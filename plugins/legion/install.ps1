param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-legion-marketplace',
    [string]$ConfigDir,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoRun,
    [ValidateSet('release','main')][string]$Ref = 'release',
    [switch]$Update,
    [switch]$Uninstall,
    [switch]$Purge,
    [string]$HomeRoot
)

if ($PSVersionTable.PSVersion -lt [version]'7.4') { throw 'The legion installer requires PowerShell 7.4 or newer. Run the root install.ps1 (or install.sh) so it can set up a current PowerShell.' }
if (-not $PSScriptRoot) { throw 'Run the legion installer from the expanded archive; script text has no PSScriptRoot.' }
$pathsLibrary = Join-Path $PSScriptRoot 'bin/lib/paths.ps1'
if (-not (Test-Path -LiteralPath $pathsLibrary -PathType Leaf)) { throw 'The legion installer requires bin/lib/paths.ps1 from the expanded archive.' }
. $pathsLibrary
. (Join-Path $PSScriptRoot 'bin/lib/footprints.ps1')

function Get-InstallSourceText {
    param([string]$Url)
    $ProgressPreference = 'SilentlyContinue'
    return (Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop).Content
}

function Get-InstallBranch {
    param([ValidateSet('release','main')][string]$Ref = 'release')
    if ($Ref -eq 'main') { return 'main' }
    return 'stable'
}

function Get-InstallCatalog {
    param([string]$Source, [ValidateSet('release','main')][string]$Ref = 'release', $Catalog)
    if ($null -eq $Catalog) {
        if (Test-Path -LiteralPath $Source -PathType Container) {
            $index = Join-Path (Resolve-Path -LiteralPath $Source).Path 'plugins/legion/tools.json'
            if (-not (Test-Path -LiteralPath $index -PathType Leaf)) {
                throw 'Local tools.json is missing; run tools/update-tools-index.ps1 to regenerate it.'
            }
            $content = Get-Content -LiteralPath $index -Raw -ErrorAction Stop
        } elseif ($Source -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            $branch = Get-InstallBranch -Ref $Ref
            $content = Get-InstallSourceText -Url "https://raw.githubusercontent.com/$Source/$branch/plugins/legion/tools.json"
        } else { throw "unsupported marketplace source '$Source'" }
        $Catalog = ConvertFrom-InstallCatalogJson -Text $content
    }
    if ($null -eq $Catalog -or $Catalog.schemaVersion -ne 1) {
        throw 'unsupported tools catalog schemaVersion (expected 1)'
    }
    if ($Catalog.tools -isnot [array]) { throw 'invalid catalog tools: expected array' }
    return $Catalog
}

# Catalog text stays text: a value that looks like a date is not turned into one.
function ConvertFrom-InstallCatalogJson {
    param([string]$Text)
    if (-not $Text.TrimStart().StartsWith('{')) { throw 'invalid catalog root: expected object' }
    $jsonOptions = @{ ErrorAction = 'Stop' }
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $jsonOptions.DateKind = 'String' }
    return $Text | ConvertFrom-Json @jsonOptions
}

function Get-InstallTool {
    param([string]$Tool)
    foreach ($entry in $script:installCatalog.tools) { if ($entry.id -ceq $Tool) { return $entry } }
    throw "unknown tool '$Tool'"
}

