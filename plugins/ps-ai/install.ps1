param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-ai-marketplace',
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

# Standalone: this file also runs as downloaded script text in Windows PowerShell 5.1.
function Get-InstallSourceText {
    param([string]$Url)
    $ProgressPreference = 'SilentlyContinue'
    return (Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop).Content
}

function Assert-InstallString {
    param($Value, [string]$Field, [switch]$AllowEmpty)
    if ($Value -isnot [string] -or (-not $AllowEmpty -and [string]::IsNullOrWhiteSpace($Value))) {
        throw "invalid catalog field '$Field': expected string"
    }
}

function Assert-InstallArguments {
    param($Value, [string]$Field)
    if ($Value -isnot [array]) { throw "invalid catalog field '$Field': expected argument array" }
    foreach ($argument in $Value) { Assert-InstallString $argument $Field -AllowEmpty }
}

function Assert-InstallObject {
    param($Value, [string]$Field)
    if ($Value -isnot [pscustomobject] -and $Value -isnot [Collections.IDictionary]) {
        throw "invalid catalog field '$Field': expected object"
    }
}

function Assert-InstallRelativePath {
    param($Value, [string]$Field, [switch]$AllowEmpty)
    Assert-InstallString $Value $Field -AllowEmpty:$AllowEmpty
    if ($Value -match '(^[/\\]|:|(^|[/\\])\.\.([/\\]|$))') { throw "invalid catalog field '$Field': expected relative path" }
}

function Assert-InstallExactRelativePath {
    param($Value, [string]$Field)
    Assert-InstallRelativePath $Value $Field
    if ($Value -match '(^~|(^|[/\\])\.([/\\]|$)|[*?]|[/\\]$|[/\\]{2})') {
        throw "invalid catalog ${Field}: expected exact relative path"
    }
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
            $index = Join-Path (Resolve-Path -LiteralPath $Source).Path 'plugins/ps-ai/tools.json'
            if (-not (Test-Path -LiteralPath $index -PathType Leaf)) {
                throw 'Local tools.json is missing; run tools/update-tools-index.ps1 to regenerate it.'
            }
            $content = Get-Content -LiteralPath $index -Raw -ErrorAction Stop
        } elseif ($Source -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            $branch = Get-InstallBranch -Ref $Ref
            $content = Get-InstallSourceText -Url "https://raw.githubusercontent.com/$Source/$branch/plugins/ps-ai/tools.json"
        } else { throw "unsupported marketplace source '$Source'" }
        if (-not $content.TrimStart().StartsWith('{')) { throw 'invalid catalog root: expected object' }
        $jsonOptions = @{ ErrorAction = 'Stop' }
        if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { $jsonOptions.DateKind = 'String' }
        $Catalog = $content | ConvertFrom-Json @jsonOptions
    }
    Assert-InstallObject $Catalog 'catalog'
    if ($null -eq $Catalog -or ($Catalog.schemaVersion -isnot [int] -and $Catalog.schemaVersion -isnot [long]) -or $Catalog.schemaVersion -ne 1) {
        throw 'unsupported tools catalog schemaVersion (expected 1)'
    }
    if ($Catalog.tools -isnot [array]) { throw 'invalid catalog tools: expected array' }
    $ids = @()
    foreach ($tool in $Catalog.tools) {
        Assert-InstallObject $tool 'tool'
        Assert-InstallString $tool.id 'id'
        if ($tool.id -cnotmatch '^[a-z][a-z0-9-]*$' -or $ids -contains $tool.id) { throw 'invalid or duplicate catalog tool id' }
        $ids += $tool.id
        Assert-InstallString $tool.command 'command'
        Assert-InstallString $tool.configEnv 'configEnv'
        if ($tool.configEnv -cnotmatch '^[A-Z_][A-Z0-9_]*$') { throw 'invalid catalog configEnv' }
        Assert-InstallObject $tool.plugin 'plugin'
        foreach ($field in @('marketplaceAdd','marketplaceAddRef','marketplaceRemove','install','uninstall','marketplaceList','list','marketplaceUpdate','update')) {
            Assert-InstallArguments $tool.plugin.$field "plugin.$field"
        }

        if ($null -ne $tool.plugin.listingEnv) {
            $environment = $tool.plugin.listingEnv
            Assert-InstallObject $environment 'plugin.listingEnv'
            $names = if ($environment -is [Collections.IDictionary]) { $environment.Keys } else { $environment.PSObject.Properties.Name }
            foreach ($name in $names) {
                if ($name -cnotmatch '^[A-Z_][A-Z0-9_]*$') { throw 'invalid catalog listingEnv name' }
                Assert-InstallString $environment.$name "plugin.listingEnv.$name" -AllowEmpty
            }
        }
        foreach ($field in @('defaultConfigDir','installedRoot','cacheDir')) {
            $present = if ($tool.plugin -is [Collections.IDictionary]) { $tool.plugin.Contains($field) } else { $null -ne $tool.plugin.PSObject.Properties[$field] }
            if (-not $present) { continue }
            $value = $tool.plugin.$field
            Assert-InstallString $value "plugin.$field"
            if ($field -eq 'defaultConfigDir') {
                if (-not $value.StartsWith('~/')) { throw 'invalid catalog plugin.defaultConfigDir: expected ~/ relative path' }
                Assert-InstallRelativePath $value.Substring(2) 'plugin.defaultConfigDir'
            } else {
                Assert-InstallRelativePath $value "plugin.$field"
                if ($value -match '^~[/\\]') { throw "invalid catalog plugin.${field}: expected relative path" }
            }
            if ($field -eq 'cacheDir') { Assert-InstallExactRelativePath $value 'plugin.cacheDir' }
        }
        if ($null -ne $tool.plugin.purge) {
            $purge = $tool.plugin.purge
            Assert-InstallObject $purge 'plugin.purge'
            Assert-InstallArguments $purge.paths 'plugin.purge.paths'
            if ($null -ne $purge.emptyDirs) { Assert-InstallArguments $purge.emptyDirs 'plugin.purge.emptyDirs' }
            foreach ($path in (@($purge.paths) + @($purge.emptyDirs))) {
                if ($null -ne $path) { Assert-InstallExactRelativePath $path 'plugin.purge path' }
            }
            if ($null -ne $purge.legacyHookTrust -and $purge.legacyHookTrust -isnot [bool]) { throw 'invalid plugin.purge.legacyHookTrust' }
            if ($purge.settings -isnot [array]) { throw 'plugin.purge.settings must be an array' }
            foreach ($setting in $purge.settings) {
                Assert-InstallObject $setting 'plugin.purge.settings entry'
                Assert-InstallExactRelativePath $setting.path 'plugin.purge.settings.path'
                if ($setting.kind -cnotin @('settings', 'marketplaces', 'claude', 'copilot', 'toml')) { throw 'invalid plugin.purge.settings.kind' }
            }
        }
        $listing = $tool.plugin.listing
        Assert-InstallObject $listing 'listing'
        Assert-InstallString $listing.format 'listing.format'
        if ($listing.format -ceq 'json') {
            Assert-InstallString $listing.idField 'listing.idField'
            Assert-InstallString $listing.enabledField 'listing.enabledField'
        } elseif ($listing.format -ceq 'lines') {
            Assert-InstallString $listing.rejectPattern 'listing.rejectPattern' -AllowEmpty
            $null = [regex]::new($listing.rejectPattern)
        } else { throw 'invalid catalog listing format' }
        $marketplaceListing = $tool.plugin.marketplaceListing
        if ($null -eq $marketplaceListing) { throw 'marketplaceListing is required' }
        if ($null -ne $marketplaceListing) {
            Assert-InstallObject $marketplaceListing 'marketplaceListing'
            if ($marketplaceListing.format -cne 'json') { throw 'invalid catalog marketplace listing format' }
            Assert-InstallString $marketplaceListing.nameField 'marketplaceListing.nameField'

            foreach ($field in @('collectionField', 'rootField')) {
                if ($null -ne $marketplaceListing.$field) { Assert-InstallString $marketplaceListing.$field "marketplaceListing.$field" }
            }

        }
        Assert-InstallObject $tool.hooks 'hooks'
        Assert-InstallString $tool.hooks.status 'hooks.status' -AllowEmpty
        Assert-InstallString $tool.hooks.hint 'hooks.hint' -AllowEmpty
        Assert-InstallString $tool.installHint 'installHint' -AllowEmpty
    }
    Assert-InstallObject $Catalog.bootstrap 'bootstrap'
    $windows = $Catalog.bootstrap.windows
    Assert-InstallObject $windows 'bootstrap.windows'
    Assert-InstallString $windows.wingetId 'bootstrap.windows.wingetId'
    Assert-InstallRelativePath $windows.portableCommand 'bootstrap.windows.portableCommand'
    Assert-InstallObject $windows.download 'bootstrap.windows.download'
    $zip = $windows.download.zip
    Assert-InstallObject $zip 'bootstrap.zip'
    foreach ($field in @('kind','resolver','verification')) { Assert-InstallString $zip.$field "bootstrap.zip.$field" }
    if ($zip.kind -cne 'zip' -or $zip.resolver -cne 'release-assets' -or $zip.verification -cne 'asset-digest') {
        throw 'invalid catalog bootstrap ZIP recipe'
    }
    Assert-InstallString $zip.metadataUrl 'bootstrap.zip.metadataUrl'
    Assert-InstallString $zip.assetPattern 'bootstrap.zip.assetPattern'
    $null = [regex]::new($zip.assetPattern)
    Assert-InstallRelativePath $zip.pathFolder 'bootstrap.zip.pathFolder' -AllowEmpty
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
    } elseif ($info.PSObject.Properties['ArgumentList']) {
        foreach ($argument in $arguments) { $info.ArgumentList.Add($argument) }
    } else {
        $info.Arguments = ($arguments | ForEach-Object { ConvertTo-InstallArgument $_ }) -join ' '
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
        foreach ($name in $names) { $info.EnvironmentVariables[$name] = [string]$Environment.$name }
    }
    # The stdin pipe must carry nothing, but a UTF-8 console code page makes the pipe send a byte-order mark,
    # which the CLI reads as one character instead of EOF. PowerShell 5.1 has no StandardInputEncoding, so it
    # starts the process with a mark-free console input encoding.
    $noMark = New-Object System.Text.UTF8Encoding -ArgumentList $false
    $savedInputEncoding = $null
    $inputEncodingChanged = $false
    if ($info.PSObject.Properties['StandardInputEncoding']) {
        $info.StandardInputEncoding = $noMark
    } else {
        $savedInputEncoding = [Console]::InputEncoding
        try {
            [Console]::InputEncoding = $noMark
            $inputEncodingChanged = $true
        } catch {
            # Without a console, keep the runtime's default input encoding.
        }
    }
    try { $process = [System.Diagnostics.Process]::Start($info) }
    finally { if ($inputEncodingChanged) { [Console]::InputEncoding = $savedInputEncoding } }
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

