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

if ($PSVersionTable.PSVersion.Major -lt 7) { throw 'The legion installer requires PowerShell 7. Run the root install.ps1 bootstrap with Windows PowerShell 5.1.' }
if (-not $PSScriptRoot) { throw 'Run the legion installer from the expanded archive; script text has no PSScriptRoot.' }
$pathsLibrary = Join-Path $PSScriptRoot 'bin/lib/paths.ps1'
if (-not (Test-Path -LiteralPath $pathsLibrary -PathType Leaf)) { throw 'The legion installer requires bin/lib/paths.ps1 from the expanded archive.' }
. $pathsLibrary
$script:installPathComparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }

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
        if (-not $content.TrimStart().StartsWith('{')) { throw 'invalid catalog root: expected object' }
        $jsonOptions = @{ ErrorAction = 'Stop' }
        if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $jsonOptions.DateKind = 'String' }
        $Catalog = $content | ConvertFrom-Json @jsonOptions
    }
    if ($null -eq $Catalog -or $Catalog.schemaVersion -ne 1) {
        throw 'unsupported tools catalog schemaVersion (expected 1)'
    }
    if ($Catalog.tools -isnot [array]) { throw 'invalid catalog tools: expected array' }
    return $Catalog
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
    param([string[]]$Command, [ValidateSet('marketplace','plugin')][string]$Kind = 'plugin', [string]$ConfigEnv, [string]$ConfigDir, [switch]$IncludeDisabled, [switch]$RequireRoot)
    $entry = $script:installCatalog.tools | Where-Object command -CEQ $Command[0] | Select-Object -First 1
    if (-not $entry) { throw "unknown tool command '$($Command[0])'" }
    $lines = @(Get-InstallListingLines -Entry $entry -Kind $Kind -ConfigDir $ConfigDir)
    return Test-InstallListing -Kind $Kind -Tool $entry.id -Lines $lines -IncludeDisabled:$IncludeDisabled -RequireRoot:$RequireRoot
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

