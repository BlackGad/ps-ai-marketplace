param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-ai-marketplace',
    [string]$ConfigDir,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoRun,
    [string]$SourceRef = 'main',
    [switch]$Update
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
        foreach ($field in @('marketplaceAdd','install','marketplaceList','list','marketplaceUpdate','update')) {
            Assert-InstallArguments $tool.plugin.$field "plugin.$field"
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

function Get-ConfigEnvName {
    param([string]$Tool)
    return (Get-InstallTool -Tool $Tool).configEnv
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
    param([string[]]$Command)
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

function Test-InstallStepDone {
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
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
        if ($ConfigDir) { [Environment]::SetEnvironmentVariable($ConfigEnv, $ConfigDir, 'Process') }
        $result = Invoke-ClosedInput -Command $list
        if ($result.ExitCode -ne 0) { throw "$($entry.command) listing exited $($result.ExitCode)" }
        return Test-InstallListing -Kind $kind -Tool $entry.id -Lines $result.Output -Source $requestedSource
    } finally {
        if ($ConfigDir) { [Environment]::SetEnvironmentVariable($ConfigEnv, $previous, 'Process') }
    }
}

function Test-InstallListing {
    # Installation requires enabled plugins; updates also refresh disabled installed copies.
    param([ValidateSet('marketplace', 'plugin')][string]$Kind, [string]$Tool, [string[]]$Lines, [switch]$IncludeDisabled, [string]$Source)
    if ($Kind -eq 'marketplace') {
        for ($index = 0; $index -lt $Lines.Count; $index++) {
            if ($Lines[$index] -notmatch '(^|[\s`])ps-ai-marketplace(\s|`|"|$)') { continue }
            if (-not $Source) { return $true }
            $registered = ($Lines[$index] -replace '^.*?ps-ai-marketplace[\s`"]*', '').Trim()
            if (-not $registered -and $index + 1 -lt $Lines.Count -and $Lines[$index + 1] -match '^\s*Source:\s*(.+)$') { $registered = $Matches[1] }
            if ((ConvertTo-InstallMarketplaceSource $registered) -ceq (ConvertTo-InstallMarketplaceSource $Source)) { return $true }
            throw 'ps-ai-marketplace is already registered with a different or unknown source; inspect the CLI marketplace list and remove the conflicting registration before retrying.'
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
        if ($ConfigDir) { [Environment]::SetEnvironmentVariable($ConfigEnv, $ConfigDir, 'Process') }
        $result = Invoke-ClosedInput -Command $Command
        $result.Output
        $result.ErrorOutput
        if ($result.ExitCode -ne 0) { throw "$($Command[0]) exited $($result.ExitCode)" }
    } finally {
        [Environment]::SetEnvironmentVariable($ConfigEnv, $previous, 'Process')
    }
}

function Invoke-PsAiInstallSteps {
    param([string]$Tool, [string]$Source, [string]$ConfigEnv, [string]$ConfigDir, [switch]$DryRun)
    $commands = Get-InstallCommands -Tool $Tool -Source $Source
    foreach ($command in $commands) {
        if ($DryRun) { Format-InstallCommand -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
        elseif (Test-InstallStepDone -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir) { "skip: $($command -join ' ') (already done)" }
        else { Invoke-InstallCommand -Command $command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir }
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

function Invoke-PsAiUpdateSteps {
    param($Entry, [string]$ConfigDir, [switch]$DryRun)
    $configEnv = $Entry.configEnv
    $previous = [Environment]::GetEnvironmentVariable($configEnv, 'Process')
    try {
        [Environment]::SetEnvironmentVariable($configEnv, $ConfigDir, 'Process')
        $list = @($Entry.command) + $Entry.plugin.list
        Format-InstallCommand -Command $list -ConfigEnv $configEnv -ConfigDir $ConfigDir
        if (-not $DryRun) {
            $result = Invoke-ClosedInput -Command $list
            if ($result.ExitCode -ne 0) { throw "$($Entry.command) listing exited $($result.ExitCode)" }
            if (-not (Test-InstallListing -Kind plugin -Tool $Entry.id -Lines $result.Output -IncludeDisabled)) {
                $target = if ($ConfigDir) { $ConfigDir } else { 'default config' }
                "skip: $($Entry.id) ps-ai in $target (not installed)"
                return
            }
        }
        foreach ($arguments in @($Entry.plugin.marketplaceUpdate, $Entry.plugin.update)) {
            if (-not $arguments.Count) { continue }
            $command = @($Entry.command) + $arguments
            Format-InstallCommand -Command $command -ConfigEnv $configEnv -ConfigDir $ConfigDir
            if (-not $DryRun) { Invoke-InstallCommand -Command $command -ConfigEnv $configEnv -ConfigDir $ConfigDir }
        }
    } finally {
        [Environment]::SetEnvironmentVariable($configEnv, $previous, 'Process')
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
    param([string[]]$Tools, [string]$Source = 'BlackGad/ps-ai-marketplace', [string]$ConfigDir, [switch]$DryRun, [switch]$Yes, $Catalog, [string]$SourceRef = 'main', [switch]$Update)
    $script:installCatalog = Get-InstallCatalog -Source $Source -SourceRef $SourceRef -Catalog $Catalog
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
    $Source = Resolve-InstallSource -Source $Source
    foreach ($tool in $Tools) {
        $entry = Get-InstallTool -Tool $tool
        if ($Update) {
            if (-not (Test-InstallCommandAvailable -Name $entry.command)) {
                "skip: $tool (not installed)"
                continue
            }
            foreach ($folder in (Get-UpdateConfigDirs -Tool $tool -ConfigDir $ConfigDir)) {
                Invoke-PsAiUpdateSteps -Entry $entry -ConfigDir $folder -DryRun:$DryRun
            }
            continue
        }
        $configEnv = $entry.configEnv
        Invoke-PsAiInstallSteps -Tool $tool -Source $Source -ConfigEnv $configEnv -ConfigDir $ConfigDir -DryRun:$DryRun
        if (-not $DryRun) {
            $version = (& $entry.command --version 2>$null | Select-Object -First 1)
            $hooks = $entry.hooks.status
            $results += [pscustomobject]@{ Tool = $tool; Version = $version; Plugin = 'ps-ai'; Hooks = $hooks }
        }
        if ($entry.hooks.hint) { $entry.hooks.hint }
    }
    if (-not $DryRun -and -not $Update) { $results | Format-Table Tool, Version, Plugin, Hooks -AutoSize }
}

if (-not $NoRun) {
    Invoke-PsAiInstaller -Tools $Tools -Source $Source -SourceRef $SourceRef -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes -Update:$Update
}