function Set-InstallConfigEnvironment {
    param([string]$Name, $Value)
    # Passing null to SetEnvironmentVariable can create an empty variable on newer runtimes.
    if ($null -eq $Value) { Remove-Item -LiteralPath "Env:$Name" -ErrorAction SilentlyContinue }
    else { [Environment]::SetEnvironmentVariable($Name, [string]$Value, 'Process') }
}

function Test-InstallStepDone {
    param([string[]]$Command, [ValidateSet('marketplace','plugin')][string]$Kind = 'plugin', [string]$ConfigEnv, [string]$ConfigDir, [switch]$IncludeDisabled, [switch]$RequireRoot)
    $entry = $script:installCatalog.tools | Where-Object command -CEQ $Command[0] | Select-Object -First 1
    if (-not $entry) { throw "unknown tool command '$($Command[0])'" }
    $arguments = if ($kind -eq 'marketplace') { $entry.plugin.marketplaceList } else { $entry.plugin.list }
    $list = @($entry.command) + $arguments
    $previous = if ($ConfigEnv) { [Environment]::GetEnvironmentVariable($ConfigEnv, 'Process') } else { $null }
    try {
        if ($ConfigEnv) {
            if ($ConfigDir) { Set-InstallConfigEnvironment -Name $ConfigEnv -Value $ConfigDir }
            else { Set-InstallConfigEnvironment -Name $ConfigEnv -Value $null }
        }
        $result = Invoke-ClosedInput -Command $list -Environment $entry.plugin.listingEnv
        if ($result.ExitCode -ne 0) {
            $details = @((($result.ErrorOutput -join "`n").Trim()), (($result.Output -join "`n").Trim())) | Where-Object { $_ }
            # Codex refuses to list an explicit home until its directory exists, even before login.
            if ($entry.id -eq 'codex' -and $result.ExitCode -eq 1 -and $ConfigDir -and -not (Test-Path -LiteralPath $ConfigDir) -and
                ($details -join "`n") -match 'failed to resolve CODEX_HOME' -and ($details -join "`n") -match 'but that path does not exist') {
                return $false
            }
            throw (@("$($entry.command) listing exited $($result.ExitCode)") + $details -join "`n")
        }
        return Test-InstallListing -Kind $kind -Tool $entry.id -Lines $result.Output -IncludeDisabled:$IncludeDisabled -RequireRoot:$RequireRoot
    } finally {
        if ($ConfigEnv) { Set-InstallConfigEnvironment -Name $ConfigEnv -Value $previous }
    }
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
            if ((Get-InstallListingField -Item $item -Field $listing.nameField) -cne 'ps-ai-marketplace') { continue }
            if ($RequireRoot -and $listing.rootField) {
                $root = Get-InstallListingField -Item $item -Field $listing.rootField
                if (-not ($root -is [string]) -or -not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) { return $false }
            }
            return $true
        }
        return $false
    }
    $listing = $entry.plugin.listing
    if ($listing -and $listing.format -eq 'json') {
        try {
            $plugins = @((($Lines -join "`n") | ConvertFrom-Json -ErrorAction Stop))
            return [bool](@($plugins | Where-Object {
                $_.($listing.idField) -is [string] -and $_.($listing.idField) -ceq 'ps-ai@ps-ai-marketplace' -and
                $_.($listing.enabledField) -is [bool] -and ($IncludeDisabled -or $_.($listing.enabledField))
            }).Count)
        } catch { throw "$Tool plugin listing returned invalid JSON" }
    }
    $reject = if ($IncludeDisabled) { 'not installed' } elseif ($listing) { $listing.rejectPattern } else { 'not installed|disabled' }
    $pattern = if ($Tool) { '(^|[\s`])ps-ai@ps-ai-marketplace(\s|`|"|$)' } else { 'ps-ai@ps-ai-marketplace' }
    $matching = @($Lines) | Where-Object { $_ -match $pattern }
    return [bool](@($matching) | Where-Object { -not $reject -or $_ -notmatch $reject })
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
    $previous = [Environment]::GetEnvironmentVariable($ConfigEnv, 'Process')
    try {
        if ($ConfigEnv -eq 'CODEX_HOME' -and $ConfigDir -and -not (Test-Path -LiteralPath $ConfigDir)) {
            New-Item -ItemType Directory -Path $ConfigDir -Force -ErrorAction Stop | Out-Null
        }
        if ($ConfigDir) { Set-InstallConfigEnvironment -Name $ConfigEnv -Value $ConfigDir }
        else { Set-InstallConfigEnvironment -Name $ConfigEnv -Value $null }
        $result = Invoke-ClosedInput -Command $Command
        $result.Output
        $result.ErrorOutput
        if ($result.ExitCode -ne 0) { throw "$($Command[0]) exited $($result.ExitCode)" }
    } finally {
        Set-InstallConfigEnvironment -Name $ConfigEnv -Value $previous
    }
}