function Invoke-LegionInstallSteps {
    param([string]$Tool, [string]$Source, [string]$ConfigEnv, [string]$ConfigDir, [switch]$DryRun, [ValidateSet('release','main')][string]$Ref = 'release')
    $commands = Get-InstallCommands -Tool $Tool -Source $Source -Ref $Ref
    $entry = Get-InstallTool -Tool $Tool
    if (-not $DryRun -and $ConfigDir -and -not (Test-Path -LiteralPath $ConfigDir -PathType Container)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force -ErrorAction Stop | Out-Null
    }
    $marketplaceAdded = $false
    for ($index = 0; $index -lt $commands.Count; $index++) {
        $command = $commands[$index]
        $kind = if ($index -eq 0) { 'marketplace' } else { 'plugin' }
        if (-not $marketplaceAdded -and (Test-InstallStepDone -Command $command -Kind $kind -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir)) {
            if ($index -ne 0) {
                "skip: $($command -join ' ') (already done)"
                continue
            }
            $rootReady = $true
            if ($entry.plugin.marketplaceListing.rootField) {
                $rootReady = Test-InstallStepDone -Command $command -Kind marketplace -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir -RequireRoot
            }
            $pluginReady = Test-InstallStepDone -Command $commands[1] -Kind plugin -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir
            if ($rootReady -and $pluginReady) {
                "skip: $($command -join ' ') (already done)"
                "skip: $($commands[1] -join ' ') (already done)"
                return
            }
            if (-not $entry.plugin.marketplaceUpdate.Count) { throw "$Tool has no marketplace refresh command" }
        } else {
            if ($DryRun) { Format-InstallCommand -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
            else { Invoke-InstallCommand -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
        }
        if ($index -eq 0) {
            $marketplaceAdded = $true
            if ($entry.plugin.marketplaceUpdate.Count) {
                $refresh = @($entry.command) + $entry.plugin.marketplaceUpdate
                if ($DryRun) { Format-InstallCommand -Command $refresh -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
                else { Invoke-InstallCommand -Command $refresh -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
            }
        }
    }
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

function Get-InstallOwnerPath {
    param([ValidateSet('Settings', 'Notes', 'Update', 'Runtime', 'Install')][string]$Name,
        [string]$HomeRoot = (Get-InstallHome))
    return Get-LegionOwnerPath -Name $Name -HomeRoot $HomeRoot
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
    return [string]::Equals($selected, $profileHome, $script:installPathComparison)
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
    $file = Get-InstallOwnerPath -Name Settings
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

# The owner commands legion creates, and the bin script each one calls.
function Get-InstallOwnerCommands {
    return [ordered]@{ 'legion' = 'legion.ps1' }
}

# Same rule as lib/commands.ps1: the whole file is the generated launcher,
# one line whose -File argument is the script, and a .cmd file writes % as %%.
# Returns the script path and its span, or nothing when the file is not a legion command.
function Get-InstallOwnerCommandTarget {
    param([string]$Path, [string]$Script)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $text = [IO.File]::ReadAllText($Path)
    $launcher = '\A(?:#![^\r\n]*\r?\n)?(?:[ \t]*\r?\n)*[ \t]*(?:exec[ \t]+|@)?pwsh[ \t]+(?:-\S+[ \t]+)*?-File[ \t]+'
    $scriptWord = '(?<target>(?:''[^''\r\n]*''|"[^"\r\n]*"|[^\s''"]+)+)'
    $match = [regex]::Match($text, $launcher + $scriptWord)
    if (-not $match.Success) { return }
    # Batch double quotes keep dollar signs literal; shell double quotes expand them.
    $argument = '(?<argument>(?:''[^''\r\n]*''|"[^"$`\r\n]*")+|"\$@"|\$@|%\*|[\w.=:/\\-]+)'
    $batchExit = ''
    if ([IO.Path]::GetExtension($Path) -ieq '.cmd') { $argument = '(?<argument>"[^"\r\n]*"|%\*|[\w.=:/\\-]+)'; $batchExit = '(?:[ \t]+&[ \t]+\(goto\)[ \t]+2>nul[ \t]+&[ \t]+exit[ \t]+/b)?' }
    $tail = $text.Substring($match.Length)
    if ($tail -notmatch ('\A(?:[ \t]+' + $argument + ')*' + $batchExit + '\s*\z')) { return }
    $word = $match.Groups['target']
    $target = $word.Value -replace '''([^'']*)''|"([^"]*)"', '$1$2'
    if ([IO.Path]::GetExtension($Path) -ieq '.cmd') { $target = $target.Replace('%%', '%') }
    $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if ($target.Replace('\', '/').EndsWith("/bin/$Script", $comparison)) {
        return [pscustomobject]@{ Path=$target; Start=$word.Index; Length=$word.Length }
    }
}

# Retarget only the generated script argument, keeping the owner's flags verbatim.
function Set-InstallOwnerCommandTarget {
    param([string]$Path, [string]$Script, [string]$Runner)
    $target = Get-InstallOwnerCommandTarget -Path $Path -Script $Script
    if (-not $target) { return }
    $literal = if ([IO.Path]::GetExtension($Path) -ieq '.cmd') { '"' + $Runner.Replace('%', '%%') + '"' }
        else { "'" + $Runner.Replace("'", "'`"'`"'") + "'" }
    $text = [IO.File]::ReadAllText($Path)
    $bin = [IO.Path]::GetFullPath((Get-InstallLegionPath 'bin'))
    if (-not (Test-InstallGeneratedPathSafe -Path $Path -Bin $bin)) { return }
    [IO.File]::WriteAllText($Path, $text.Substring(0, $target.Start) + $literal + $text.Substring($target.Start + $target.Length))
}

function Test-InstallOwnerCommandFile {
    param([string]$Path, [string]$Script)
    return [bool](Get-InstallOwnerCommandTarget -Path $Path -Script $Script)
}

function Get-InstallOwnerCommandPaths {
    param([string]$Bin)
    $owner = Get-InstallOwnerCommands
    foreach ($command in $owner.Keys) {
        foreach ($name in @($command, "$command.cmd")) {
            $path = Join-Path $Bin $name
            if (Test-InstallOwnerCommandFile -Path $path -Script $owner[$command]) { $path }
        }
    }
}

# Owner commands whose script is gone, or lives in a folder this uninstall is about to remove.
function Get-InstallDeadCommandPaths {
    param([string[]]$RemovedFolders = @())
    $bin = [IO.Path]::GetFullPath((Get-InstallLegionPath 'bin'))
    $owner = Get-InstallOwnerCommands
    foreach ($command in $owner.Keys) {
        foreach ($name in @($command, "$command.cmd")) {
            $path = Join-Path $bin $name
            $target = Get-InstallOwnerCommandTarget -Path $path -Script $owner[$command]
            if (-not $target) { continue }
            $scriptGone = -not (Test-Path -LiteralPath $target.Path -PathType Leaf)
            $insideRemoved = $false
            $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            foreach ($folder in $RemovedFolders) {
                $prefix = [IO.Path]::GetFullPath($folder).TrimEnd('\', '/') +[IO.Path]::DirectorySeparatorChar
                if ([IO.Path]::GetFullPath($target.Path).StartsWith($prefix, $comparison)) { $insideRemoved = $true }
            }
            if (($scriptGone -or $insideRemoved) -and (Test-InstallGeneratedPathSafe -Path $path -Bin $bin)) { $path }
        }
    }
}

# Installs that stay after this uninstall: the plugin is installed there and no target removes it.
function Get-UninstallSurvivors {
    param($Targets)
    $removed = @()
    foreach ($target in $Targets) {
        if (@($target.Steps | Where-Object Kind -CEQ 'plugin').Count) { $removed += Get-InstallFolderKey -Entry $target.Entry -Folder $target.Folder }
    }
    foreach ($entry in $script:installCatalog.tools) {
        if (-not (Test-InstallCommandAvailable -Name $entry.command)) { continue }
        $folders = Get-UpdateConfigDirs -Tool $entry.id
        # An environment override does not hide an install in the physical default folder.
        if ($entry.plugin.defaultConfigDir) { $folders += Resolve-InstallConfigDir $entry.plugin.defaultConfigDir }
        $seen = @()
        foreach ($folder in $folders) {
            $key = Get-InstallFolderKey -Entry $entry -Folder $folder
            if ($removed -ccontains $key -or $seen -ccontains $key) { continue }
            $seen += $key
            try {
                $root = Get-InstallPluginRoot -Entry $entry -ConfigDir $folder
                if ($root) { [pscustomobject]@{ Entry=$entry; Folder=$folder; Root=$root } }
            } catch {
                Write-Host "kept: shared commands (could not read $($entry.id) plugins; check them after uninstall)"
                # A null root records uncertainty, so neither removal nor repair can touch shared commands.
                [pscustomobject]@{ Entry=$entry; Folder=$folder; Root=$null }
            }
        }
    }
}

# The same install seen from a target and from the folder list: '' is the CLI's default folder.
function Get-InstallFolderKey {
    param($Entry, [string]$Folder)
    if (-not $Folder) { $Folder = $Entry.plugin.defaultConfigDir }
    $key = $Entry.id + '|' + $(if ($Folder) { Resolve-InstallConfigDir $Folder } else { '' })
    if ($env:OS -eq 'Windows_NT') { return $key.ToLowerInvariant() }
    return $key
}

# After an uninstall, a command whose script is gone moves to a surviving install, or is removed when none is left.
# Only the commands the plan listed are removed; anything else that went dead is reported and kept.
function Repair-InstallOwnerCommands {
    param($Survivors = @(), [string[]]$Planned = @())
    if (@($Survivors | Where-Object { -not $_.Root }).Count) { return }
    $owner = Get-InstallOwnerCommands
    foreach ($path in (Get-InstallDeadCommandPaths)) {
        $scriptName = $owner[([IO.Path]::GetFileName($path) -replace '\.cmd$', '')]
        $runner = $Survivors | ForEach-Object { Join-Path $_.Root "bin/$scriptName" } | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
        if ($runner) { Set-InstallOwnerCommandTarget -Path $path -Script $scriptName -Runner $runner }
        elseif ($Planned -ccontains $path) {
            # Re-read ownership and links immediately before deleting a planned command.
            if (@(Get-InstallDeadCommandPaths) -ccontains $path) {
                Remove-Item -LiteralPath $path -Force -ErrorAction Stop
                "Removed command: $path"
            }
        }
        else { "Kept command: $path (its script is gone; it was not in the plan)" }
    }
}

function Get-UninstallFiles {
    param([string[]]$Tools, [string]$ConfigDir, $Owner, [switch]$KeepOwnerCommands)
    $homeRoot = Get-InstallHome
    $bin = [IO.Path]::GetFullPath((Get-InstallLegionPath 'bin'))
    $paths = @()
    $unselectedLauncher = $false
    foreach ($agent in $Owner.agents) {
        if ($agent.id -cnotmatch '^[a-z][a-z0-9-]*$') { continue }
        $selected = -not $Tools -or $agent.tool -cin $Tools
        if ($ConfigDir) {
            $folder = $agent.configDir
            if ($folder -match '^~[/\\]') { $folder = Join-Path $homeRoot $folder.Substring(2) }
            $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            $selected = $selected -and $folder -and [string]::Equals([IO.Path]::GetFullPath($folder).TrimEnd('\', '/'), [IO.Path]::GetFullPath($ConfigDir).TrimEnd('\', '/'), $comparison)
        }
        foreach ($suffix in @('', '.cmd')) {
            $path = Join-Path $bin "$($agent.id)$suffix"
            if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
            $header = if ($suffix) { "@rem Generated by legion: account $($agent.id)" } else { "# Generated by legion: account $($agent.id)" }
            if (-not @([IO.File]::ReadAllLines($path) | Where-Object { $_ -ceq $header }).Count) { continue }
            # Launchers survive uninstall; an unselected account still needs the shared runtime.
            if (-not $selected) { $unselectedLauncher = $true }
        }
    }
    if (-not $unselectedLauncher) {
        if (-not $KeepOwnerCommands) { $paths += Get-InstallOwnerCommandPaths -Bin $bin }
        # Exact files published by Sync-LegionFoundryRuntime; never remove the directory tree.
        $runtime = Get-InstallOwnerPath -Name Runtime
        foreach ($name in (Get-LegionRuntimeFiles)) {
            $paths += Join-Path $runtime $name
        }
        foreach ($entry in $script:installCatalog.tools) {
            foreach ($name in @('SKILL.md', 'tool.json', 'scripts/foundry-config.ps1', 'scripts/foundry-launch.ps1')) {
                $paths += Join-Path $runtime "skills/legion-$($entry.id)/$name"
            }
        }
    }
    foreach ($path in ($paths | Select-Object -Unique)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        if (Test-InstallGeneratedPathSafe -Path $path -Bin $bin) { $path }
    }
}

# A linked file or ancestor belongs to its owner; check through the selected home.
function Test-InstallGeneratedPathSafe {
    param([string]$Path, [string]$Bin)
    $currentPath = [IO.Path]::GetFullPath($Path)
    if (-not $currentPath.StartsWith($Bin + [IO.Path]::DirectorySeparatorChar, $script:installPathComparison)) { throw 'Unsafe generated file path' }
    $homeRoot = [IO.Path]::GetFullPath((Get-InstallHome)).TrimEnd('\', '/')
    if (-not $currentPath.StartsWith($homeRoot + [IO.Path]::DirectorySeparatorChar, $script:installPathComparison)) { throw 'Unsafe generated file path' }
    if (-not (Test-LegionOwnerPathSafe -Path $currentPath -StopRoot (Get-InstallHome))) {
        Write-Host "skip: $Path (linked folder)"
        return $false
    }
    return $true
}

function Get-UninstallCachePath {
    param($Entry, [string]$ConfigDir)
    if (-not $Entry.plugin.cacheDir) { return }
    if (-not $ConfigDir) {
        if (-not $Entry.plugin.defaultConfigDir) { throw 'Missing plugin.defaultConfigDir for cache cleanup' }
        $ConfigDir = Join-Path (Get-InstallHome) $Entry.plugin.defaultConfigDir.Substring(2)
    }
    return Get-InstallSafePath -Root $ConfigDir -Relative $Entry.plugin.cacheDir
}

function Get-InstallSafePath {
    param([string]$Root, $Relative, [switch]$AllowFile)
    # Catalogs are generated and schema-checked, but deletion paths must still be exact and relative.
    if ($Relative -isnot [string] -or [string]::IsNullOrWhiteSpace($Relative) -or
        $Relative -match '(^[/\\~]|:|(^|[/\\])\.{1,2}([/\\]|$)|[*?]|[/\\]$|[/\\]{2})') {
        throw 'Unsafe relative path: expected an exact path under the root'
    }
    $rootPath = [IO.Path]::GetFullPath($Root)
    $path = [IO.Path]::GetFullPath((Join-Path $rootPath $Relative))
    $prefix = $rootPath.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    if (-not $path.StartsWith($prefix, $script:installPathComparison)) { throw 'Unsafe path outside the root' }
    if (-not (Test-Path -LiteralPath $path)) { return }
    if (-not $AllowFile -and -not (Test-Path -LiteralPath $path -PathType Container)) { return }
    $homeRoot = [IO.Path]::GetFullPath((Get-InstallHome))
    $homePrefix = $homeRoot.TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
    # Selected config folders may live outside home; home paths never walk above it.
    $stopRoot = if ($path.StartsWith($homePrefix, $script:installPathComparison)) { $homeRoot } else { [IO.Path]::GetPathRoot($path) }
    if (-not (Test-LegionOwnerPathSafe -Path $path -StopRoot $stopRoot)) {
        Write-Host "skip: plugin cache $path (linked folder)"
        return
    }
    $pending = [Collections.Generic.Stack[string]]::new()
    if (Test-Path -LiteralPath $path -PathType Container) { $pending.Push($path) }
    while ($pending.Count) {
        foreach ($item in (Get-ChildItem -LiteralPath $pending.Pop() -Force -ErrorAction Stop)) {
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
    param([string]$Text, [string]$Kind)
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
        if ($Kind -eq 'marketplaces') {
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
        $entries += if ($member.Key -eq '*') { 'installedPlugins: legion@ps-legion-marketplace' } else { $member.Key }
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
    param([string]$Path, [string]$Kind)
    $before = [IO.File]::ReadAllBytes($Path)
    $encoding = New-Object Text.UTF8Encoding ($false, $true)
    $bom = 0
    if ($before.Length -ge 3 -and $before[0] -eq 239 -and $before[1] -eq 187 -and $before[2] -eq 191) { $bom = 3 }
    elseif ($before.Length -ge 2 -and $before[0] -eq 255 -and $before[1] -eq 254) { $encoding = New-Object Text.UnicodeEncoding ($false, $false, $true); $bom=2 }
    elseif ($before.Length -ge 2 -and $before[0] -eq 254 -and $before[1] -eq 255) { $encoding = New-Object Text.UnicodeEncoding ($true, $false, $true); $bom=2 }
    try {
        $text = $encoding.GetString($before, $bom, $before.Length - $bom)
        $result = if ($Kind -eq 'toml') { Get-InstallPurgeTomlText -Text $text } else { Get-InstallPurgeJsonText -Text $text -Kind $Kind }
        if (-not $result.Entries.Count) { return }
        $after = $encoding.GetBytes($result.Text)
        if ($bom) { $after = [byte[]]($before[0..($bom - 1)] + $after) }
        return [pscustomobject]@{ Path=$Path; Before=$before; After=$after; Entries=$result.Entries }
    } catch {
        # Do not print settings contents or parser errors that could contain secrets.
        return [pscustomobject]@{ Manual=$true; Path=$Path }
    }
}

function Get-InstallPurgePlan {
    param([string]$ConfigDir)
    # Purge is global even if the preceding uninstall selected only some targets.
    $paths = @()
    $edits = @()
    $editedPaths = [Collections.Generic.HashSet[string]]::new((Get-LegionPathComparer))
    $manualSteps = @()
    $pathEntries = @((Get-InstallLegionPath 'bin'), (Get-InstallLegionPath 'tools/pwsh'))
    $userPath = if ($env:OS -eq 'Windows_NT') { Get-InstallUserPath } else { '' }
    $keptPath = @()
    $removedPath = @()
    foreach ($part in ($userPath -split ';')) {
        $owned = $false
        foreach ($entry in $pathEntries) {
            if (Test-InstallPathEntry -Path $part -Entry $entry -Separator ';') { $owned=$true; break }
        }
        if ($owned) { $removedPath += $part } else { $keptPath += $part }
    }
    $processPath = $env:PATH
    $processSeparator = [string][IO.Path]::PathSeparator
    $keptProcessPath = @()
    $removedProcessPath = @()
    if ($env:OS -eq 'Windows_NT') {
        foreach ($part in ($processPath -split [regex]::Escape($processSeparator))) {
            $owned = $false
            foreach ($entry in $pathEntries) {
                if (Test-InstallPathEntry -Path $part -Entry $entry -Separator $processSeparator) { $owned=$true; break }
            }
            if ($owned) { $removedProcessPath += $part } else { $keptProcessPath += $part }
        }
    }
    $seen = @()
    foreach ($entry in $script:installCatalog.tools) {
        $folders = Get-UpdateConfigDirs -Tool $entry.id
        if ($entry.plugin.defaultConfigDir) { $folders += Resolve-InstallConfigDir $entry.plugin.defaultConfigDir }
        if ($ConfigDir) { $folders += Resolve-InstallConfigDir $ConfigDir }
        foreach ($folder in $folders) {
            if (-not $folder -and $entry.plugin.defaultConfigDir) { $folder = Resolve-InstallConfigDir $entry.plugin.defaultConfigDir }
            if (-not $folder) { continue }
            $key = Get-InstallFolderKey -Entry $entry -Folder $folder
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
                    $edit = Get-InstallPurgeEdit -Path $path -Kind $setting.kind
                    if ($edit.Manual) { $manualSteps += "Manual step: $path (remove its legion entries; could not match them safely)" }
                    elseif ($edit) { $edits += $edit; [void]$editedPaths.Add($path) }
                }
            }
        }
    }
    $legion = Get-InstallSafePath -Root (Get-InstallHome) -Relative '.legion' 6>$null
    if (-not $legion -and (Test-Path -LiteralPath (Get-InstallLegionPath ''))) { $manualSteps += 'Manual step: legion home contains linked paths; left in place.' }
    return [pscustomobject]@{
        Paths=$paths; Edits=$edits; Legion=$legion; HomeRoot=(Get-InstallHome); ManualSteps=$manualSteps
        UserPath=[pscustomobject]@{ Before=$userPath; After=($keptPath -join ';'); Entries=$removedPath }
        ProcessPath=[pscustomobject]@{ Before=$processPath; After=($keptProcessPath -join $processSeparator); Entries=$removedProcessPath }
        HasWork=[bool]($paths.Count -or $edits.Count -or $legion -or $removedPath.Count -or $removedProcessPath.Count)
    }
}

function Show-InstallPurgePlan {
    param($Plan)
    foreach ($entry in $Plan.UserPath.Entries) { "Remove user PATH entry: $entry" }
    foreach ($entry in $Plan.ProcessPath.Entries) { "Remove process PATH entry: $entry" }
    foreach ($edit in $Plan.Edits) { foreach ($name in $edit.Entries) { "Remove entry: $($edit.Path): $name" } }
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
        $safe = Get-InstallSafePath -Root (Split-Path $edit.Path) -Relative ([IO.Path]::GetFileName($edit.Path)) -AllowFile
        if (-not $safe -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($edit.Path)) -cne [Convert]::ToBase64String($edit.Before)) { throw 'Settings changed after preview; run purge again.' }
        [IO.File]::WriteAllBytes($edit.Path, $edit.After)
    }
    foreach ($item in $Plan.Paths) {
        $safe = Get-InstallSafePath -Root $item.Root -Relative $item.Relative -AllowFile
        if (-not $safe -or $safe -cne $item.Path) { continue }
        if ($item.EmptyOnly -and @(Get-ChildItem -LiteralPath $safe -Force).Count) { continue }
        Remove-Item -LiteralPath $safe -Recurse -Force -ErrorAction Stop
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
    $file = Get-InstallOwnerPath -Name Settings
    $owner = $null
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $owner = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    $targets = @()
    $selectedTools = if ($Tools) { $Tools } else { @($script:installCatalog.tools | ForEach-Object { $_.id }) }
    foreach ($tool in ($selectedTools | Select-Object -Unique)) {
        $entry = Get-InstallTool -Tool $tool
        if (-not (Test-InstallCommandAvailable -Name $entry.command)) { "skip: $tool (not installed)"; continue }
        foreach ($folder in (Get-UpdateConfigDirs -Tool $tool -ConfigDir $ConfigDir)) {
            $label = if ($folder) { $folder } else { 'default config' }
            # In a chosen home the tool's default folder may not exist; then nothing is installed there.
            $isHomeDefault = $folder -and (Get-InstallFolderKey -Entry $entry -Folder $folder) -ceq (Get-InstallFolderKey -Entry $entry)
            if ($isHomeDefault -and -not (Test-InstallRealProfile) -and -not (Test-Path -LiteralPath $folder)) { "skip: $tool plugin in $label (not installed)"; continue }
            $steps = @()
            foreach ($kind in @('plugin', 'marketplace')) {
                $check = if ($kind -eq 'plugin') { @($entry.command) + $entry.plugin.install }
                    else { @($entry.command) + @($entry.plugin.marketplaceAdd | ForEach-Object { if ($_ -ceq '{source}') { '' } else { $_ } }) }
                if (-not (Test-InstallStepDone -Command $check -Kind $kind -ConfigEnv $entry.configEnv -ConfigDir $folder -IncludeDisabled)) {
                    "skip: $tool $kind in $label (not installed)"
                    continue
                }
                $arguments = if ($kind -eq 'plugin') { $entry.plugin.uninstall } else { $entry.plugin.marketplaceRemove }
                $steps += [pscustomobject]@{ Kind=$kind; Check=$check; Command=(@($entry.command) + $arguments) }
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
    # Find the installs that stay before removing anything; their commands must keep working.
    $bin = [IO.Path]::GetFullPath((Get-InstallLegionPath 'bin'))
    $survivors = @()
    if (@(Get-InstallOwnerCommandPaths -Bin $bin).Count) { $survivors = @(Get-UninstallSurvivors -Targets $targets) }
    $uncertain = @($survivors | Where-Object { -not $_.Root }).Count -gt 0
    $files = @(Get-UninstallFiles -Tools $Tools -ConfigDir $ConfigDir -Owner $owner -KeepOwnerCommands:($survivors.Count -gt 0))
    foreach ($path in $files) { "Remove file: $path" }
    if (-not $files.Count) { 'skip: legion generated files (not installed)' }
    $hasWork = $targets.Count -or $files.Count
    # A survivor can keep only commands whose script it actually provides.
    $plannedDead = @()
    if ($hasWork -and -not $uncertain) {
        $removedFolders = @($targets | Where-Object Cache | ForEach-Object { $_.Cache })
        $ownerCommands = Get-InstallOwnerCommands
        $plannedDead = @(Get-InstallDeadCommandPaths -RemovedFolders $removedFolders | Where-Object {
            $scriptName = $ownerCommands[([IO.Path]::GetFileName($_) -replace '\.cmd$', '')]
            $provided = @($survivors | Where-Object { Test-Path -LiteralPath (Join-Path $_.Root "bin/$scriptName") -PathType Leaf }).Count
            $files -cnotcontains $_ -and -not $provided
        })
    }
    foreach ($path in $plannedDead) { "Remove dead command: $path" }
    'Channel plugins and their state remain in place.'
    if (-not $hasWork) { 'Nothing to uninstall.' }
    if ($hasWork -and -not $DryRun -and ($Yes -or (Read-Host 'Uninstall legion from these targets? [y/N]') -match '^(?i:y|yes)$')) {
        foreach ($target in $targets) {
            $entry = $target.Entry
            foreach ($step in $target.Steps) {
                if (-not (Test-InstallStepDone -Command $step.Check -Kind $step.Kind -ConfigEnv $entry.configEnv -ConfigDir $target.Folder -IncludeDisabled)) {
                    "skip: $($entry.id) $($step.Kind) in $(if ($target.Folder) { $target.Folder } else { 'default config' }) (not installed)"
                    continue
                }
                Invoke-InstallCommand -Command $step.Command -ConfigEnv $entry.configEnv -ConfigDir $target.Folder
            }
            if ($target.Cache) {
                $check = @($entry.command) + $entry.plugin.install
                if (Test-InstallStepDone -Command $check -Kind plugin -ConfigEnv $entry.configEnv -ConfigDir $target.Folder -IncludeDisabled) {
                    throw "$($entry.id) plugin is still listed; cache kept."
                }
                # Recheck the exact descriptor path and links immediately before recursive deletion.
                $cache = Get-UninstallCachePath -Entry $entry -ConfigDir $target.Folder
                if ($cache -and $cache -ceq $target.Cache) {
                    Remove-Item -LiteralPath $cache -Recurse -Force -ErrorAction Stop
                }
            }
        }
        foreach ($path in $files) {
            # The preview is not ownership: a file or any ancestor may have changed since then.
            if (@(Get-UninstallFiles -Tools $Tools -ConfigDir $ConfigDir -Owner $owner -KeepOwnerCommands:($survivors.Count -gt 0)) -cnotcontains $path) { continue }
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            $parent = Split-Path $path -Parent
            while ($parent.Length -gt $bin.Length -and -not @(Get-ChildItem -LiteralPath $parent -Force -ErrorAction Stop).Count) {
                if (-not (Test-InstallGeneratedPathSafe -Path $parent -Bin $bin)) { break }
                Remove-Item -LiteralPath $parent -ErrorAction Stop
                $parent = Split-Path $parent -Parent
            }
        }
        Repair-InstallOwnerCommands -Survivors $survivors -Planned $plannedDead
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
            if (-not $folder) {
                $folder = $entry.plugin.defaultConfigDir
                if ($folder -match '^~[/\\]') { $folder = Join-Path $homeRoot $folder.Substring(2) }
            }
            if ($folder -and (Test-Path -LiteralPath $folder)) { "Kept config folder and login: $folder" }
        }
    }
    if ($ConfigDir -and (Test-Path -LiteralPath $ConfigDir)) { "Kept config folder and login: $ConfigDir" }
    'Kept repositories at their existing paths; CLIs and PowerShell at their existing install locations.'
    'You can delete kept data by hand if you no longer need it.'
}

function Invoke-LegionUpdateSteps {
    param($Entry, [string]$ConfigDir, [switch]$DryRun, [string]$Source = 'BlackGad/ps-legion-marketplace', [ValidateSet('release','main')][string]$Ref = 'release', [string]$PluginRoot)
    $configEnv = $Entry.configEnv
    if (-not $PSBoundParameters.ContainsKey('PluginRoot')) { $PluginRoot = Get-InstallPluginRoot -Entry $Entry -ConfigDir $ConfigDir }
    $before = if ($PluginRoot) { (Get-Content -LiteralPath (Join-Path $PluginRoot 'plugin.json') -Raw | ConvertFrom-Json).version } else { 'not installed' }
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
        $after = (Get-Content -LiteralPath (Join-Path $root 'plugin.json') -Raw | ConvertFrom-Json).version
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

function Invoke-LegionInstaller {
    param([string[]]$Tools, [string]$Source = 'BlackGad/ps-legion-marketplace', [string]$ConfigDir, [switch]$DryRun, [switch]$Yes, $Catalog, [ValidateSet('release','main')][string]$Ref = 'release', [switch]$Update, [switch]$Uninstall, [switch]$Purge)
    if ($Update -and $Uninstall) { throw 'Choose either -Update or -Uninstall.' }
    if ($Purge -and -not $Uninstall) { throw '-Purge requires -Uninstall.' }
    $script:installCatalog = Get-InstallCatalog -Source $Source -Ref $Ref -Catalog $Catalog
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
                $version = if ($root) { (Get-Content -LiteralPath (Join-Path $root 'plugin.json') -Raw | ConvertFrom-Json).version } else { 'not installed' }
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
    $onWindows = $env:OS -eq 'Windows_NT'
    $bin = Get-InstallLegionPath 'bin'
    $pathQuestion = ''
    if ($onWindows -and -not (Test-InstallPathEntry -Path (Get-InstallUserPath) -Entry $bin -Separator ';')) {
        $pathQuestion = ', and add ~/.legion/bin to your PATH'
    }
    if (-not $DryRun) {
        if (-not (Confirm-InstallChange -Yes:$Yes -Question "Install legion for $($Tools -join ', ') now${pathQuestion}? [y/N]")) {
            'Nothing changed. Run again with -Yes to apply.'
            return
        }
        if ($onWindows) {
            New-Item -ItemType Directory -Path $bin -Force | Out-Null
            Add-InstallPowerShellPath -Path $bin
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
                    $pluginVersion = (Get-Content -LiteralPath (Join-Path $root 'plugin.json') -Raw | ConvertFrom-Json).version
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
        if (-not $onWindows -and -not (Test-InstallPathEntry -Path $env:PATH -Entry $bin -Separator ([string][IO.Path]::PathSeparator))) {
            'add to your shell profile: export PATH="$HOME/.legion/bin:$PATH"'
        }
        "installed: legion $pluginVersion ($Ref)"
        'next: legion add claude (or legion in a repository)'
    }
}

if (-not $NoRun) {
    $catalog = $null
    # The expanded installer uses its matching catalog unless Source selects other data.
    if (-not $PSBoundParameters.ContainsKey('Source') -and
        $PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools.json') -PathType Leaf)) {
        $catalog = Get-InstallCatalog -Catalog (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.json') -Raw | ConvertFrom-Json)
    }
    Invoke-LegionInstaller -Tools $Tools -Source $Source -Ref $Ref -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes -Update:$Update -Uninstall:$Uninstall -Purge:$Purge -Catalog $catalog
}
