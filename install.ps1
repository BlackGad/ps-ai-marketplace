param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-ai-marketplace',
    [string]$ConfigDir,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoRun,
    [string]$SourceRef = 'main',
    [switch]$Update,
    [switch]$Uninstall
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

function Get-InstallCatalog {
    param([string]$Source, [string]$SourceRef = 'main', $Catalog)
    if ($null -eq $Catalog) {
        if (Test-Path -LiteralPath $Source -PathType Container) {
            $index = Join-Path (Resolve-Path -LiteralPath $Source).Path 'tools.json'
            if (-not (Test-Path -LiteralPath $index -PathType Leaf)) {
                throw 'Local tools.json is missing; run tools/update-tools-index.ps1 to regenerate it.'
            }
            $content = Get-Content -LiteralPath $index -Raw -ErrorAction Stop
        } elseif ($Source -match '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') {
            $content = Get-InstallSourceText -Url "https://raw.githubusercontent.com/$Source/$SourceRef/tools.json"
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
        foreach ($field in @('marketplaceAdd','marketplaceRemove','install','uninstall','marketplaceList','list','marketplaceUpdate','update')) {
            Assert-InstallArguments $tool.plugin.$field "plugin.$field"
        }
        Assert-InstallString $tool.plugin.marketplaceRemoveHint 'plugin.marketplaceRemoveHint' -AllowEmpty
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
            if ($field -eq 'cacheDir' -and $value -match '(^~|(^|[/\\])\.([/\\]|$)|[*?]|[/\\]$|[/\\]{2})') {
                throw 'invalid catalog plugin.cacheDir: expected exact relative folder path'
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
        if ($null -ne $marketplaceListing) {
            Assert-InstallObject $marketplaceListing 'marketplaceListing'
            if ($marketplaceListing.format -cne 'json') { throw 'invalid catalog marketplace listing format' }
            Assert-InstallString $marketplaceListing.nameField 'marketplaceListing.nameField'
            Assert-InstallArguments $marketplaceListing.sourceFields 'marketplaceListing.sourceFields'
            if (-not $marketplaceListing.sourceFields.Count) { throw 'marketplaceListing.sourceFields cannot be empty' }
            foreach ($field in @('collectionField', 'sourcePattern')) {
                if ($null -ne $marketplaceListing.$field) { Assert-InstallString $marketplaceListing.$field "marketplaceListing.$field" }
            }
            if ($marketplaceListing.sourcePattern) { $null = [regex]::new($marketplaceListing.sourcePattern) }
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
    param([string]$Tool, [string]$Source)
    $entry = Get-InstallTool -Tool $Tool
    $marketplace = @($entry.command) + @($entry.plugin.marketplaceAdd | ForEach-Object { if ($_ -ceq '{source}') { $Source } else { $_ } })
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
    $process = [System.Diagnostics.Process]::Start($info)
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
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir, [switch]$IncludeDisabled)
    $entry = $script:installCatalog.tools | Where-Object command -CEQ $Command[0] | Select-Object -First 1
    if (-not $entry) { throw "unknown tool command '$($Command[0])'" }
    $marketplace = @($entry.command) + @($entry.plugin.marketplaceAdd | ForEach-Object { if ($_ -ceq '{source}') { '' } else { $_ } })
    $kind = 'plugin'
    $requestedSource = ''
    if ($Command.Count -eq $marketplace.Count) {
        $same = $true
        for ($index = 0; $index -lt $Command.Count; $index++) {
            if ($index -gt 0 -and $entry.plugin.marketplaceAdd[($index - 1)] -ceq '{source}') { $requestedSource = $Command[$index]; continue }
            if ($Command[$index] -cne $marketplace[$index]) { $same = $false; break }
        }
        if ($same) { $kind = 'marketplace' }
    }
    $arguments = if ($kind -eq 'marketplace') { $entry.plugin.marketplaceList } else { $entry.plugin.list }
    $list = @($entry.command) + $arguments
    $previous = if ($ConfigEnv) { [Environment]::GetEnvironmentVariable($ConfigEnv, 'Process') } else { $null }
    try {
        if ($ConfigEnv) {
            if ($ConfigDir) { Set-InstallConfigEnvironment -Name $ConfigEnv -Value $ConfigDir }
            else { Set-InstallConfigEnvironment -Name $ConfigEnv -Value $null }
        }
        $result = Invoke-ClosedInput -Command $list -Environment $entry.plugin.listingEnv
        if ($result.ExitCode -ne 0) { throw "$($entry.command) listing exited $($result.ExitCode)" }
        return Test-InstallListing -Kind $kind -Tool $entry.id -Lines $result.Output -Source $requestedSource -IncludeDisabled:$IncludeDisabled
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
    param([ValidateSet('marketplace', 'plugin')][string]$Kind, [string]$Tool, [string[]]$Lines, [switch]$IncludeDisabled, [string]$Source)
    if ($Kind -eq 'marketplace') {
        $entry = if ($Tool) { Get-InstallTool -Tool $Tool } else { $null }
        $listing = if ($entry) { $entry.plugin.marketplaceListing } else { $null }
        $sources = @()
        if ($listing -and $listing.format -eq 'json') {
            try { $items = ($Lines -join "`n") | ConvertFrom-Json -ErrorAction Stop }
            catch { throw "$Tool marketplace listing returned invalid JSON" }
            if ($listing.collectionField -and $null -ne $items) {
                $items = Get-InstallListingField -Item $items -Field $listing.collectionField
                if ($null -eq $items) { throw "$Tool marketplace listing is missing its collection" }
            }
            foreach ($item in @($items)) {
                if ((Get-InstallListingField -Item $item -Field $listing.nameField) -cne 'ps-ai-marketplace') { continue }
                $registered = ''
                foreach ($field in $listing.sourceFields) {
                    $value = Get-InstallListingField -Item $item -Field $field
                    if ($value -is [string] -and $value) { $registered = $value; break }
                }
                if ($listing.sourcePattern -and $registered -match $listing.sourcePattern) { $registered = $Matches.source }
                $sources += $registered
            }
        } else {
            for ($index = 0; $index -lt $Lines.Count; $index++) {
                if ($Lines[$index] -notmatch '(^|[\s`])ps-ai-marketplace(\s|`|"|$)') { continue }
                $registered = ($Lines[$index] -replace '^.*?ps-ai-marketplace[\s`"]*', '').Trim()
                if (-not $registered -and $index + 1 -lt $Lines.Count -and $Lines[$index + 1] -match '^\s*Source:\s*(.+)$') { $registered = $Matches[1] }
                $sources += $registered
            }
        }
        foreach ($registered in $sources) {
            if (-not $Source) { return $true }
            if ((ConvertTo-InstallMarketplaceSource $registered) -ceq (ConvertTo-InstallMarketplaceSource $Source)) { return $true }
            $folder = if ($entry) { [Environment]::GetEnvironmentVariable($entry.configEnv, 'Process') } else { '' }
            $target = if ($folder) { $folder } else { 'default config' }
            $currentSource = if ($registered) { $registered } else { 'unknown' }
            $message = "$Tool in ${target}: ps-ai-marketplace source conflict; current source: $currentSource; requested source: $Source."
            if ($entry) {
                $remove = Format-InstallCommand -Command (@($entry.command) + $entry.plugin.marketplaceRemove)
                if ($folder) { $remove = '$env:' + $entry.configEnv + " = '" + $folder.Replace("'", "''") + "'; " + $remove }
                $message += "`nRemove command (run only if you want to replace this registration): $remove"
                if ($entry.plugin.marketplaceRemoveHint) { $message += "`n" + $entry.plugin.marketplaceRemoveHint }
            }
            $conflict = New-Object System.InvalidOperationException -ArgumentList $message
            $conflict.Data['InstallMarketplaceConflict'] = $true
            throw $conflict
        }
        return $false
    }
    $listing = if ($Tool) { (Get-InstallTool -Tool $Tool).plugin.listing } else { $null }
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

function ConvertTo-InstallMarketplaceSource {
    param([string]$Source)
    $value = $Source.Trim().Trim('"', "'", '`').Replace('\', '/').TrimEnd('/')
    if ($value -match '^(?:GitHub\s*\(|https://github\.com/|git@github\.com:|ssh://git@github\.com/)?(?<repo>[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?)(?:\.git)?\)?$') {
        return $Matches.repo.ToLowerInvariant()
    }
    if ($env:OS -eq 'Windows_NT') { return $value.ToLowerInvariant() }
    return $value
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

function Invoke-PsAiInstallSteps {
    param([string]$Tool, [string]$Source, [string]$ConfigEnv, [string]$ConfigDir, [switch]$DryRun)
    $commands = Get-InstallCommands -Tool $Tool -Source $Source
    $entry = Get-InstallTool -Tool $Tool
    $marketplaceAdded = $false
    for ($index = 0; $index -lt $commands.Count; $index++) {
        $command = $commands[$index]
        if (-not $marketplaceAdded -and (Test-InstallStepDone -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir)) {
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

function Get-InstallHome {
    return [Environment]::GetFolderPath('UserProfile')
}

function Get-UpdateConfigDirs {
    param([string]$Tool, [string]$ConfigDir)
    if ($ConfigDir) { return ,@($ConfigDir) }
    # An empty directory selects the CLI default, with its environment override cleared.
    $folders = @('')
    $homeRoot = Get-InstallHome
    $file = Join-Path $homeRoot '.agents/configuration/ps-ai-personalisation.json'
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $data = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        foreach ($agent in $data.agents) {
            if ($agent.tool -cne $Tool -or [string]::IsNullOrWhiteSpace($agent.configDir) -or $agent.configDir -eq 'default') { continue }
            $folder = $agent.configDir
            if ($folder -match '^~[/\\]') { $folder = Join-Path $homeRoot $folder.Substring(2) }
            $folder = [IO.Path]::GetFullPath($folder)
            $alreadyListed = if ($env:OS -eq 'Windows_NT') { $folders -contains $folder } else { $folders -ccontains $folder }
            if (-not $alreadyListed) { $folders += $folder }
        }
    }
    return ,$folders
}

function Get-UninstallFiles {
    param([string[]]$Tools, [string]$ConfigDir, $Owner)
    $homeRoot = Get-InstallHome
    $bin = [IO.Path]::GetFullPath((Join-Path $homeRoot '.agents/bin'))
    $paths = @()
    $remaining = $false
    foreach ($agent in $Owner.agents) {
        if ($agent.id -cnotmatch '^[a-z][a-z0-9-]*$') { continue }
        $wrapper = "~/.agents/bin/$($agent.id)"
        $owned = @($wrapper, "$wrapper.cmd", (Join-Path $homeRoot $wrapper.Substring(2)), (Join-Path $homeRoot ($wrapper.Substring(2) + '.cmd')))
        if ($agent.command -notin $owned) { continue }
        $selected = -not $Tools -or $agent.tool -cin $Tools
        if ($ConfigDir) {
            $folder = $agent.configDir
            if ($folder -match '^~[/\\]') { $folder = Join-Path $homeRoot $folder.Substring(2) }
            $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
            $selected = $selected -and $folder -and [string]::Equals([IO.Path]::GetFullPath($folder).TrimEnd('\', '/'), [IO.Path]::GetFullPath($ConfigDir).TrimEnd('\', '/'), $comparison)
        }
        foreach ($suffix in @('', '.cmd')) {
            $path = Join-Path $bin "$($agent.id)$suffix"
            if ($selected) { $paths += $path }
            elseif (Test-Path -LiteralPath $path -PathType Leaf) { $remaining = $true }
        }
    }
    if (-not $remaining) {
        foreach ($name in @('ps-ai-overseer', 'ps-ai-overseer.cmd')) {
            $path = Join-Path $bin $name
            if ((Test-Path -LiteralPath $path -PathType Leaf) -and
                [IO.File]::ReadAllText($path) -match '(-File\s+)(["''][^\r\n]*?[/\\]bin[/\\]ps-ai-overseer\.ps1["''])') { $paths += $path }
        }
        # Exact files published by Sync-PsAiFoundryRuntime; never remove the directory tree.
        $runtime = Join-Path $bin '.ps-ai-runtime'
        foreach ($name in @('bin/lib/tools.ps1', 'bin/lib/foundry.ps1', 'bin/ps-ai-foundry.ps1', 'schemas/tool.schema.json')) {
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
        # A linked file or directory belongs to its owner; do not follow it outside bin.
        $safe = $true
        $currentPath = [IO.Path]::GetFullPath($path)
        if (-not $currentPath.StartsWith($bin + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe generated file path' }
        while ($currentPath.Length -ge $bin.Length) {
            $current = Get-Item -LiteralPath $currentPath -Force -ErrorAction Stop
            if ($current.Attributes -band [IO.FileAttributes]::ReparsePoint) { $safe = $false; break }
            if ($currentPath -eq $bin) { break }
            $currentPath = Split-Path $currentPath -Parent
        }
        if ($safe) { $path }
    }
}

function Get-UninstallCachePath {
    param($Entry, [string]$ConfigDir)
    if (-not $Entry.plugin.cacheDir) { return }
    if (-not $ConfigDir) {
        if (-not $Entry.plugin.defaultConfigDir) { throw 'Missing plugin.defaultConfigDir for cache cleanup' }
        $ConfigDir = Join-Path (Get-InstallHome) $Entry.plugin.defaultConfigDir.Substring(2)
    }
    $root = [IO.Path]::GetFullPath($ConfigDir).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    $path = [IO.Path]::GetFullPath((Join-Path $root $Entry.plugin.cacheDir))
    $comparison = if ($env:OS -eq 'Windows_NT') { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    if (-not $path.StartsWith($root + [IO.Path]::DirectorySeparatorChar, $comparison)) { throw 'Unsafe plugin cache path' }
    if (-not (Test-Path -LiteralPath $path -PathType Container)) { return }
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
    $pending.Push($path)
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

function Invoke-PsAiUninstall {
    param([string[]]$Tools, [string]$ConfigDir, [switch]$DryRun, [switch]$Yes)
    $homeRoot = Get-InstallHome
    $file = Join-Path $homeRoot '.agents/configuration/ps-ai-personalisation.json'
    $owner = $null
    if (Test-Path -LiteralPath $file -PathType Leaf) {
        $owner = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    $targets = @()
    $selectedTools = if ($Tools) { $Tools } else { @($script:installCatalog.tools | ForEach-Object { $_.id }) }
    foreach ($tool in ($selectedTools | Select-Object -Unique)) {
        $entry = Get-InstallTool -Tool $tool
        if (-not (Test-InstallCommandAvailable -Name $entry.command)) { "skip: $tool (not installed)"; continue }
        $seenFolders = @()
        foreach ($folder in (Get-UpdateConfigDirs -Tool $tool -ConfigDir $ConfigDir)) {
            $resolved = if ($folder) { $folder } else { $entry.plugin.defaultConfigDir }
            if ($resolved -match '^~[/\\]') { $resolved = Join-Path $homeRoot $resolved.Substring(2) }
            if ($resolved) { $resolved = [IO.Path]::GetFullPath($resolved).TrimEnd('\', '/') }
            $seen = if ($env:OS -eq 'Windows_NT') { $seenFolders -contains $resolved } else { $seenFolders -ccontains $resolved }
            if ($seen) { continue }
            $seenFolders += $resolved
            $label = if ($folder) { $folder } else { 'default config' }
            $steps = @()
            foreach ($kind in @('plugin', 'marketplace')) {
                $check = if ($kind -eq 'plugin') { @($entry.command) + $entry.plugin.install }
                    else { @($entry.command) + @($entry.plugin.marketplaceAdd | ForEach-Object { if ($_ -ceq '{source}') { '' } else { $_ } }) }
                if (-not (Test-InstallStepDone -Command $check -ConfigEnv $entry.configEnv -ConfigDir $folder -IncludeDisabled)) {
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
    $files = @(Get-UninstallFiles -Tools $Tools -ConfigDir $ConfigDir -Owner $owner)
    foreach ($path in $files) { "Remove file: $path" }
    if (-not $files.Count) { 'skip: ps-ai generated files (not installed)' }
    $hasWork = $targets.Count -or $files.Count
    if (-not $hasWork) { 'Nothing to uninstall.' }
    if ($hasWork -and -not $DryRun -and ($Yes -or (Read-Host 'Uninstall ps-ai from these targets? [y/N]') -match '^(?i:y|yes)$')) {
        foreach ($target in $targets) {
            $entry = $target.Entry
            foreach ($step in $target.Steps) {
                if (-not (Test-InstallStepDone -Command $step.Check -ConfigEnv $entry.configEnv -ConfigDir $target.Folder -IncludeDisabled)) {
                    "skip: $($entry.id) $($step.Kind) in $(if ($target.Folder) { $target.Folder } else { 'default config' }) (not installed)"
                    continue
                }
                Invoke-InstallCommand -Command $step.Command -ConfigEnv $entry.configEnv -ConfigDir $target.Folder
            }
            if ($target.Cache) {
                $check = @($entry.command) + $entry.plugin.install
                if (Test-InstallStepDone -Command $check -ConfigEnv $entry.configEnv -ConfigDir $target.Folder -IncludeDisabled) {
                    throw "$($entry.id) plugin is still listed; cache kept."
                }
                # Recheck the exact descriptor path and links immediately before recursive deletion.
                $cache = Get-UninstallCachePath -Entry $entry -ConfigDir $target.Folder
                if ($cache -and $cache -ceq $target.Cache) {
                    Remove-Item -LiteralPath $cache -Recurse -Force -ErrorAction Stop
                }
            }
        }
        $bin = [IO.Path]::GetFullPath((Join-Path $homeRoot '.agents/bin'))
        foreach ($path in $files) {
            Remove-Item -LiteralPath $path -Force -ErrorAction Stop
            $parent = Split-Path $path -Parent
            while ($parent.Length -gt $bin.Length -and -not @(Get-ChildItem -LiteralPath $parent -Force -ErrorAction Stop).Count) {
                Remove-Item -LiteralPath $parent -ErrorAction Stop
                $parent = Split-Path $parent -Parent
            }
        }
    }
    $configuration = Join-Path $homeRoot '.agents/configuration'
    $accounts = Join-Path $homeRoot '.agents/accounts'
    if (Test-Path -LiteralPath $configuration) { "Kept settings and notes: $configuration" }
    if (Test-Path -LiteralPath $accounts) { "Kept account folders and logins: $accounts" }
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

function Invoke-PsAiUpdateSteps {
    param($Entry, [string]$ConfigDir, [switch]$DryRun, [string]$Source = 'BlackGad/ps-ai-marketplace')
    $configEnv = $Entry.configEnv
    $previous = [Environment]::GetEnvironmentVariable($configEnv, 'Process')
    try {
        if ($ConfigDir) { Set-InstallConfigEnvironment -Name $configEnv -Value $ConfigDir }
        else { Set-InstallConfigEnvironment -Name $configEnv -Value $null }
        $list = @($Entry.command) + $Entry.plugin.list
        Format-InstallCommand -Command $list -ConfigEnv $configEnv -ConfigDir $ConfigDir
        $install = @($Entry.command) + $Entry.plugin.install
        if (-not (Test-InstallStepDone -Command $install -ConfigEnv $configEnv -ConfigDir $ConfigDir -IncludeDisabled)) {
            Invoke-PsAiInstallSteps -Tool $Entry.id -Source $Source -ConfigEnv $configEnv -ConfigDir $ConfigDir -DryRun:$DryRun
            if (-not $DryRun) { Invoke-InstallRefresh -Entry $Entry -ConfigDir $ConfigDir }
            return
        }
        foreach ($arguments in @($Entry.plugin.marketplaceUpdate, $Entry.plugin.update)) {
            if (-not $arguments.Count) { continue }
            $command = @($Entry.command) + $arguments
            Format-InstallCommand -Command $command -ConfigEnv $configEnv -ConfigDir $ConfigDir
            if (-not $DryRun) { Invoke-InstallCommand -Command $command -ConfigEnv $configEnv -ConfigDir $ConfigDir }
        }
        if (-not $DryRun) { Invoke-InstallRefresh -Entry $Entry -ConfigDir $ConfigDir }
    } finally {
        Set-InstallConfigEnvironment -Name $configEnv -Value $previous
    }
}

function Invoke-InstallRefresh {
    param($Entry, [string]$ConfigDir)
    # Resolve after the update: the previous plugin cache can already be obsolete.
    $result = Invoke-ClosedInput -Command (@($Entry.command) + $Entry.plugin.list) -Environment $Entry.plugin.listingEnv
    if ($result.ExitCode -ne 0) { throw "$($Entry.command) post-update listing exited $($result.ExitCode)" }
    if (-not (Test-InstallListing -Kind plugin -Tool $Entry.id -Lines $result.Output -IncludeDisabled)) {
        throw "$($Entry.id) ps-ai is absent from the post-update listing; generated artifacts were not refreshed."
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
        foreach ($line in $result.Output) {
            if ($line -notmatch '(^|[\s`])ps-ai@ps-ai-marketplace(\s|`|"|$)' -or $line -match 'not installed') { continue }
            if ($line -match '\b(v?\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\b') { $installedVersion = $Matches[1] -replace '^v', '' }
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
            $paths = @(Get-ChildItem -LiteralPath $cacheRoot -Filter plugin.json -File -Recurse -ErrorAction Stop | ForEach-Object { $_.DirectoryName })
        }
    }
    $scripts = @()
    foreach ($path in ($paths | Select-Object -Unique)) {
        try {
            $manifest = Get-Content -LiteralPath (Join-Path $path 'plugin.json') -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($manifest.name -cne 'ps-ai' -or ($installedVersion -and $manifest.version -cne $installedVersion)) { continue }
            $script = Join-Path $path 'bin/ps-ai-refresh.ps1'
            if (Test-Path -LiteralPath $script -PathType Leaf) { $scripts += $script }
        } catch { continue }
    }
    if ($scripts.Count -ne 1) {
        throw "$($Entry.id) updated, but its installed ps-ai refresh script could not be identified uniquely; generated artifacts still need refreshing."
    }
    $powerShell = Get-InstallPowerShellCommand
    if (-not $powerShell) { throw 'PowerShell 7 is required to refresh generated ps-ai artifacts.' }
    $result = Invoke-ClosedInput -Command @($powerShell.Source, '-NoProfile', '-File', $scripts[0], '-HomeRoot', (Get-InstallHome))
    $result.Output
    $result.ErrorOutput
    if ($result.ExitCode -ne 0) { throw "ps-ai artifact refresh exited $($result.ExitCode)" }
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
    $root = Join-Path (Get-InstallHome) '.agents/tools/pwsh'
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
    if (-not ('PsAiInstall.Environment' -as [type])) {
        Add-Type -Namespace PsAiInstall -Name Environment -MemberDefinition @'
[DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern IntPtr SendMessageTimeout(IntPtr window, uint message, UIntPtr parameter, string value, uint flags, uint timeout, out UIntPtr result);
'@
    }
    $result = [UIntPtr]::Zero
    [void][PsAiInstall.Environment]::SendMessageTimeout([IntPtr]0xffff, 0x1a, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result)
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
    $temporary = Join-Path (Get-InstallHome) ('.agents/temp/ps-ai-install-' + [guid]::NewGuid().ToString('N'))
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
        $destination = Join-Path (Get-InstallHome) '.agents/tools/pwsh'
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
        if ($OnWindows -and -not $DryRun -and $portable -and $command.Source -eq $portable) {
            Add-InstallPowerShellPath -Path (Split-Path $portable -Parent)
        }
        return $true
    }
    Write-Host 'PowerShell 7 is missing.'
    if (-not $OnWindows) {
        Write-Host 'Install PowerShell 7: https://learn.microsoft.com/powershell/scripting/install/installing-powershell'
        return $false
    }
    Write-Host ('winget install --id ' + $script:installCatalog.bootstrap.windows.wingetId + ' -e')
    Write-Host 'ZIP fallback: latest official PowerShell ZIP, verified with its SHA-256 digest, to ~/.agents/tools/pwsh/ (user and process PATH).'
    if ($DryRun) { return $false }
    if (-not $Yes -and (Read-Host 'Install PowerShell 7 now? [y/N]') -notmatch '^(?i:y|yes)$') { return $false }
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
    if (-not $Yes -and (Read-Host 'Install PowerShell 7 from the official per-user ZIP now? [y/N]') -notmatch '^(?i:y|yes)$') { return $false }
    Install-PowerShellZip
    return $true
}

function Invoke-PsAiInstaller {
    param([string[]]$Tools, [string]$Source = 'BlackGad/ps-ai-marketplace', [string]$ConfigDir, [switch]$DryRun, [switch]$Yes, $Catalog, [string]$SourceRef = 'main', [switch]$Update, [switch]$Uninstall)
    if ($Update -and $Uninstall) { throw 'Choose either -Update or -Uninstall.' }
    $script:installCatalog = Get-InstallCatalog -Source $Source -SourceRef $SourceRef -Catalog $Catalog
    if ($Uninstall) {
        Invoke-PsAiUninstall -Tools $Tools -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes
        return
    }
    if (-not $Update) {
        $ready = Ensure-InstallPowerShell -DryRun:$DryRun -Yes:$Yes
        if (-not $ready -and -not $DryRun) { return }
    }
    if (-not $Tools -or $Tools.Count -eq 0) {
        $Tools = @($script:installCatalog.tools | Where-Object { Test-InstallCommandAvailable -Name $_.command } | ForEach-Object { $_.id })
    }
    if (-not $Tools -or $Tools.Count -eq 0) {
        'No coding CLI is installed. Install one, then run this script again:'
        foreach ($entry in $script:installCatalog.tools) { if ($entry.installHint) { $entry.installHint } }
        return
    }
    $results = @()
    $conflicts = 0
    $Source = Resolve-InstallSource -Source $Source
    foreach ($tool in $Tools) {
        $entry = Get-InstallTool -Tool $tool
        if ($Update) {
            if (-not (Test-InstallCommandAvailable -Name $entry.command)) {
                "skip: $tool (not installed)"
                continue
            }
        }
        $configEnv = $entry.configEnv
        try {
            foreach ($folder in (Get-UpdateConfigDirs -Tool $tool -ConfigDir $ConfigDir)) {
                if ($Update) {
                    Invoke-PsAiUpdateSteps -Entry $entry -ConfigDir $folder -DryRun:$DryRun -Source $Source
                } else {
                    Invoke-PsAiInstallSteps -Tool $tool -Source $Source -ConfigEnv $configEnv -ConfigDir $folder -DryRun:$DryRun
                }
            }
        } catch {
            if (-not $_.Exception.Data['InstallMarketplaceConflict']) { throw }
            $_.Exception.Message
            $conflicts++
            continue
        }
        if ($Update) { continue }
        if (-not $DryRun) {
            $version = (& $entry.command --version 2>$null | Select-Object -First 1)
            $hooks = $entry.hooks.status
            $results += [pscustomobject]@{ Tool = $tool; Version = $version; Plugin = 'ps-ai'; Hooks = $hooks }
        }
        if ($entry.hooks.hint) { $entry.hooks.hint }
    }
    if (-not $DryRun -and -not $Update) { $results | Format-Table Tool, Version, Plugin, Hooks -AutoSize }
    if ($conflicts) { throw "$conflicts marketplace conflict(s); resolve the registrations above and retry." }
}

if (-not $NoRun) {
    $catalog = $null
    # A checked-out installer uses its matching catalog; downloaded script text fetches it.
    if (-not $PSBoundParameters.ContainsKey('Source') -and -not $PSBoundParameters.ContainsKey('SourceRef') -and
        $PSScriptRoot -and (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'tools.json') -PathType Leaf)) {
        $catalog = Get-InstallCatalog -Source $PSScriptRoot
    }
    Invoke-PsAiInstaller -Tools $Tools -Source $Source -SourceRef $SourceRef -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes -Update:$Update -Uninstall:$Uninstall -Catalog $catalog
}