function Invoke-LegionInstallSteps {
    param([string]$Tool, [string]$Source, [string]$ConfigEnv, [string]$ConfigDir, [switch]$DryRun, [ValidateSet('release','main')][string]$Ref = 'release')
    $commands = Get-InstallCommands -Tool $Tool -Source $Source -Ref $Ref
    $entry = Get-InstallTool -Tool $Tool
    $marketplaceAdded = $false
    for ($index = 0; $index -lt $commands.Count; $index++) {
        $command = $commands[$index]
        $kind = if ($index -eq 0) { 'marketplace' } else { 'plugin' }
        if (-not $marketplaceAdded -and (Test-InstallStepDone -Command $command -Kind $kind -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir)) {
            if ($index -eq 0) {
                $rootReady = $true
                if ($entry.plugin.marketplaceListing.rootField) {
                    $rootReady = Test-InstallStepDone -Command $command -Kind marketplace -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir -RequireRoot
                }
                $pluginReady = Test-InstallStepDone -Command $commands[1] -Kind plugin -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir
                if (-not $rootReady -or -not $pluginReady) {
                    if (-not $entry.plugin.marketplaceUpdate.Count) { throw "$Tool has no marketplace refresh command" }
                    $refresh = @($entry.command) + $entry.plugin.marketplaceUpdate
                    if ($DryRun) { Format-InstallCommand -Command $refresh -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
                    else { Invoke-InstallCommand -Command $refresh -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
                    $marketplaceAdded = $true
                    continue
                }
                "skip: $($command -join ' ') (already done)"
                "skip: $($commands[1] -join ' ') (already done)"
                return
            }
            "skip: $($command -join ' ') (already done)"
            continue
        }
        if ($DryRun) { Format-InstallCommand -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
        else { Invoke-InstallCommand -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
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

function Resolve-InstallConfigDir {
    param([string]$Path)
    $Path = $Path.Replace('\', '/')
    if ($Path -eq '~') { $Path = Get-InstallHome }
    elseif ($Path.StartsWith('~/')) { $Path = Join-Path (Get-InstallHome) $Path.Substring(2) }
    $Path = [IO.Path]::GetFullPath($Path)
    if ($Path.Length -gt [IO.Path]::GetPathRoot($Path).Length) { $Path = $Path.TrimEnd('\', '/') }
    return $Path
}

function Test-InstallRealProfile {
    $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $selected = [IO.Path]::GetFullPath((Get-InstallHome)).TrimEnd('\', '/')
    $profileHome = [IO.Path]::GetFullPath([Environment]::GetFolderPath('UserProfile')).TrimEnd('\', '/')
    return [string]::Equals($selected, $profileHome, $comparison)
}

function Get-UpdateConfigDirs {
    param([string]$Tool, [string]$ConfigDir)
    if ($ConfigDir) { return ,@($ConfigDir) }
    $entry = Get-InstallTool -Tool $Tool
    $override = [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')
    $defaultFolder = if ($override) { $override } else { $entry.plugin.defaultConfigDir }
    if ($defaultFolder) { $defaultFolder = Resolve-InstallConfigDir $defaultFolder }
    $folders = @()
    $homeRoot = Get-InstallHome
    $file = Get-InstallLegionPath 'configuration/ps-ai-personalisation.json'
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $data = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($agent in $data.agents) {
            if ($agent.tool -cne $Tool -or [string]::IsNullOrWhiteSpace($agent.configDir)) { continue }
            $folder = Resolve-InstallConfigDir $agent.configDir
            $alreadyListed = if ($env:OS -eq 'Windows_NT') { $folders -contains $folder } else { $folders -ccontains $folder }
            if (-not $alreadyListed) { $folders += $folder }
        }
    }
    $defaultListed = if ($env:OS -eq 'Windows_NT') { $folders -contains $defaultFolder } else { $folders -ccontains $defaultFolder }
    if (-not $defaultListed) {
        # Keep the CLI's implicit default only when no recorded account selects it.
        # A home other than the real profile has its own default folder; never hand the CLI its real default.
        $target = if ($override -or -not (Test-InstallRealProfile)) { $defaultFolder } else { '' }
        $folders = @($target) + $folders
    }
    return ,$folders
}

# The owner commands ps-ai creates, and the bin script each one calls.
function Get-InstallOwnerCommands {
    return [ordered]@{ 'ps-ai-setup' = 'ps-ai-setup.ps1'; 'ps-ai-status' = 'ps-ai-status.ps1'; 'ps-ai-overseer' = 'ps-ai-overseer.ps1'; 'legion' = 'legion.ps1' }
}

# Same rule as lib/commands.ps1 (this file is standalone): the whole file is the generated launcher,
# one line whose -File argument is the script, and a .cmd file writes % as %%.
# Returns the script path and its span, or nothing when the file is not a ps-ai command.
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
            $header = if ($suffix) { "@rem Generated by ps-ai: account $($agent.id)" } else { "# Generated by ps-ai: account $($agent.id)" }
            if ([IO.File]::ReadAllLines($path) -cnotcontains $header) { continue }
            # Launchers survive uninstall; an unselected account still needs the shared runtime.
            if (-not $selected) { $unselectedLauncher = $true }
        }
    }
    if (-not $unselectedLauncher) {
        if (-not $KeepOwnerCommands) { $paths += Get-InstallOwnerCommandPaths -Bin $bin }
        # Exact files published by Sync-LegionFoundryRuntime; never remove the directory tree.
        $runtime = Join-Path $bin '.ps-ai-runtime'
        foreach ($name in @('bin/lib/tools.ps1', 'bin/lib/foundry.ps1', 'bin/lib/paths.ps1', 'bin/ps-ai-foundry.ps1', 'schemas/tool.schema.json')) {
            $paths += Join-Path $runtime $name
        }
        foreach ($entry in $script:installCatalog.tools) {
            foreach ($name in @('SKILL.md', 'tool.json', 'scripts/foundry-config.ps1', 'scripts/foundry-launch.ps1')) {
                $paths += Join-Path $runtime "skills/ps-ai-$($entry.id)/$name"
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
    $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $currentPath.StartsWith($Bin + [IO.Path]::DirectorySeparatorChar, $comparison)) { throw 'Unsafe generated file path' }
    $homeRoot = [IO.Path]::GetFullPath((Get-InstallHome)).TrimEnd('\', '/')
    if (-not $currentPath.StartsWith($homeRoot + [IO.Path]::DirectorySeparatorChar, $comparison)) { throw 'Unsafe generated file path' }
    while ($currentPath.Length -ge $homeRoot.Length) {
        $current = Get-Item -LiteralPath $currentPath -Force -ErrorAction SilentlyContinue
        if (-not $current) { return $false }
        if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "skip: $Path (linked folder)"
            return $false
        }
        if ([string]::Equals($currentPath, $homeRoot, $comparison)) { break }
        $currentPath = Split-Path $currentPath -Parent
    }
    return $true
}

function Get-UninstallCachePath {
    param($Entry, [string]$ConfigDir, [switch]$AllowFile)
    if (-not $Entry.plugin.cacheDir) { return }
    if (-not $ConfigDir) {
        if (-not $Entry.plugin.defaultConfigDir) { throw 'Missing plugin.defaultConfigDir for cache cleanup' }
        $ConfigDir = Join-Path (Get-InstallHome) $Entry.plugin.defaultConfigDir.Substring(2)
    }
    $root = [IO.Path]::GetFullPath($ConfigDir).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $path = [IO.Path]::GetFullPath((Join-Path $root $Entry.plugin.cacheDir))
    $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, $comparison)) { throw 'Unsafe plugin cache path' }
    if (-not (Test-Path -LiteralPath $path)) { return }
    if (-not $AllowFile -and -not (Test-Path -LiteralPath $path -PathType Container)) { return }
    # Refuse linked ancestors and linked contents, including junctions on Windows PowerShell.
    $current = $path
    while ($current) {
        if ((Get-Item -LiteralPath $current -Force -ErrorAction Stop).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Host "skip: plugin cache $path (linked folder)"
            return
        }
        $current = Split-Path $current -Parent
    }
    $pending = New-Object 'Collections.Generic.Stack[string]'
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
        $children = @()
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
            $children += $member
            if ($Cursor.Value -lt $tokens.Count -and $tokens[$Cursor.Value].Value -eq ',') {
                $member.AfterComma = $tokens[$Cursor.Value].Index
                $previousComma = $member.AfterComma
                $Cursor.Value++
            } elseif ($Cursor.Value -ge $tokens.Count -or $tokens[$Cursor.Value].Value -ne $close) { throw 'Missing JSON comma' }
        }
        if ($Cursor.Value -ge $tokens.Count) { throw 'Unclosed JSON container' }
        $node.End = $tokens[$Cursor.Value].Index + 1
        $node.Children = $children
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
            $candidates = @($root.Children | Where-Object Key -CEQ 'ps-ai-marketplace')
        } else {
            foreach ($parent in $root.Children) {
                $key = if ($parent.Key -ceq 'extraKnownMarketplaces') { 'ps-ai-marketplace' } else { 'ps-ai@ps-ai-marketplace' }
                if ($parent.Key -cin @('enabledPlugins', 'extraKnownMarketplaces') -or ($Kind -eq 'claude' -and $parent.Key -ceq 'plugins')) {
                    $candidates += @($parent.Node.Children | Where-Object Key -CEQ $key)
                }
                if ($Kind -eq 'copilot' -and $parent.Key -ceq 'installedPlugins') {
                    foreach ($item in $parent.Node.Children) {
                        $name = @($item.Node.Children | Where-Object Key -CEQ 'name')
                        $marketplace = @($item.Node.Children | Where-Object Key -CEQ 'marketplace')
                        if ($name.Count -eq 1 -and $name[0].Node.Value -ceq 'ps-ai' -and $marketplace.Count -eq 1 -and $marketplace[0].Node.Value -ceq 'ps-ai-marketplace') { $candidates += $item }
                    }
                }
            }
        }
        if (-not $candidates.Count) { break }
        $member = $candidates[0]
        $entries += if ($member.Key -eq '*') { 'installedPlugins: ps-ai@ps-ai-marketplace' } else { $member.Key }
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
    $key = '(?:ps-ai-marketplace|"ps-ai-marketplace"|''ps-ai-marketplace'')'
    $plugin = '(?:"ps-ai@ps-ai-marketplace"|''ps-ai@ps-ai-marketplace'')'
    $hook = '(?:"ps-ai@ps-ai-marketplace:[^"\r\n]*"|''ps-ai@ps-ai-marketplace:[^''\r\n]*'')'
    $owned = '^\s*\[\s*(?:(?:plugins|"plugins"|''plugins'')\s*\.\s*' + $plugin + '|(?:marketplaces|"marketplaces"|''marketplaces'')\s*\.\s*' + $key + '|(?:hooks|"hooks"|''hooks'')\s*\.\s*(?:state|"state"|''state'')\s*\.\s*' + $hook + ')(?:\s*\.\s*[\w"''.-]+)*\s*\]\s*(?:#.*)?$'
    foreach ($match in [regex]::Matches($Text, '[^\r\n]*(?:\r\n|\n|\r|$)')) {
        $line = $match.Value
        if (-not $line.Length) { continue }
        $outsideValue = -not $delimiter -and $arrayDepth -eq 0
        if ($outsideValue -and $line -match '^\s*\[') {
            $skip = $line.TrimEnd("`r", "`n") -cmatch $owned
            if ($skip) { $entries += $line.Trim() }
        }
        if ($outsideValue -and -not $skip -and $line -cmatch '^\s*(?:["'']?(?:plugins|marketplaces|hooks)["'']?[\s.=]|["'']?ps-ai(?:@ps-ai-marketplace|-marketplace))' -and $line -cmatch 'ps-ai(?:@ps-ai-marketplace|-marketplace)') {
            throw 'Inline or dotted ps-ai TOML entry needs manual removal'
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

function Get-InstallPurgeTrustPath {
    param([string]$ConfigDir)
    # Codex legacy_trust_path: SHA256 of length-prefixed config path and plugin ID.
    $stream = New-Object IO.MemoryStream
    $hash = [Security.Cryptography.SHA256]::Create()
    try {
        foreach ($part in @([IO.Path]::GetFullPath((Join-Path $ConfigDir 'config.toml')), 'ps-ai@ps-ai-marketplace')) {
            $bytes = [Text.Encoding]::UTF8.GetBytes($part)
            $length = [BitConverter]::GetBytes([uint64]$bytes.Length)
            if (-not [BitConverter]::IsLittleEndian) { [Array]::Reverse($length) }
            $stream.Write($length, 0, $length.Length)
            $stream.Write($bytes, 0, $bytes.Length)
        }
        $name = ([BitConverter]::ToString($hash.ComputeHash($stream.ToArray()))).Replace('-', '').ToLowerInvariant()
        return ".hook-trust/$name"
    } finally { $stream.Dispose(); $hash.Dispose() }
}

function Get-InstallPurgePlan {
    param([string]$ConfigDir)
    # Purge is global even if the preceding uninstall selected only some targets.
    $paths = @()
    $edits = @()
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
            if ($purge.legacyHookTrust) { $relativePaths += Get-InstallPurgeTrustPath -ConfigDir $folder }
            foreach ($relative in $relativePaths) {
                if (-not $relative) { continue }
                $descriptor = @{ plugin=@{ cacheDir=$relative } }
                $path = Get-UninstallCachePath -Entry $descriptor -ConfigDir $folder -AllowFile 6>$null
                if ($path) { $paths += [pscustomobject]@{ Path=$path; Root=$folder; Relative=$relative; EmptyOnly=$false } }
                elseif (Test-Path -LiteralPath (Join-Path $folder $relative)) { $manualSteps += "Manual step: $(Join-Path $folder $relative) (linked path; left in place)" }
            }
            foreach ($relative in $purge.emptyDirs) {
                $descriptor = @{ plugin=@{ cacheDir=$relative } }
                $path = Get-UninstallCachePath -Entry $descriptor -ConfigDir $folder 6>$null
                # List the parent only if its remaining children are already planned for removal.
                if ($path -and -not @(Get-ChildItem -LiteralPath $path -Force | Where-Object { $_.FullName -notin $paths.Path }).Count) {
                    $paths += [pscustomobject]@{ Path=$path; Root=$folder; Relative=$relative; EmptyOnly=$true }
                }
            }
            foreach ($setting in $purge.settings) {
                $relative = $setting.path
                $descriptor = @{ plugin=@{ cacheDir=$relative } }
                $path = Get-UninstallCachePath -Entry $descriptor -ConfigDir $folder -AllowFile 6>$null
                if (-not $path -and (Test-Path -LiteralPath (Join-Path $folder $relative))) { $manualSteps += "Manual step: $(Join-Path $folder $relative) (linked path; left in place)" }
                if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
                    $alreadyEdited = if ($env:OS -eq 'Windows_NT') { $edits.Path -contains $path } else { $edits.Path -ccontains $path }
                    if ($alreadyEdited) { continue }
                    $edit = Get-InstallPurgeEdit -Path $path -Kind $setting.kind
                    if ($edit.Manual) { $manualSteps += "Manual step: $path (remove its ps-ai entries; could not match them safely)" }
                    elseif ($edit) { $edits += $edit }
                }
            }
        }
    }
    $legionDescriptor = @{ plugin=@{ cacheDir='.legion' } }
    $legion = Get-UninstallCachePath -Entry $legionDescriptor -ConfigDir (Get-InstallHome) 6>$null
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
    $shown = @()
    foreach ($item in $items) {
        $key = if ($env:OS -eq 'Windows_NT') { $item.Path.ToLowerInvariant() } else { $item.Path }
        if ($shown -ccontains $key) { continue }
        $shown += $key
        if (Test-Path -LiteralPath $item.Path -PathType Container) {
            $count = @(Get-ChildItem -LiteralPath $item.Path -File -Recurse -Force).Count
            $note = if ($item.EmptyOnly) { ' (if empty)' } elseif ($item.Path -ceq $Plan.Legion) { ' (last: all settings, notes, account folders, logins and launchers)' } else { '' }
            "Remove folder: $($item.Path) ($count files)$note"
        } else { "Remove file: $($item.Path)" }
    }
    foreach ($step in $Plan.ManualSteps) { $step }
    'Codex hook approvals for folders ps-ai no longer knows cannot be identified and are left in place.'
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
        $descriptor = @{ plugin=@{ cacheDir=([IO.Path]::GetFileName($edit.Path)) } }
        $safe = Get-UninstallCachePath -Entry $descriptor -ConfigDir (Split-Path $edit.Path) -AllowFile
        if (-not $safe -or [Convert]::ToBase64String([IO.File]::ReadAllBytes($edit.Path)) -cne [Convert]::ToBase64String($edit.Before)) { throw 'Settings changed after preview; run purge again.' }
        [IO.File]::WriteAllBytes($edit.Path, $edit.After)
    }
    foreach ($item in $Plan.Paths) {
        $descriptor = @{ plugin=@{ cacheDir=$item.Relative } }
        $safe = Get-UninstallCachePath -Entry $descriptor -ConfigDir $item.Root -AllowFile
        if (-not $safe -or $safe -cne $item.Path) { continue }
        if ($item.EmptyOnly -and @(Get-ChildItem -LiteralPath $safe -Force).Count) { continue }
        Remove-Item -LiteralPath $safe -Recurse -Force -ErrorAction Stop
    }
    # The running installer may be a private copy under this tree; functions are
    # already loaded. Legion's caller tolerates its copy having been removed.
    if ($Plan.Legion) {
        $descriptor = @{ plugin=@{ cacheDir='.legion' } }
        $safe = Get-UninstallCachePath -Entry $descriptor -ConfigDir $Plan.HomeRoot
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
    if (-not ($Yes -or (Read-Host 'Purge ps-ai settings, notes, account folders and logins listed above? [y/N]') -match '^(?i:y|yes)$')) { 'Purge cancelled.'; return }
    Invoke-InstallPurgePlan -Plan $plan
    if ($plan.ManualSteps.Count) { 'Purge needs the manual steps above.' } else { 'done: purge' }
}

function Invoke-LegionUninstall {
    param([string[]]$Tools, [string]$ConfigDir, [switch]$DryRun, [switch]$Yes)
    $homeRoot = Get-InstallHome
    $script:installUninstallDeclined = $false
    $file = Get-InstallLegionPath 'configuration/ps-ai-personalisation.json'
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
    if (-not $files.Count) { 'skip: ps-ai generated files (not installed)' }
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
    if ($hasWork -and -not $DryRun -and ($Yes -or (Read-Host 'Uninstall ps-ai from these targets? [y/N]') -match '^(?i:y|yes)$')) {
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
        $bin = [IO.Path]::GetFullPath((Get-InstallLegionPath 'bin'))
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
    $bin = Get-InstallLegionPath 'bin'
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
    param($Entry, [string]$ConfigDir, [switch]$DryRun, [switch]$Yes, [string]$Source = 'BlackGad/ps-ai-marketplace', [ValidateSet('release','main')][string]$Ref = 'release', [string]$PluginRoot)
    $configEnv = $Entry.configEnv
    $previous = [Environment]::GetEnvironmentVariable($configEnv, 'Process')
    try {
        if ($ConfigDir) { Set-InstallConfigEnvironment -Name $configEnv -Value $ConfigDir }
        else { Set-InstallConfigEnvironment -Name $configEnv -Value $null }
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
            if (-not $root) { throw "$($Entry.id) ps-ai is absent from the post-update listing; generated artifacts were not refreshed." }
            $after = (Get-Content -LiteralPath (Join-Path $root 'plugin.json') -Raw | ConvertFrom-Json).version
            Invoke-InstallRefresh -Entry $Entry -ConfigDir $ConfigDir -PluginRoot $root
            if ($before -ceq $after) { "skip: ps-ai $after (already up to date)" }
            else { "ps-ai $before -> $after" }
        }
    } finally {
        Set-InstallConfigEnvironment -Name $configEnv -Value $previous
    }
}

function Invoke-InstallRefresh {
    param($Entry, [string]$ConfigDir, [string]$PluginRoot)
    if (-not $PluginRoot) { $PluginRoot = Get-InstallPluginRoot -Entry $Entry -ConfigDir $ConfigDir }
    if (-not $PluginRoot) { throw "$($Entry.id) ps-ai is absent from the post-update listing; generated artifacts were not refreshed." }
    $refresh = Join-Path $PluginRoot 'bin/ps-ai-refresh.ps1'
    if (-not (Test-Path -LiteralPath $refresh -PathType Leaf)) { throw "$($Entry.id) installed ps-ai refresh script is missing." }
    $powerShell = Get-InstallPowerShellCommand
    if (-not $powerShell) { throw 'PowerShell 7 is required to refresh generated ps-ai artifacts.' }
    $result = Invoke-ClosedInput -Command @($powerShell.Source, '-NoProfile', '-File', $refresh, '-HomeRoot', (Get-InstallHome))
    $result.Output
    $result.ErrorOutput
    if ($result.ExitCode -ne 0) { throw "ps-ai artifact refresh exited $($result.ExitCode)" }
}

function Get-InstallVersion {
    param([string]$Text)
    if ($Text -match '\b(v?\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\b') { return $Matches[1] -replace '^v', '' }
    return ''
}

function Get-InstallPluginRoot {
    param($Entry, [string]$ConfigDir)
    $previous = [Environment]::GetEnvironmentVariable($Entry.configEnv, 'Process')
    try {
        if ($ConfigDir) { Set-InstallConfigEnvironment -Name $Entry.configEnv -Value $ConfigDir }
        else { Set-InstallConfigEnvironment -Name $Entry.configEnv -Value $null }
        $result = Invoke-ClosedInput -Command (@($Entry.command) + $Entry.plugin.list) -Environment $Entry.plugin.listingEnv
        if ($result.ExitCode -ne 0) {
            $details = @($result.ErrorOutput) + @($result.Output) -join "`n"
            # Codex cannot list a selected home until that folder exists.
            if ($Entry.id -eq 'codex' -and $result.ExitCode -eq 1 -and $ConfigDir -and -not (Test-Path -LiteralPath $ConfigDir) -and
                $details -match 'failed to resolve CODEX_HOME' -and $details -match 'but that path does not exist') { return $null }
            throw "$($Entry.command) plugin listing exited $($result.ExitCode)`n$details"
        }
        if (-not (Test-InstallListing -Kind plugin -Tool $Entry.id -Lines $result.Output -IncludeDisabled)) {
            return $null
        }
        $paths = @()
        $installedVersion = ''
        if ($Entry.plugin.listing.format -eq 'json') {
            $listing = $Entry.plugin.listing
            $plugins = @((($result.Output -join "`n") | ConvertFrom-Json -ErrorAction Stop))
            foreach ($plugin in $plugins) {
                if ($plugin.($listing.idField) -cne 'ps-ai@ps-ai-marketplace') { continue }
                if ($plugin.installPath) { $paths += [string]$plugin.installPath }
                if ($plugin.version) { $installedVersion = [string]$plugin.version }
            }
        } else {
            $isLegion = $false
            foreach ($line in $result.Output) {
                if ($Entry.id -ceq 'copilot' -and $isLegion -and $line -match '^\s+from (.+?)\s*$') {
                    # Copilot lists a live directory marketplace instead of an installed copy.
                    $marketplaceRoot = $Matches[1]
                    try {
                        $marketplace = Get-Content -LiteralPath (Join-Path $marketplaceRoot '.claude-plugin/marketplace.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
                        foreach ($plugin in $marketplace.plugins) {
                            if ($plugin.name -ceq 'ps-ai' -and $plugin.source -is [string]) { $paths += Join-Path $marketplaceRoot $plugin.source }
                        }
                    } catch { }
                }
                $isLegion = $line -match '(^|[\s`])ps-ai@ps-ai-marketplace(\s|`|"|$)' -and $line -notmatch 'not installed'
                if (-not $isLegion) { continue }
                $version = Get-InstallVersion $line
                if ($version) { $installedVersion = $version }
                if ($line -match '\s((?:[A-Za-z]:[/\\]|/).+?)\s*$') { $paths += $Matches[1] }
            }
        }
        if (-not $paths.Count) {
            $homeRoot = Get-InstallHome
            if (-not $Entry.plugin.installedRoot) { throw "$($Entry.id) plugin descriptor needs installedRoot to locate its installed refresh script." }
            if (-not $ConfigDir -and -not $Entry.plugin.defaultConfigDir) { throw "$($Entry.id) plugin descriptor needs defaultConfigDir to locate its installed refresh script." }
            $configRoot = if ($ConfigDir) { $ConfigDir } else { $Entry.plugin.defaultConfigDir }
            if ($configRoot -match '^~[/\\]') { $configRoot = Join-Path $homeRoot $configRoot.Substring(2) }
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
                if ($manifest.name -cne 'ps-ai' -or ($installedVersion -and $manifest.version -cne $installedVersion)) { continue }
                $roots += $path
            } catch { continue }
        }
        if ($roots.Count -ne 1) {
            throw "$($Entry.id) installed ps-ai folder could not be identified uniquely."
        }
        return $roots[0]
    } finally {
        Set-InstallConfigEnvironment -Name $Entry.configEnv -Value $previous
    }
}

function Test-InstallCommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Get-InstallPowerShellCommand {
    $command = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command }
    $portable = Get-InstallPortablePowerShell
    if ($portable) { return @{ Source=$portable } }
    if ($env:OS -eq 'Windows_NT' -and $env:ProgramFiles) {
        $candidate = Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe'
        if (Test-Path -LiteralPath $candidate) { return @{ Source=$candidate } }
    }
}

function Get-InstallPortablePowerShell {
    $root = Get-InstallLegionPath 'tools/pwsh'
    $pattern = Join-Path ([WildcardPattern]::Escape($root)) $script:installCatalog.bootstrap.windows.portableCommand
    $file = Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
    if ($file) { return $file.FullName }
}

function Get-InstallUserPath {
    # Read the raw registry value so entries such as %USERPROFILE%\bin stay unexpanded.
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    if (-not $key) { return '' }
    try { return [string]$key.GetValue('Path', '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames) }
    finally { $key.Dispose() }
}

function Set-InstallUserPath {
    param([string]$Path)
    # Keep the existing value kind (normally REG_EXPAND_SZ), then tell Windows the environment changed.
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        $kind = [Microsoft.Win32.RegistryValueKind]::ExpandString
        if ($key.GetValueNames() -icontains 'Path') { $kind = $key.GetValueKind('Path') }
        $key.SetValue('Path', $Path, $kind)
    } finally { $key.Dispose() }
    if (-not ('LegionInstall.Environment' -as [type])) {
        Add-Type -Namespace LegionInstall -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr parameter, string value, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    [void][LegionInstall.Environment]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
}

function Test-InstallPathEntry {
    param([string]$Path, [string]$Entry, [string]$Separator)
    $target = $Entry.TrimEnd('\', '/')
    foreach ($part in ($Path -split [regex]::Escape($Separator))) {
        if ([Environment]::ExpandEnvironmentVariables($part).TrimEnd('\', '/') -ieq $target) { return $true }
    }
    return $false
}

function Add-InstallPowerShellPath {
    param([string]$Path)
    $userPath = Get-InstallUserPath
    if (-not (Test-InstallPathEntry -Path $userPath -Entry $Path -Separator ';')) {
        $updated = if ($userPath) { $userPath.TrimEnd(';') + ';' + $Path } else { $Path }
        Set-InstallUserPath -Path $updated
    }
    if (-not (Test-InstallPathEntry -Path $env:PATH -Entry $Path -Separator ([string][IO.Path]::PathSeparator))) {
        $env:PATH = $Path + [IO.Path]::PathSeparator + $env:PATH
    }
}

function Invoke-InstallDownload {
    param([string]$Url, [string]$OutFile)
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
}

function Invoke-InstallWinget {
    $result = Invoke-ClosedInput -Command @('winget', 'install', '--id', $script:installCatalog.bootstrap.windows.wingetId, '-e')
    foreach ($line in @($result.Output) + @($result.ErrorOutput)) { Write-Host $line }
    return $result.ExitCode
}

function Install-PowerShellZip {
    $temporary = Get-InstallLegionPath ('temp/ps-ai-install-' + [guid]::NewGuid().ToString('N'))
    $metadata = Join-Path $temporary 'release.json'
    $archive = Join-Path $temporary 'pwsh.zip'
    try {
        New-Item -ItemType Directory -Path $temporary -Force -ErrorAction Stop | Out-Null
        $recipe = $script:installCatalog.bootstrap.windows.download.zip
        Invoke-InstallDownload -Url $recipe.metadataUrl -OutFile $metadata
        $release = Get-Content -LiteralPath $metadata -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $asset = $release.assets | Where-Object { $_.name -match $recipe.assetPattern } | Select-Object -First 1
        if (-not $asset -or $asset.digest -notmatch '^sha256:([a-fA-F0-9]{64})$') {
            throw 'PowerShell ZIP asset or SHA-256 digest is missing from the official release.'
        }
        $expectedHash = $Matches[1]
        Invoke-InstallDownload -Url $asset.browser_download_url -OutFile $archive
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256 -ErrorAction Stop).Hash -ine $expectedHash) {
            throw 'PowerShell ZIP SHA-256 digest mismatch; download deleted.'
        }
        $destination = Get-InstallLegionPath 'tools/pwsh'
        Expand-Archive -LiteralPath $archive -DestinationPath $destination -Force -ErrorAction Stop
        if (-not (Get-InstallPortablePowerShell)) { throw 'PowerShell ZIP does not contain the configured executable.' }
        $folder = $recipe.pathFolder.Replace('{version}', [string]$release.tag_name)
        Assert-InstallRelativePath $folder 'bootstrap ZIP pathFolder' -AllowEmpty
        Add-InstallPowerShellPath -Path (Join-Path $destination $folder)
    } finally {
        foreach ($file in @($archive, $metadata)) {
            if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file -Force -ErrorAction Stop }
        }
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -ErrorAction Stop }
    }
}

function Ensure-InstallPowerShell {
    param([bool]$OnWindows = ($env:OS -eq 'Windows_NT'), [switch]$DryRun, [switch]$Yes)
    $command = Get-InstallPowerShellCommand
    if ($command) {
        Write-Host 'skip: PowerShell 7 (already done)'
        # A previous portable install may be present before this shell has refreshed PATH.
        $portable = Get-InstallPortablePowerShell
        if ($OnWindows -and -not $DryRun -and $portable -and $command.Source -eq $portable -and
            (Confirm-InstallChange -Yes:$Yes -Question 'Add the portable PowerShell 7 folder to your user PATH? [y/N]')) {
            Add-InstallPowerShellPath -Path (Split-Path $portable -Parent)
        }
        return $true
    }
    if (-not $OnWindows) {
        Write-Host 'PowerShell 7 is missing.'
        Write-Host 'Install PowerShell 7: https://learn.microsoft.com/powershell/scripting/install/installing-powershell'
        return $false
    }
    if (-not $Yes -or $DryRun) {
        Write-Host 'PowerShell 7 is missing.'
        Write-Host ('winget install --id ' + $script:installCatalog.bootstrap.windows.wingetId + ' -e')
        Write-Host 'ZIP fallback: latest official PowerShell ZIP, verified with its SHA-256 digest, to ~/.legion/tools/pwsh/ (user and process PATH).'
    }
    if ($DryRun) { return $false }
    if (-not (Confirm-InstallChange -Yes:$Yes -Question 'Install PowerShell 7 now? [y/N]')) { return $false }
    if (Test-InstallCommandAvailable -Name winget) {
        try {
            $exitCode = Invoke-InstallWinget
            if ($exitCode -eq 0) {
                $command = Get-InstallPowerShellCommand
                if ($command) {
                    $folder = Split-Path $command.Source -Parent
                    if (-not (Test-InstallPathEntry -Path $env:PATH -Entry $folder -Separator ([string][IO.Path]::PathSeparator))) {
                        $env:PATH = $folder + [IO.Path]::PathSeparator + $env:PATH
                    }
                    return $true
                }
            }
            Write-Host 'winget did not make PowerShell 7 available.'
        } catch { Write-Host 'winget failed to install PowerShell 7.' }
    } else { Write-Host 'winget is missing.' }
    Install-PowerShellZip
    return $true
}

function Invoke-LegionInstaller {
    param([string[]]$Tools, [string]$Source = 'BlackGad/ps-ai-marketplace', [string]$ConfigDir, [switch]$DryRun, [switch]$Yes, $Catalog, [ValidateSet('release','main')][string]$Ref = 'release', [switch]$Update, [switch]$Uninstall, [switch]$Purge)
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
                "Update ps-ai for $tool in $label ($version)"
            }
        }
        if (-not $targets.Count) { return }
        if (-not $DryRun -and -not (Confirm-InstallChange -Yes:$Yes -Question 'Update ps-ai? [y/N]')) {
            'Nothing changed. Run again with -Yes to apply.'
            return
        }
        $Source = Resolve-InstallSource -Source $Source
        foreach ($target in $targets) {
            Invoke-LegionUpdateSteps -Entry $target.Entry -ConfigDir $target.Folder -PluginRoot $target.Root -Source $Source -Ref $Ref -DryRun:$DryRun -Yes
        }
        if (-not $DryRun) { 'done: restart your sessions; run legion in the repository' }
        return
    }
    "Install ps-ai for $($Tools -join ', ')"
    $ready = Ensure-InstallPowerShell -DryRun
    $onWindows = $env:OS -eq 'Windows_NT'
    if (-not $ready -and -not $onWindows -and -not $DryRun) { return }
    $bin = Get-InstallLegionPath 'bin'
    $pathQuestion = ''
    if ($onWindows -and -not (Test-InstallPathEntry -Path (Get-InstallUserPath) -Entry $bin -Separator ';')) {
        $pathQuestion = ', and add ~/.legion/bin to your PATH'
    }
    if (-not $DryRun) {
        if (-not (Confirm-InstallChange -Yes:$Yes -Question "Install ps-ai for $($Tools -join ', ') now${pathQuestion}? [y/N]")) {
            'Nothing changed. Run again with -Yes to apply.'
            return
        }
        if (-not (Ensure-InstallPowerShell -Yes)) { return }
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
            $results += [pscustomobject]@{ Tool = $tool; Version = $version; Plugin = 'ps-ai'; Hooks = $hooks }
        }
        if ($entry.hooks.hint) { $entry.hooks.hint }
    }
    if (-not $DryRun) {
        $results | Format-Table Tool, Version, Plugin, Hooks -AutoSize
        if (-not $onWindows -and -not (Test-InstallPathEntry -Path $env:PATH -Entry $bin -Separator ([string][IO.Path]::PathSeparator))) {
            'add to your shell profile: export PATH="$HOME/.legion/bin:$PATH"'
        }
        "installed: ps-ai $pluginVersion ($Ref)"
        'next: legion add claude (or legion in a repository)'
    }
}

if (-not $NoRun) {
    $catalog = $null
    # A checked-out installer uses its matching catalog; downloaded script text fetches it.
    if (-not $PSBoundParameters.ContainsKey('Source') -and
        $PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools.json') -PathType Leaf)) {
        $catalog = Get-InstallCatalog -Catalog (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tools.json') -Raw | ConvertFrom-Json)
    }
    Invoke-LegionInstaller -Tools $Tools -Source $Source -Ref $Ref -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes -Update:$Update -Uninstall:$Uninstall -Purge:$Purge -Catalog $catalog
}