function ConvertTo-InstallArgument {
    # Windows command-line quoting, including embedded quotes and trailing backslashes.
    param([string]$Value)
    return '"' + ([regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
}

function Get-InstallCommands {
    param([string]$Tool, [string]$Source, [ValidateSet('release','main')][string]$Ref = 'release')
    $entry = Get-InstallTool -Tool $Tool
    $arguments = $entry.plugin.marketplaceAdd
    if ($Source -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$' -and -not (Test-Path -LiteralPath $Source -PathType Container)) {
        $arguments = $entry.plugin.marketplaceAddRef
    }
    $branch = Get-InstallBranch -Ref $Ref
    $marketplace = @($entry.command) + @($arguments | ForEach-Object { $_.Replace('{source}', $Source).Replace('{ref}', $branch) })
    $commands = @([string[]]$marketplace, [string[]](@($entry.command) + $entry.plugin.install))
    return ,$commands
}

function Resolve-InstallSource {
    param([string]$Source)
    if (Test-Path -LiteralPath $Source) { return (Resolve-Path -LiteralPath $Source).Path.Replace('\', '/') }
    return $Source
}

function Invoke-ClosedInput {
    # Some CLI shims refuse a non-terminal stdin that stays open; a closed stdin works like `< /dev/null`.
    param([string[]]$Command, $Environment)
    $executable = (Get-Command $Command[0] -CommandType Application -ErrorAction Stop)[0].Source
    $info = New-Object System.Diagnostics.ProcessStartInfo
    $info.FileName = $executable
    $arguments = @($Command | Select-Object -Skip 1)
    $onWindows = $env:OS -eq 'Windows_NT'
    if ($onWindows -and $executable -match '\.(cmd|bat)$') {
        # npm shims need cmd.exe when UseShellExecute is false.
        $info.FileName = $env:ComSpec
        $line = (@($executable) + $arguments | ForEach-Object { ConvertTo-InstallArgument $_ }) -join ' '
        $info.Arguments = '/d /s /c "' + $line + '"'
    } else {
        foreach ($argument in $arguments) { $info.ArgumentList.Add($argument) }
    }
    $info.UseShellExecute = $false
    # Codex reads <cwd>/.codex/config.toml as project settings; from the home folder that leaks
    # the default account's marketplaces into every other account.
    $info.WorkingDirectory = [IO.Path]::GetTempPath()
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    # CLI output is UTF-8 regardless of the launching terminal's code page.
    $info.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    if ($null -ne $Environment) {
        $names = if ($Environment -is [Collections.IDictionary]) { $Environment.Keys } else { $Environment.PSObject.Properties.Name }
        foreach ($name in $names) {
            if ([string]::IsNullOrEmpty($Environment.$name)) { $info.EnvironmentVariables.Remove($name) }
            else { $info.EnvironmentVariables[$name] = [string]$Environment.$name }
        }
    }
    # A mark-free UTF-8 stdin sends EOF without a byte-order mark.
    $info.StandardInputEncoding = [Text.UTF8Encoding]::new($false)
    $process = [Diagnostics.Process]::Start($info)
    $process.StandardInput.Close()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    $result = @{
        ExitCode = $process.ExitCode
        Output = @($output -split "`r?`n" | Where-Object { $_ })
        ErrorOutput = @($errorTask.Result -split "`r?`n" | Where-Object { $_ })
    }
    $process.Dispose()
    return $result
}

function Get-InstallEnvironment {
    param([string]$ConfigEnv, [string]$ConfigDir, $Environment)
    $values = @{}
    if ($Environment) {
        $names = if ($Environment -is [Collections.IDictionary]) { $Environment.Keys } else { $Environment.PSObject.Properties.Name }
        foreach ($name in $names) { $values[$name] = $Environment.$name }
    }
    if ($ConfigEnv) { $values[$ConfigEnv] = $ConfigDir }
    return $values
}

function Get-InstallListingLines {
    param($Entry, [ValidateSet('marketplace','plugin')][string]$Kind = 'plugin', [string]$ConfigDir)
    if ($ConfigDir -and -not (Test-Path -LiteralPath $ConfigDir -PathType Container)) { return }
    $arguments = if ($Kind -eq 'marketplace') { $Entry.plugin.marketplaceList } else { $Entry.plugin.list }
    $environment = Get-InstallEnvironment -ConfigEnv $Entry.configEnv -ConfigDir $ConfigDir -Environment $Entry.plugin.listingEnv
    $result = Invoke-ClosedInput -Command (@($Entry.command) + $arguments) -Environment $environment
    if ($result.ExitCode -ne 0) {
        $details = @((($result.ErrorOutput -join "`n").Trim()), (($result.Output -join "`n").Trim())) | Where-Object { $_ }
        throw (@("$($Entry.command) listing exited $($result.ExitCode)") + $details -join "`n")
    }
    return $result.Output
}

function Test-InstallStepDone {
    param($Entry, [ValidateSet('marketplace','plugin')][string]$Kind = 'plugin', [string]$ConfigDir, [switch]$IncludeDisabled, [switch]$RequireRoot)
    $lines = @(Get-InstallListingLines -Entry $Entry -Kind $Kind -ConfigDir $ConfigDir)
    return Test-InstallListing -Kind $Kind -Tool $Entry.id -Lines $lines -IncludeDisabled:$IncludeDisabled -RequireRoot:$RequireRoot
}

function Get-InstallListingField {
    param($Item, [string]$Field)
    foreach ($part in $Field.Split('.')) {
        if ($null -eq $Item) { return $null }
        $Item = $Item.$part
    }
    return ,$Item
}

function Test-InstallListing {
    # Installation requires enabled plugins; updates also refresh disabled installed copies.
    param([ValidateSet('marketplace', 'plugin')][string]$Kind, [string]$Tool, [string[]]$Lines, [switch]$IncludeDisabled, [switch]$RequireRoot)
    $entry = Get-InstallTool -Tool $Tool
    if ($Kind -eq 'marketplace') {
        $listing = $entry.plugin.marketplaceListing
        try { $items = ($Lines -join "`n") | ConvertFrom-Json -ErrorAction Stop }
        catch { throw "$Tool marketplace listing returned invalid JSON" }
        if ($listing.collectionField -and $null -ne $items) {
            $items = Get-InstallListingField -Item $items -Field $listing.collectionField
            if ($null -eq $items) { throw "$Tool marketplace listing is missing its collection" }
        }
        foreach ($item in @($items)) {
            if ((Get-InstallListingField -Item $item -Field $listing.nameField) -cne 'ps-legion-marketplace') { continue }
            if ($RequireRoot -and $listing.rootField) {
                $root = Get-InstallListingField -Item $item -Field $listing.rootField
                if (-not ($root -is [string]) -or -not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) { return $false }
            }
            return $true
        }
        return $false
    }
    $plugin = Read-InstallPluginListing -Entry $entry -Lines $Lines
    return $plugin.Listed -and ($IncludeDisabled -or $plugin.Enabled)
}

function Format-InstallCommand {
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
    $parts = foreach ($part in $Command) {
        if ($part -match '\s') { '"' + $part.Replace('"', '\"') + '"' }
        else { $part }
    }
    $line = $parts -join ' '
    if ($ConfigDir) { return "$ConfigEnv=$ConfigDir $line" }
    return $line
}

function Invoke-InstallCommand {
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
    $environment = Get-InstallEnvironment -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir
    $result = Invoke-ClosedInput -Command $Command -Environment $environment
    $result.Output
    $result.ErrorOutput
    if ($result.ExitCode -ne 0) { throw "$($Command[0]) exited $($result.ExitCode)" }
}

function Invoke-InstallStep {
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir, [switch]$DryRun)
    if ($DryRun) { Format-InstallCommand -Command $Command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
    else { Invoke-InstallCommand -Command $Command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
}

function Invoke-LegionInstallSteps {
    param([string]$Tool, [string]$Source, [string]$ConfigEnv, [string]$ConfigDir, [switch]$DryRun, [ValidateSet('release','main')][string]$Ref = 'release')
    $commands = Get-InstallCommands -Tool $Tool -Source $Source -Ref $Ref
    $marketplace, $plugin = $commands
    $entry = Get-InstallTool -Tool $Tool
    if (-not $DryRun -and $ConfigDir -and -not (Test-Path -LiteralPath $ConfigDir -PathType Container)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force -ErrorAction Stop | Out-Null
    }
    if (Test-InstallStepDone -Entry $entry -Kind marketplace -ConfigDir $ConfigDir) {
        $rootReady = -not $entry.plugin.marketplaceListing.rootField -or (Test-InstallStepDone -Entry $entry -Kind marketplace -ConfigDir $ConfigDir -RequireRoot)
        if ($rootReady -and (Test-InstallStepDone -Entry $entry -Kind plugin -ConfigDir $ConfigDir)) {
            "skip: $($marketplace -join ' ') (already done)"
            "skip: $($plugin -join ' ') (already done)"
            return
        }
        if (-not $entry.plugin.marketplaceUpdate.Count) { throw "$Tool has no marketplace refresh command" }
    } else {
        Invoke-InstallStep -Command $marketplace -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir -DryRun:$DryRun
    }
    if ($entry.plugin.marketplaceUpdate.Count) {
        Invoke-InstallStep -Command (@($entry.command) + $entry.plugin.marketplaceUpdate) -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir -DryRun:$DryRun
    }
    Invoke-InstallStep -Command $plugin -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir -DryRun:$DryRun
}

# -HomeRoot lets a caller with an alternate home keep every write, refresh included, inside it.
$script:installHomeRoot = $HomeRoot
function Get-InstallHome {
    if ($script:installHomeRoot) { return $script:installHomeRoot }
    return [Environment]::GetFolderPath('UserProfile')
}

# Persistent changes need consent: -Yes, or a yes at the prompt.
function Confirm-InstallChange {
    param([string]$Question, [switch]$Yes)
    return $Yes -or (Read-Host $Question) -match '^(?i:y|yes)$'
}

function Get-InstallLegionPath {
    param([string]$Path)
    return Join-Path (Join-Path (Get-InstallHome) '.legion') $Path
}

function Resolve-InstallConfigDir {
    param([string]$Path)
    $Path = $Path.Replace('\', '/')
    if ($Path -eq '~') { $Path = Get-InstallHome }
    $Path = Resolve-LegionHomePath -Path $Path -HomeRoot (Get-InstallHome)
    return [IO.Path]::TrimEndingDirectorySeparator([IO.Path]::GetFullPath($Path))
}

function Test-InstallRealProfile {
    $selected = [IO.Path]::GetFullPath((Get-InstallHome)).TrimEnd('\', '/')
    $profileHome = [IO.Path]::GetFullPath([Environment]::GetFolderPath('UserProfile')).TrimEnd('\', '/')
    return (Get-LegionPathComparer).Equals($selected, $profileHome)
}

function Get-UpdateConfigDirs {
    param([string]$Tool, [string]$ConfigDir)
    if ($ConfigDir) { return ,@($ConfigDir) }
    $entry = Get-InstallTool -Tool $Tool
    $override = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
    $defaultFolder = if ($override) { $override } else { $entry.plugin.defaultConfigDir }
    if ($defaultFolder) { $defaultFolder = Resolve-InstallConfigDir $defaultFolder }
    $folders = @()
    $seen = [Collections.Generic.HashSet[string]]::new((Get-LegionPathComparer))
    $file = Get-LegionOwnerPath -Name Settings -HomeRoot (Get-InstallHome)
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $data = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($agent in $data.agents) {
            if ($agent.tool -cne $Tool -or [string]::IsNullOrWhiteSpace($agent.configDir)) { continue }
            $folder = Resolve-InstallConfigDir $agent.configDir
            if ($seen.Add($folder)) { $folders += $folder }
        }
    }
    if (-not $seen.Contains($defaultFolder)) {
        # Keep the CLI's implicit default only when no recorded account selects it.
        # A home other than the real profile has its own default folder; never hand the CLI its real default.
        $target = if ($override -or -not (Test-InstallRealProfile)) { $defaultFolder } else { '' }
        $folders = @($target) + $folders
    }
    return ,$folders
}

# Used by the install plan and the integration runner.
function Get-InstallOwnerCommands {
    return [ordered]@{ 'legion' = 'legion.ps1' }
}

function Get-UninstallCachePath {
    param($Entry, [string]$ConfigDir)
    if (-not $Entry.plugin.cacheDir) { return }
    if (-not $ConfigDir) {
        if (-not $Entry.plugin.defaultConfigDir) { throw 'Missing plugin.defaultConfigDir for cache cleanup' }
        $ConfigDir = Resolve-LegionHomePath -Path $Entry.plugin.defaultConfigDir -HomeRoot (Get-InstallHome)
    }
    return Get-InstallSafePath -Root $ConfigDir -Relative $Entry.plugin.cacheDir
}

function Get-InstallSafePath {
    # Except: links inside the path that purge removes first.
    param([string]$Root, $Relative, [switch]$AllowFile, [string[]]$Except = @())
    # Catalogs are generated and schema-checked, but deletion paths must still be exact and relative.
    if ($Relative -isnot [string] -or [string]::IsNullOrWhiteSpace($Relative) -or
        $Relative -match '(^[/\\~]|:|(^|[/\\])\.{1,2}([/\\]|$)|[*?]|[/\\]$|[/\\]{2})') {
        throw 'Unsafe relative path: expected an exact path under the root'
    }
    $rootPath = [IO.Path]::GetFullPath($Root)
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    if (-not (Test-LegionPathUnder -Path $path -Root $rootPath)) { throw 'Unsafe path outside the root' }
    if (-not (Test-Path -LiteralPath $path)) { return }
    if (-not $AllowFile -and -not (Test-Path -LiteralPath $path -PathType Container)) { return }
    $homeRoot = [IO.Path]::GetFullPath((Get-InstallHome))
    # Selected config folders may live outside home; home paths never walk above it.
    $stopRoot = if (Test-LegionPathUnder -Path $path -Root $homeRoot) { $homeRoot } else { [IO.Path]::GetPathRoot($path) }
    if (-not (Test-LegionOwnerPathSafe -Path $path -StopRoot $stopRoot)) {
        Write-Host "skip: plugin cache $path (linked folder)"
        return
    }
    $pending = [Collections.Generic.Stack[string]]::new()
    if (Test-Path -LiteralPath $path -PathType Container) { $pending.Push($path) }
    while ($pending.Count) {
        foreach ($item in (Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
            if ($Except -ccontains $item.FullName) { continue }
            if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                Write-Host "skip: plugin cache $path (linked contents)"
                return
            }
            if ($item.PSIsContainer) { $pending.Push($item.FullName) }
        }
    }
    return $path
}

# Read JSON/JSONC token spans rather than serializing settings. Only the selected
# member (or inventory array item) and one separating comma are removed.
function Get-InstallPurgeJsonText {
    param([string]$Text, [string]$Kind, [string]$Key, [string]$Value)
    function Read-PurgeJsonNode {
        param([ref]$Cursor, [int]$Depth = 0)
        if ($Depth -gt 64 -or $Cursor.Value -ge $tokens.Count) { throw 'Unsupported JSON' }
        $token = $tokens[$Cursor.Value]
        $Cursor.Value++
        $node = [pscustomobject]@{ Start=$token.Index; End=($token.Index + $token.Length); Value=$null; Children=@() }
        if ($token.Value -notin @('{', '[')) {
            if ($token.Value -match '^[}\],:]$') { throw 'Invalid JSON value' }
            $node.Value = if ($token.Value.StartsWith('"')) { ConvertFrom-Json -InputObject $token.Value -ErrorAction Stop } else { $token.Value }
            return $node
        }
        $object = $token.Value -eq '{'
        $close = if ($object) { '}' } else { ']' }
        $previousComma = -1
        $names = New-Object 'Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
        while ($Cursor.Value -lt $tokens.Count -and $tokens[$Cursor.Value].Value -ne $close) {
            $start = $tokens[$Cursor.Value].Index
            $name = '*'
            if ($object) {
                $key = $tokens[$Cursor.Value].Value
                if (-not $key.StartsWith('"')) { throw 'Invalid JSON member' }
                $name = ConvertFrom-Json -InputObject $key -ErrorAction Stop
                if (-not $names.Add($name)) { throw 'Duplicate JSON member' }
                $Cursor.Value++
                if ($Cursor.Value -ge $tokens.Count -or $tokens[$Cursor.Value].Value -ne ':') { throw 'Missing JSON colon' }
                $Cursor.Value++
            }
            $value = Read-PurgeJsonNode -Cursor $Cursor -Depth ($Depth + 1)
            $member = [pscustomobject]@{ Key=$name; Start=$start; End=$value.End; Node=$value; BeforeComma=$previousComma; AfterComma=-1 }
            $node.Children += $member
            if ($Cursor.Value -lt $tokens.Count -and $tokens[$Cursor.Value].Value -eq ',') {
                $member.AfterComma = $tokens[$Cursor.Value].Index
                $previousComma = $member.AfterComma
                $Cursor.Value++
            } elseif ($Cursor.Value -ge $tokens.Count -or $tokens[$Cursor.Value].Value -ne $close) { throw 'Missing JSON comma' }
        }
        if ($Cursor.Value -ge $tokens.Count) { throw 'Unclosed JSON container' }
        $node.End = $tokens[$Cursor.Value].Index + 1
        $Cursor.Value++
        return $node
    }
    $entries = @()
    while ($true) {
        $pattern = '\G(?:\s+|//[^\r\n]*|/\*[\s\S]*?\*/|"(?:\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4})|[^"\\\x00-\x1f])*"|[{}\[\],:]|true\b|false\b|null\b|-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?)'
        $tokens = @()
        $offset = 0
        while ($offset -lt $Text.Length) {
            $match = ([regex]$pattern).Match($Text, $offset)
            if (-not $match.Success -or $match.Index -ne $offset) { throw 'Unsupported JSONC syntax' }
            $offset += $match.Length
            if ($match.Value -match '^\s|^//|^/\*') { continue }
            $tokens += $match
        }
        $cursor = 0
        $root = Read-PurgeJsonNode -Cursor ([ref]$cursor)
        if ($cursor -ne $tokens.Count -or $tokens[0].Value -ne '{') { throw 'Unsupported JSON root' }
        $candidates = @()
        if ($Kind -eq 'allow') {
            $node = $root
            foreach ($part in $Key.Split('.')) { $node = ($node.Children | Where-Object Key -CEQ $part).Node }
            $candidates = @($node.Children | Where-Object { $_.Node.Value -is [string] -and $_.Node.Value -ceq $Value })
        } elseif ($Kind -eq 'marketplaces') {
            $candidates = @($root.Children | Where-Object Key -CEQ 'ps-legion-marketplace')
        } else {
            foreach ($parent in $root.Children) {
                $key = if ($parent.Key -ceq 'extraKnownMarketplaces') { 'ps-legion-marketplace' } else { 'legion@ps-legion-marketplace' }
                if ($parent.Key -cin @('enabledPlugins', 'extraKnownMarketplaces') -or ($Kind -eq 'claude' -and $parent.Key -ceq 'plugins')) {
                    $candidates += @($parent.Node.Children | Where-Object Key -CEQ $key)
                }
                if ($Kind -eq 'copilot' -and $parent.Key -ceq 'installedPlugins') {
                    foreach ($item in $parent.Node.Children) {
                        $name = @($item.Node.Children | Where-Object Key -CEQ 'name')
                        $marketplace = @($item.Node.Children | Where-Object Key -CEQ 'marketplace')
                        if ($name.Count -eq 1 -and $name[0].Node.Value -ceq 'legion' -and $marketplace.Count -eq 1 -and $marketplace[0].Node.Value -ceq 'ps-legion-marketplace') { $candidates += $item }
                    }
                }
            }
        }
        if (-not $candidates.Count) { break }
        $member = $candidates[0]
        $entries += if ($Kind -eq 'allow') { "$Key`: $Value" } elseif ($member.Key -eq '*') { 'installedPlugins: legion@ps-legion-marketplace' } else { $member.Key }
        $comma = if ($member.AfterComma -ge 0) { $member.AfterComma } else { $member.BeforeComma }
        # Remove the comma independently so intervening comments and whitespace stay.
        if ($comma -ge $member.End) { $Text = $Text.Remove($comma, 1) }
        $Text = $Text.Remove($member.Start, $member.End - $member.Start)
        if ($comma -ge 0 -and $comma -lt $member.Start) { $Text = $Text.Remove($comma, 1) }
    }
    return [pscustomobject]@{ Text=$Text; Entries=$entries }
}

function Get-InstallPurgeTomlText {
    param([string]$Text)
    # The same string/comment scan used by the Foundry adapter: apparent headers
    # inside multiline strings and arrays are values, not tables to delete.
    $delimiter = ''
    $arrayDepth = 0
    $skip = $false
    $kept = New-Object Text.StringBuilder
    $entries = @()
    $key = '(?:ps-legion-marketplace|"ps-legion-marketplace"|''ps-legion-marketplace'')'
    $plugin = '(?:"legion@ps-legion-marketplace"|''legion@ps-legion-marketplace'')'
    $hook = '(?:"legion@ps-legion-marketplace:[^"\r\n]*"|''legion@ps-legion-marketplace:[^''\r\n]*'')'
    $owned = '^\s*\[\s*(?:(?:plugins|"plugins"|''plugins'')\s*\.\s*' + $plugin + '|(?:marketplaces|"marketplaces"|''marketplaces'')\s*\.\s*' + $key + '|(?:hooks|"hooks"|''hooks'')\s*\.\s*(?:state|"state"|''state'')\s*\.\s*' + $hook + ')(?:\s*\.\s*[\w"''.-]+)*\s*\]\s*(?:#.*)?$'
    foreach ($match in [regex]::Matches($Text, '[^\r\n]*(?:\r\n|\n|\r|$)')) {
        $line = $match.Value
        if (-not $line.Length) { continue }
        $outsideValue = -not $delimiter -and $arrayDepth -eq 0
        if ($outsideValue -and $line -match '^\s*\[') {
            $skip = $line.TrimEnd("`r", "`n") -cmatch $owned
            if ($skip) { $entries += $line.Trim() }
        }
        if ($outsideValue -and -not $skip -and $line -cmatch '^\s*(?:["'']?(?:plugins|marketplaces|hooks)["'']?[\s.=]|["'']?legion(?:@ps-legion-marketplace|-marketplace))' -and $line -cmatch 'legion(?:@ps-legion-marketplace|-marketplace)') {
            throw 'Inline or dotted legion TOML entry needs manual removal'
        }
        if (-not $skip) { [void]$kept.Append($line) }
        for ($i = 0; $i -lt $line.Length;) {
            if ($delimiter) {
                if ($delimiter -ceq '"""' -and $line[$i] -ceq '\') { $i += 2; continue }
                if ($i + 2 -lt $line.Length -and $line.Substring($i, 3) -ceq $delimiter) { $delimiter = ''; $i += 3; continue }
                $i++; continue
            }
            if ($line[$i] -ceq '#') { break }
            if ($line[$i] -cin @('"', "'")) {
                $quote = [string]$line[$i]
                if ($i + 2 -lt $line.Length -and $line.Substring($i, 3) -ceq ($quote * 3)) { $delimiter = $quote * 3; $i += 3; continue }
                $word = [regex]::Match($line.Substring($i), '^(?:"(?:\\.|[^"\\])*"|''[^'']*'')')
                if (-not $word.Success) { throw 'Unsupported TOML string' }
                $i += $word.Length
            } else {
                if ($line[$i] -ceq '[') { $arrayDepth++ }
                if ($line[$i] -ceq ']') { $arrayDepth-- }
                $i++
            }
        }
    }
    if ($delimiter -or $arrayDepth -ne 0) { throw 'Unclosed TOML value' }
    return [pscustomobject]@{ Text=$kept.ToString(); Entries=$entries }
}

function Get-InstallPurgeEdit {
    param([string]$Path, [string]$Kind, [array]$Footprints = @())
    $before = [IO.File]::ReadAllBytes($Path)
    $encoding = New-Object Text.UTF8Encoding ($false, $true)
    $bom = 0
    if ($before.Length -ge 3 -and $before[0] -eq 239 -and $before[1] -eq 187 -and $before[2] -eq 191) { $bom = 3 }
    elseif ($before.Length -ge 2 -and $before[0] -eq 255 -and $before[1] -eq 254) { $encoding = New-Object Text.UnicodeEncoding ($false, $false, $true); $bom=2 }
    elseif ($before.Length -ge 2 -and $before[0] -eq 254 -and $before[1] -eq 255) { $encoding = New-Object Text.UnicodeEncoding ($true, $false, $true); $bom=2 }
    try {
        $text = $encoding.GetString($before, $bom, $before.Length - $bom)
        $entries = @()
        foreach ($footprint in $Footprints) {
            if ($footprint.kind -ceq 'path-entry') {
                # Only a line under legion's marker is legion's; the recorded separator goes with it.
                $pattern = '(?m)(?:' + [regex]::Escape($footprint.key) + ')?^# Added by legion\r?\n' + [regex]::Escape($footprint.value) + '(?:\r?\n|$)'
                if ([regex]::IsMatch($text, $pattern)) {
                    $text = [regex]::Replace($text, $pattern, '')
                    $entries += $footprint.value
                }
                continue
            }
            $result = Get-InstallPurgeJsonText -Text $text -Kind allow -Key $footprint.key -Value $footprint.value
            $text = $result.Text; $entries += $result.Entries
        }
        if ($Kind) {
            $result = if ($Kind -eq 'toml') { Get-InstallPurgeTomlText -Text $text } else { Get-InstallPurgeJsonText -Text $text -Kind $Kind }
            $text = $result.Text; $entries += $result.Entries
        }
        if (-not $entries.Count) { return }
        $after = $encoding.GetBytes($text)
        if ($bom) { $after = [byte[]]($before[0..($bom - 1)] + $after) }
        return [pscustomobject]@{ Path=$Path; Before=$before; After=$after; Entries=$entries }
    } catch {
        # Do not print settings contents or parser errors that could contain secrets.
        return [pscustomobject]@{ Manual=$true; Path=$Path }
    }
}

function Set-InstallPurgeEdit {
    param($Edit)
    $safe = Get-InstallSafePath -Root (Split-Path $Edit.Path) -Relative ([IO.Path]::GetFileName($Edit.Path)) -AllowFile
    if (-not $safe -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($Edit.Path)) -cne [Convert]::ToBase64String($Edit.Before)) { throw 'Settings changed after preview; run again.' }
    [IO.File]::WriteAllBytes($Edit.Path, $Edit.After)
}

# The edit for one existing file; Manual when the file is linked or cannot be matched safely.
function Get-InstallSafeEdit {
    param([string]$Path, [array]$Footprints)
    if (-not (Get-InstallSafePath -Root (Split-Path $Path) -Relative ([IO.Path]::GetFileName($Path)) -AllowFile 6>$null)) {
        return [pscustomobject]@{ Manual=$true; Path=$Path }
    }
    return Get-InstallPurgeEdit -Path $Path -Footprints $Footprints
}

function Select-InstallFootprintsAt {
    param([array]$Footprints, [string]$Path)
    return @($Footprints | Where-Object { (Get-LegionPathComparer).Equals((Resolve-LegionHomePath -Path $_.path -HomeRoot (Get-InstallHome)), $Path) })
}

function Remove-InstallFootprintEdit {
    param($Entry, [string]$HomeRoot, [switch]$WhatIf)
    $path = Resolve-LegionHomePath -Path $Entry.path -HomeRoot $HomeRoot
    if (-not (Test-Path -LiteralPath $path)) { return $true }
    $edit = Get-InstallSafeEdit -Path $path -Footprints @($Entry)
    if ($edit.Manual) { Write-Host "skip: $path (linked or could not match safely)"; return $false }
    if ($edit) {
        foreach ($name in $edit.Entries) { Write-Host "Remove entry: $path`: $name" }
        if (-not $WhatIf) { Set-InstallPurgeEdit -Edit $edit }
    }
    return $true
}

# Split a PATH value into the parts legion recorded (Removed) and the rest (Kept).
function Split-InstallPath {
    param([string]$Path, [string]$Separator, [string[]]$Owned)
    $kept = @()
    $removed = @()
    foreach ($part in ($Path -split [regex]::Escape($Separator))) {
        if (@($Owned | Where-Object { Test-InstallPathEntry -Path $part -Entry $_ -Separator $Separator }).Count) { $removed += $part } else { $kept += $part }
    }
    return @{ Kept=$kept; Removed=$removed }
}

function Get-InstallPurgePlan {
    param([string]$ConfigDir)
    # Purge is global even if the preceding uninstall selected only some targets.
    $paths = @()
    $edits = @()
    $editedPaths = [Collections.Generic.HashSet[string]]::new((Get-LegionPathComparer))
    $manualSteps = @()
    $footprints = @(Get-LegionFootprints -HomeRoot (Get-InstallHome) | Where-Object { $_.kind -ceq 'edit' -or ($_.kind -ceq 'path-entry' -and $_.path -cne 'user PATH') })
    $pathEntries = @(Get-LegionFootprints -HomeRoot (Get-InstallHome) -Kind path-entry | Where-Object path -CEQ 'user PATH' | ForEach-Object value)
    $userPath = if ($env:OS -eq 'Windows_NT') { Get-InstallUserPath } else { '' }
    $user = Split-InstallPath -Path $userPath -Separator ';' -Owned $pathEntries
    $processPath = $env:PATH
    $processSeparator = [string][IO.Path]::PathSeparator
    $process = if ($env:OS -eq 'Windows_NT') { Split-InstallPath -Path $processPath -Separator $processSeparator -Owned $pathEntries } else { @{ Kept=@(); Removed=@() } }
    $seen = @()
    foreach ($entry in $script:installCatalog.tools) {
        $folders = Get-UpdateConfigDirs -Tool $entry.id
        if ($entry.plugin.defaultConfigDir) { $folders += Resolve-InstallConfigDir $entry.plugin.defaultConfigDir }
        if ($ConfigDir) { $folders += Resolve-InstallConfigDir $ConfigDir }
        foreach ($folder in $folders) {
            if (-not $folder -and $entry.plugin.defaultConfigDir) { $folder = Resolve-InstallConfigDir $entry.plugin.defaultConfigDir }
            if (-not $folder) { continue }
            $key = Get-LegionTargetOwner -Tool $entry -Folder $folder -HomeRoot (Get-InstallHome)
            if ($seen -ccontains $key) { continue }
            $seen += $key
            $purge = $entry.plugin.purge
            $relativePaths = @($entry.plugin.cacheDir) + @($purge.paths)
            foreach ($relative in $relativePaths) {
                if (-not $relative) { continue }
                $path = Get-InstallSafePath -Root $folder -Relative $relative -AllowFile 6>$null
                if ($path) { $paths += [pscustomobject]@{ Path=$path; Root=$folder; Relative=$relative; EmptyOnly=$false } }
                elseif (Test-Path -LiteralPath (Join-Path $folder $relative)) { $manualSteps += "Manual step: $(Join-Path $folder $relative) (linked path; left in place)" }
            }
            foreach ($relative in $purge.emptyDirs) {
                $path = Get-InstallSafePath -Root $folder -Relative $relative 6>$null
                # List the parent only if its remaining children are already planned for removal.
                if ($path -and -not @(Get-ChildItem -LiteralPath $path -Force | Where-Object { $_.FullName -notin $paths.Path }).Count) {
                    $paths += [pscustomobject]@{ Path=$path; Root=$folder; Relative=$relative; EmptyOnly=$true }
                }
            }
            foreach ($setting in $purge.settings) {
                $relative = $setting.path
                $path = Get-InstallSafePath -Root $folder -Relative $relative -AllowFile 6>$null
                if (-not $path -and (Test-Path -LiteralPath (Join-Path $folder $relative))) { $manualSteps += "Manual step: $(Join-Path $folder $relative) (linked path; left in place)" }
                if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                    if ($editedPaths.Contains($path)) { continue }
                    $edit = Get-InstallPurgeEdit -Path $path -Kind $setting.kind -Footprints (Select-InstallFootprintsAt -Footprints $footprints -Path $path)
                    if ($edit.Manual) { $manualSteps += "Manual step: $path (remove its legion entries; could not match them safely)" }
                    elseif ($edit) { $edits += $edit; [void]$editedPaths.Add($path) }
                }
            }
        }
    }
    foreach ($footprint in $footprints) {
        $path = Resolve-LegionHomePath -Path $footprint.path -HomeRoot (Get-InstallHome)
        if ($editedPaths.Contains($path) -or -not (Test-Path -LiteralPath $path)) { continue }
        [void]$editedPaths.Add($path)
        $edit = Get-InstallSafeEdit -Path $path -Footprints (Select-InstallFootprintsAt -Footprints $footprints -Path $path)
        if ($edit.Manual) { $manualSteps += "Manual step: $path (linked or could not match safely)" }
        elseif ($edit) { $edits += $edit }
    }
    $links = @(Get-LegionFootprints -HomeRoot (Get-InstallHome) -Kind link | Where-Object { Test-LegionFootprintSafe -Entry $_ -HomeRoot (Get-InstallHome) } |
        ForEach-Object { [IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $_.path -HomeRoot (Get-InstallHome))) } | Where-Object { Get-Item -LiteralPath $_ -Force -ErrorAction SilentlyContinue })
    $legion = Get-InstallSafePath -Root (Get-InstallHome) -Relative '.legion' -Except $links 6>$null
    if (-not $legion -and (Test-Path -LiteralPath (Get-InstallLegionPath ''))) { $manualSteps += 'Manual step: legion home contains linked paths; left in place.' }
    return [pscustomobject]@{
        Paths=$paths; Edits=$edits; Links=$links; Legion=$legion; HomeRoot=(Get-InstallHome); ManualSteps=$manualSteps
        UserPath=[pscustomobject]@{ Before=$userPath; After=($user.Kept -join ';'); Entries=$user.Removed }
        ProcessPath=[pscustomobject]@{ Before=$processPath; After=($process.Kept -join $processSeparator); Entries=$process.Removed }
        HasWork=[bool]($paths.Count -or $edits.Count -or $links.Count -or $legion -or $user.Removed.Count -or $process.Removed.Count)
    }
}

function Show-InstallPurgePlan {
    param($Plan)
    foreach ($entry in $Plan.UserPath.Entries) { "Remove user PATH entry: $entry" }
    foreach ($entry in $Plan.ProcessPath.Entries) { "Remove process PATH entry: $entry" }
    foreach ($edit in $Plan.Edits) { foreach ($name in $edit.Entries) { "Remove entry: $($edit.Path): $name" } }
    foreach ($link in $Plan.Links) { "Remove link: $link" }
    $items = @($Plan.Paths)
    if ($Plan.Legion) { $items += [pscustomobject]@{ Path=$Plan.Legion; EmptyOnly=$false } }
    $shown = [Collections.Generic.HashSet[string]]::new((Get-LegionPathComparer))
    foreach ($item in $items) {
        if (-not $shown.Add($item.Path)) { continue }
        if (Test-Path -LiteralPath $item.Path -PathType Container) {
            $count = @(Get-ChildItem -LiteralPath $item.Path -File -Recurse -Force).Count
            $note = if ($item.EmptyOnly) { ' (if empty)' } elseif ($item.Path -ceq $Plan.Legion) { ' (last: all settings, notes, account folders, logins and launchers)' } else { '' }
            "Remove folder: $($item.Path) ($count files)$note"
        } else { "Remove file: $($item.Path)" }
    }
    foreach ($step in $Plan.ManualSteps) { $step }
}

function Invoke-InstallPurgePlan {
    param($Plan)
    if ($Plan.UserPath.Entries.Count) {
        if ((Get-InstallUserPath) -cne $Plan.UserPath.Before) { throw 'User PATH changed after preview; run purge again.' }
        Set-InstallUserPath -Path $Plan.UserPath.After
    }
    if ($Plan.ProcessPath.Entries.Count) {
        if ($env:PATH -cne $Plan.ProcessPath.Before) { throw 'Process PATH changed after preview; run purge again.' }
        $env:PATH = $Plan.ProcessPath.After
    }
    foreach ($edit in $Plan.Edits) {
        # Refuse a concurrent settings write rather than overwriting the owner's changes.
        Set-InstallPurgeEdit -Edit $edit
    }
    foreach ($item in $Plan.Paths) {
        $safe = Get-InstallSafePath -Root $item.Root -Relative $item.Relative -AllowFile
        if (-not $safe -or $safe -cne $item.Path) { continue }
        if ($item.EmptyOnly -and @(Get-ChildItem -LiteralPath $safe -Force).Count) { continue }
        Remove-Item -LiteralPath $safe -Recurse -Force -ErrorAction Stop
    }
    foreach ($link in $Plan.Links) {
        $entry = Get-LegionFootprints -HomeRoot $Plan.HomeRoot -Kind link | Where-Object { [IO.Path]::GetFullPath((Resolve-LegionHomePath -Path $_.path -HomeRoot $Plan.HomeRoot)) -ceq $link }
        if ($entry -and (Test-LegionFootprintSafe -Entry $entry -HomeRoot $Plan.HomeRoot)) { (Get-Item -LiteralPath $link -Force).Delete() }
    }
    # The running installer may be a private copy under this tree; functions are
    # already loaded. Legion's caller tolerates its copy having been removed.
    if ($Plan.Legion) {
        $safe = Get-InstallSafePath -Root $Plan.HomeRoot -Relative '.legion'
        if ($safe -and $safe -ceq $Plan.Legion) { Remove-Item -LiteralPath $safe -Recurse -Force -ErrorAction Stop }
    }
}

function Invoke-LegionPurge {
    param([string]$ConfigDir, [switch]$DryRun, [switch]$Yes)
    $plan = Get-InstallPurgePlan -ConfigDir $ConfigDir
    Show-InstallPurgePlan -Plan $plan
    if (-not $plan.HasWork) {
        if ($plan.ManualSteps.Count) { 'Purge needs the manual steps above.' } else { 'skip: purge (already done)' }
        return
    }
    if ($DryRun) { return }
    if (-not ($Yes -or (Read-Host 'Purge legion settings, notes, account folders and logins listed above? [y/N]') -match '^(?i:y|yes)$')) { 'Purge cancelled.'; return }
    Invoke-InstallPurgePlan -Plan $plan
    if ($plan.ManualSteps.Count) { 'Purge needs the manual steps above.' } else { 'done: purge' }
}

function Invoke-LegionUninstall {
    param([string[]]$Tools, [string]$ConfigDir, [switch]$DryRun, [switch]$Yes)
    $homeRoot = Get-InstallHome
    $script:installUninstallDeclined = $false
    $owners = @()
    $targets = @()
    $selectedTools = if ($Tools) { $Tools } else { @($script:installCatalog.tools | ForEach-Object { $_.id }) }
    foreach ($tool in ($selectedTools | Select-Object -Unique)) {
        $entry = Get-InstallTool -Tool $tool
        if (-not (Test-InstallCommandAvailable -Name $entry.command)) { "skip: $tool (not installed)"; continue }
        $folders = Get-UpdateConfigDirs -Tool $tool -ConfigDir $ConfigDir
        # A removed account keeps its folder; the index still names it as an install target.
        if (-not $ConfigDir) { $folders += @(Get-LegionFootprints -HomeRoot $homeRoot | ForEach-Object { $_.owners } | Where-Object { $_ -clike "${tool}:*" } | ForEach-Object { $_.Substring($tool.Length + 1) }) }
        foreach ($folder in $folders) {
            $owner = Get-LegionTargetOwner -Tool $entry -Folder $folder -HomeRoot $homeRoot
            if ($owners -ccontains $owner) { continue }
            $label = if ($folder) { $folder } else { 'default config' }
            # In a chosen home the tool's default folder may not exist; then nothing is installed there.
            $isHomeDefault = $folder -and $entry.plugin.defaultConfigDir -and $owner -ceq (Get-LegionTargetOwner -Tool $entry -HomeRoot $homeRoot)
            if ($isHomeDefault -and -not (Test-InstallRealProfile) -and -not (Test-Path -LiteralPath $folder)) { "skip: $tool plugin in $label (not installed)"; continue }
            $owners += $owner
            $steps = @()
            foreach ($kind in @('plugin', 'marketplace')) {
                if (-not (Test-InstallStepDone -Entry $entry -Kind $kind -ConfigDir $folder -IncludeDisabled)) {
                    "skip: $tool $kind in $label (not installed)"
                    continue
                }
                $arguments = if ($kind -eq 'plugin') { $entry.plugin.uninstall } else { $entry.plugin.marketplaceRemove }
                $steps += [pscustomobject]@{ Kind=$kind; Command=(@($entry.command) + $arguments) }
            }
            $cache = Get-UninstallCachePath -Entry $entry -ConfigDir $folder
            if (-not $steps.Count -and -not $cache) { continue }
            $targets += [pscustomobject]@{ Entry=$entry; Folder=$folder; Steps=$steps; Cache=$cache }
            "Target: $tool in $label"
            foreach ($step in $steps) {
                Format-InstallCommand -Command $step.Command -ConfigEnv $entry.configEnv -ConfigDir $folder
            }
            if ($cache) { "Remove cache folder: $cache" }
        }
    }
    $bin = [IO.Path]::GetFullPath((Get-InstallLegionPath 'bin'))
    $recorded = @(Get-LegionFootprints -HomeRoot $homeRoot | Where-Object { @($_.owners | Where-Object { $owners -ccontains $_ }).Count -or -not $_.owners.Count })
    Remove-LegionFootprintOwner -HomeRoot $homeRoot -Owner $owners -RemoveEdit ${function:Remove-InstallFootprintEdit} -RetryOrphans -WhatIf
    if (-not $recorded.Count) { 'skip: legion generated files (not installed)' }
    $hasWork = $targets.Count -or $recorded.Count
    'Channel plugins and their state remain in place.'
    if (-not $hasWork) { 'Nothing to uninstall.' }
    if ($hasWork -and -not $DryRun -and ($Yes -or (Read-Host 'Uninstall legion from these targets? [y/N]') -match '^(?i:y|yes)$')) {
        foreach ($target in $targets) {
            $entry = $target.Entry
            foreach ($step in $target.Steps) {
                if (-not (Test-InstallStepDone -Entry $entry -Kind $step.Kind -ConfigDir $target.Folder -IncludeDisabled)) {
                    "skip: $($entry.id) $($step.Kind) in $(if ($target.Folder) { $target.Folder } else { 'default config' }) (not installed)"
                    continue
                }
                Invoke-InstallCommand -Command $step.Command -ConfigEnv $entry.configEnv -ConfigDir $target.Folder
            }
            if ($target.Cache) {
                if (Test-InstallStepDone -Entry $entry -Kind plugin -ConfigDir $target.Folder -IncludeDisabled) {
                    throw "$($entry.id) plugin is still listed; cache kept."
                }
                # Recheck the exact descriptor path and links immediately before recursive deletion.
                $cache = Get-UninstallCachePath -Entry $entry -ConfigDir $target.Folder
                if ($cache -and $cache -ceq $target.Cache) {
                    Remove-Item -LiteralPath $cache -Recurse -Force -ErrorAction Stop
                }
            }
        }
        Remove-LegionFootprintOwner -HomeRoot $homeRoot -Owner $owners -RemoveEdit ${function:Remove-InstallFootprintEdit} -RetryOrphans
        $command = @(Get-LegionFootprints -HomeRoot $homeRoot -Kind file | Where-Object { $_.path -ceq '~/.legion/bin/legion' -and $_.owners.Count }) | Select-Object -First 1
        if ($recorded.Count -and $command) {
            $tool, $folder = $command.owners[0] -split ':', 2
            try { Invoke-InstallRefresh -Entry (Get-InstallTool -Tool $tool) -ConfigDir $folder }
            catch { "Kept command: $($command.path) (run legion setup)" }
        }
    } elseif ($hasWork -and -not $DryRun) {
        $script:installUninstallDeclined = $true
    }
    $configuration = Get-InstallLegionPath 'configuration'
    $accounts = Get-InstallLegionPath 'agents'
    if (Test-Path -LiteralPath $configuration) { "Kept settings and notes: $configuration" }
    if (Test-Path -LiteralPath $accounts) { "Kept account folders and logins: $accounts" }
    if (Test-Path -LiteralPath $bin) { "Kept account launchers: $bin" }
    foreach ($entry in $script:installCatalog.tools) {
        foreach ($folder in (Get-UpdateConfigDirs -Tool $entry.id)) {
            if (-not $folder) { $folder = Resolve-LegionHomePath -Path $entry.plugin.defaultConfigDir -HomeRoot $homeRoot }
            if ($folder -and (Test-Path -LiteralPath $folder)) { "Kept config folder and login: $folder" }
        }
    }
    if ($ConfigDir -and (Test-Path -LiteralPath $ConfigDir)) { "Kept config folder and login: $ConfigDir" }
    'Kept repositories at their existing paths; CLIs and PowerShell at their existing install locations.'
    'You can delete kept data by hand if you no longer need it.'
}

function Get-InstallPluginVersion {
    param([string]$Root)
    return (Get-Content -LiteralPath (Join-Path $Root 'plugin.json') -Raw | ConvertFrom-Json).version
}

function Invoke-LegionUpdateSteps {
    param($Entry, [string]$ConfigDir, [switch]$DryRun, [string]$Source = 'BlackGad/ps-legion-marketplace', [ValidateSet('release','main')][string]$Ref = 'release', [string]$PluginRoot)
    $configEnv = $Entry.configEnv
    if (-not $PSBoundParameters.ContainsKey('PluginRoot')) { $PluginRoot = Get-InstallPluginRoot -Entry $Entry -ConfigDir $ConfigDir }
    $before = if ($PluginRoot) { Get-InstallPluginVersion -Root $PluginRoot } else { 'not installed' }
    if (-not $PluginRoot) {
        Invoke-LegionInstallSteps -Tool $Entry.id -Source $Source -ConfigEnv $configEnv -ConfigDir $ConfigDir -DryRun:$DryRun -Ref $Ref
    } else {
        foreach ($arguments in @($Entry.plugin.marketplaceUpdate, $Entry.plugin.update)) {
            if (-not $arguments.Count) { continue }
            $command = @($Entry.command) + $arguments
            Format-InstallCommand -Command $command -ConfigEnv $configEnv -ConfigDir $ConfigDir
            if (-not $DryRun) { Invoke-InstallCommand -Command $command -ConfigEnv $configEnv -ConfigDir $ConfigDir }
        }
    }
    if (-not $DryRun) {
        # The update may replace the cache path, so resolve the installed copy again.
        $root = Get-InstallPluginRoot -Entry $Entry -ConfigDir $ConfigDir
        if (-not $root) { throw "$($Entry.id) legion is absent from the post-update listing; generated artifacts were not refreshed." }
        $after = Get-InstallPluginVersion -Root $root
        Invoke-InstallRefresh -Entry $Entry -ConfigDir $ConfigDir -PluginRoot $root
        if ($before -ceq $after) { "skip: legion $after (already up to date)" }
        else { "legion $before -> $after" }
    }
}

function Invoke-InstallRefresh {
    param($Entry, [string]$ConfigDir, [string]$PluginRoot)
    if (-not $PluginRoot) { $PluginRoot = Get-InstallPluginRoot -Entry $Entry -ConfigDir $ConfigDir }
    if (-not $PluginRoot) { throw "$($Entry.id) legion is absent from the post-update listing; generated artifacts were not refreshed." }
    $refresh = Join-Path $PluginRoot 'bin/legion-refresh.ps1'
    if (-not (Test-Path -LiteralPath $refresh -PathType Leaf)) { throw "$($Entry.id) installed legion refresh script is missing." }
    $owner = Get-LegionTargetOwner -Tool $Entry -Folder $ConfigDir -HomeRoot (Get-InstallHome)
    foreach ($name in $(if ($IsWindows) { @('legion', 'legion.cmd') } else { @('legion') })) {
        Add-LegionFootprint -HomeRoot (Get-InstallHome) -Kind file -Path (Get-InstallLegionPath "bin/$name") -Owner $owner
    }
    $powerShell = (Get-Process -Id $PID).Path
    $environment = Get-InstallEnvironment -ConfigEnv $Entry.configEnv -ConfigDir $ConfigDir
    $result = Invoke-ClosedInput -Command @($powerShell, '-NoProfile', '-File', $refresh, '-HomeRoot', (Get-InstallHome)) -Environment $environment
    $result.Output
    $result.ErrorOutput
    if ($result.ExitCode -ne 0) { throw "legion artifact refresh exited $($result.ExitCode)" }
}

function Get-InstallVersion {
    param([string]$Text)
    if ($Text -match '\b(v?\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\b') { return $Matches[1] -replace '^v', '' }
    return ''
}

function Read-InstallPluginListing {
    param($Entry, [string[]]$Lines)
    $state = [pscustomobject]@{ Listed = $false; Enabled = $false; Path = @(); Version = ''; MarketplacePath = @() }
    $listing = $Entry.plugin.listing
    if ($listing.format -eq 'json') {
        try { $plugins = ($Lines -join "`n") | ConvertFrom-Json -ErrorAction Stop }
        catch { throw "$($Entry.id) plugin listing returned invalid JSON" }
        foreach ($plugin in @($plugins)) {
            if ($plugin.($listing.idField) -isnot [string] -or $plugin.($listing.idField) -cne 'legion@ps-legion-marketplace' -or $plugin.($listing.enabledField) -isnot [bool]) { continue }
            $state.Listed = $true
            $state.Enabled = $state.Enabled -or $plugin.($listing.enabledField)
            if ($plugin.installPath) { $state.Path += [string]$plugin.installPath }
            if ($plugin.version) { $state.Version = [string]$plugin.version }
        }
    } else {
        $isLegion = $false
        foreach ($line in $Lines) {
            if ($Entry.id -ceq 'copilot' -and $isLegion -and $line -match '^\s+from (.+?)\s*$') {
                $state.MarketplacePath += $Matches[1]
            }
            $isLegion = $line -match '(^|[\s`])legion@ps-legion-marketplace(\s|`|"|$)' -and $line -notmatch 'not installed'
            if (-not $isLegion) { continue }
            $state.Listed = $true
            $state.Enabled = $state.Enabled -or (-not $listing.rejectPattern -or $line -notmatch $listing.rejectPattern)
            $version = Get-InstallVersion $line
            if ($version) { $state.Version = $version }
            if ($line -match '\s((?:[A-Za-z]:[/\\]|/).+?)\s*$') { $state.Path += $Matches[1] }
        }
    }
    return $state
}

function Get-InstallPluginRoot {
    param($Entry, [string]$ConfigDir)
    $lines = @(Get-InstallListingLines -Entry $Entry -ConfigDir $ConfigDir)
    $listing = Read-InstallPluginListing -Entry $Entry -Lines $lines
    if (-not $listing.Listed) { return $null }
    $paths = @($listing.Path)
    $installedVersion = $listing.Version
    # Copilot directory marketplaces resolve only when a refresh root is needed.
    foreach ($marketplaceRoot in $listing.MarketplacePath) {
        try {
            $marketplace = Get-Content -LiteralPath (Join-Path $marketplaceRoot '.claude-plugin/marketplace.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            foreach ($plugin in $marketplace.plugins) {
                if ($plugin.name -ceq 'legion' -and $plugin.source -is [string]) { $paths += Join-Path $marketplaceRoot $plugin.source }
            }
        } catch { }
    }
    if (-not $paths.Count) {
        if (-not $Entry.plugin.installedRoot) { throw "$($Entry.id) plugin descriptor needs installedRoot to locate its installed refresh script." }
        if (-not $ConfigDir -and -not $Entry.plugin.defaultConfigDir) { throw "$($Entry.id) plugin descriptor needs defaultConfigDir to locate its installed refresh script." }
        $configRoot = if ($ConfigDir) { $ConfigDir } else { $Entry.plugin.defaultConfigDir }
        $configRoot = Resolve-LegionHomePath -Path $configRoot -HomeRoot (Get-InstallHome)
        $cacheRoot = Join-Path $configRoot $Entry.plugin.installedRoot
        if (Test-Path -LiteralPath $cacheRoot -PathType Container) {
            $manifestFolders = @('.claude-plugin', '.codex-plugin')
            $paths = @(Get-ChildItem -LiteralPath $cacheRoot -Filter plugin.json -File -Recurse -ErrorAction Stop |
                Where-Object { (Split-Path $_.DirectoryName -Leaf) -cnotin $manifestFolders } | ForEach-Object { $_.DirectoryName })
        }
    }
    $roots = @()
    foreach ($path in ($paths | Select-Object -Unique)) {
        try {
            $manifest = Get-Content -LiteralPath (Join-Path $path 'plugin.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($manifest.name -cne 'legion' -or ($installedVersion -and $manifest.version -cne $installedVersion)) { continue }
            $roots += $path
        } catch { continue }
    }
    if ($roots.Count -ne 1) {
        throw "$($Entry.id) installed legion folder could not be identified uniquely."
    }
    return $roots[0]
}

function Test-InstallCommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

# The PowerShell running the installer; a test seam.
function Get-InstallPowerShell {
    return (Get-Process -Id $PID).Path
}

# macOS and Linux: new shells find a portable PowerShell through ~/.legion/bin, which the profile line puts on PATH.
function Add-InstallPowerShellLink {
    param([string]$Target, [switch]$DryRun)
    $link = Get-InstallLegionPath 'bin/pwsh'
    $item = Get-Item -LiteralPath $link -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkTarget -ceq $Target) { 'skip: pwsh link (already done)'; return }
    if ($item) { "skip: $link (not legion's)"; return }
    "link $link to $Target"
    if ($DryRun) { return }
    Add-LegionFootprint -HomeRoot (Get-InstallHome) -Kind link -Path $link -Value $Target -Owner legion
    New-Item -ItemType Directory -Path (Split-Path $link) -Force | Out-Null
    $null = New-Item -ItemType SymbolicLink -Path $link -Target $Target
}

function Invoke-LegionInstaller {
    param([string[]]$Tools, [string]$Source = 'BlackGad/ps-legion-marketplace', [string]$ConfigDir, [switch]$DryRun, [switch]$Yes, $Catalog, [ValidateSet('release','main')][string]$Ref = 'release', [switch]$Update, [switch]$Uninstall, [switch]$Purge)
    $Tools = $Tools -split ','
    if ($Update -and $Uninstall) { throw 'Choose either -Update or -Uninstall.' }
    if ($Purge -and -not $Uninstall) { throw '-Purge requires -Uninstall.' }
    $script:installCatalog = Get-InstallCatalog -Source $Source -Ref $Ref -Catalog $Catalog
    $onWindows = $env:OS -eq 'Windows_NT'
    $powerShell = Get-InstallPowerShell
    $portable = Test-LegionPathUnder -Path $powerShell -Root (Get-InstallLegionPath 'tools/pwsh')
    # Windows: the stub already added the portable folder to the user PATH; record it for purge.
    if ($onWindows -and $portable -and -not $DryRun -and -not $Uninstall) {
        Add-LegionFootprint -HomeRoot (Get-InstallHome) -Kind path-entry -Path 'user PATH' -Value (Split-Path $powerShell -Parent) -Owner legion
    }
    if ($Uninstall) {
        Invoke-LegionUninstall -Tools $Tools -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes
        if ($Purge -and -not $script:installUninstallDeclined) { Invoke-LegionPurge -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes }
        return
    }
    if (-not $Tools -or $Tools.Count -eq 0) {
        $Tools = @($script:installCatalog.tools | Where-Object { Test-InstallCommandAvailable -Name $_.command } | ForEach-Object { $_.id })
    }
    if (-not $Tools -or $Tools.Count -eq 0) {
        'No coding CLI is installed. Install one, then run this script again:'
        foreach ($entry in $script:installCatalog.tools) { if ($entry.installHint) { $entry.installHint } }
        return
    }
    if ($Update) {
        $targets = @()
        foreach ($tool in $Tools) {
            $entry = Get-InstallTool -Tool $tool
            if (-not (Test-InstallCommandAvailable -Name $entry.command)) {
                "skip: $tool (not installed)"
                continue
            }
            foreach ($folder in (Get-UpdateConfigDirs -Tool $tool -ConfigDir $ConfigDir)) {
                $root = Get-InstallPluginRoot -Entry $entry -ConfigDir $folder
                $targets += @{ Entry=$entry; Folder=$folder; Root=$root }
                $version = if ($root) { Get-InstallPluginVersion -Root $root } else { 'not installed' }
                $label = if ($folder) { $folder } else { 'default config' }
                "Update legion for $tool in $label ($version)"
            }
        }
        if (-not $targets.Count) { return }
        if (-not $DryRun -and -not (Confirm-InstallChange -Yes:$Yes -Question 'Update legion? [y/N]')) {
            'Nothing changed. Run again with -Yes to apply.'
            return
        }
        $Source = Resolve-InstallSource -Source $Source
        foreach ($target in $targets) {
            Invoke-LegionUpdateSteps -Entry $target.Entry -ConfigDir $target.Folder -PluginRoot $target.Root -Source $Source -Ref $Ref -DryRun:$DryRun
        }
        if (-not $DryRun) { 'done: restart your sessions; run legion in the repository' }
        return
    }
    "Install legion for $($Tools -join ', ')"
    $bin = Get-InstallLegionPath 'bin'
    $pathQuestion = ''
    if ($onWindows -and -not (Test-InstallPathEntry -Path (Get-InstallUserPath) -Entry $bin -Separator ';')) {
        $pathQuestion = ', and add ~/.legion/bin to your PATH'
    }
    if (-not $onWindows -and -not (Get-LegionShellProfile -HomeRoot (Get-InstallHome)).HasPath) { $pathQuestion = ', and add ~/.legion/bin to your shell profile PATH' }
    if ($DryRun -and -not $onWindows) { Add-LegionUserPath -Folder $bin -HomeRoot (Get-InstallHome) -DryRun }
    if ($DryRun -and $portable -and -not $onWindows) { Add-InstallPowerShellLink -Target $powerShell -DryRun }
    if (-not $DryRun) {
        if (-not (Confirm-InstallChange -Yes:$Yes -Question "Install legion for $($Tools -join ', ') now${pathQuestion}? [y/N]")) {
            'Nothing changed. Run again with -Yes to apply.'
            return
        }
        Add-LegionUserPath -Folder $bin -HomeRoot (Get-InstallHome)
        if ($portable -and -not $onWindows) { Add-InstallPowerShellLink -Target $powerShell }
        if ($onWindows) {
            New-Item -ItemType Directory -Path $bin -Force | Out-Null
            if (-not (Test-LegionPathEntry -Path $env:PATH -Folder $bin)) { $env:PATH = $bin + [IO.Path]::PathSeparator + $env:PATH }
        }
    }
    $results = @()
    $Source = Resolve-InstallSource -Source $Source
    foreach ($tool in $Tools) {
        $entry = Get-InstallTool -Tool $tool
        $configEnv = $entry.configEnv
        foreach ($folder in (Get-UpdateConfigDirs -Tool $tool -ConfigDir $ConfigDir)) {
            Invoke-LegionInstallSteps -Tool $tool -Source $Source -ConfigEnv $configEnv -ConfigDir $folder -DryRun:$DryRun -Ref $Ref
            if (-not $DryRun) {
                try {
                    $root = Get-InstallPluginRoot -Entry $entry -ConfigDir $folder
                    $pluginVersion = Get-InstallPluginVersion -Root $root
                    Invoke-InstallRefresh -Entry $entry -ConfigDir $folder -PluginRoot $root
                } catch {
                    $label = if ($folder) { $folder } else { 'default config' }
                    "commands not refreshed for $tool in $label; run legion setup"
                }
            }
        }
        if (-not $DryRun) {
            $version = (& $entry.command --version 2>$null | Select-Object -First 1)
            $hooks = $entry.hooks.status
            $results += [pscustomobject]@{ Tool = $tool; Version = $version; Plugin = 'legion'; Hooks = $hooks }
        }
        if ($entry.hooks.hint) { $entry.hooks.hint }
    }
    if (-not $DryRun) {
        $results | Format-Table Tool, Version, Plugin, Hooks -AutoSize
        "installed: legion $pluginVersion ($Ref)"
        'next: legion add claude (or legion in a repository)'
    }
}

if (-not $NoRun) {
    $catalog = $null
    # The expanded installer uses its matching catalog unless Source selects other data.
    if (-not $PSBoundParameters.ContainsKey('Source') -and
        $PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools.json') -PathType Leaf)) {
        $catalog = Get-InstallCatalog -Catalog (ConvertFrom-InstallCatalogJson -Text (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.json') -Raw))
    }
    Invoke-LegionInstaller -Tools $Tools -Source $Source -Ref $Ref -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes -Update:$Update -Uninstall:$Uninstall -Purge:$Purge -Catalog $catalog
}
