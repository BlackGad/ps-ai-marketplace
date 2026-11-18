param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-ai-marketplace',
    [string]$ConfigDir,
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$NoRun
)

# Standalone: this file also runs as downloaded script text in Windows PowerShell 5.1.
function Get-ConfigEnvName {
    param([string]$Tool)
    switch ($Tool) {
        claude { return 'CLAUDE_CONFIG_DIR' }
        codex { return 'CODEX_HOME' }
        copilot { return 'COPILOT_HOME' }
        default { throw "unknown tool '$Tool'" }
    }
}

function ConvertTo-InstallArgument {
    # Windows command-line quoting, including embedded quotes and trailing backslashes.
    param([string]$Value)
    return '"' + ([regex]::Replace([regex]::Replace($Value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1')) + '"'
}

function Get-InstallCommands {
    param([string]$Tool, [string]$Source)
    $null = Get-ConfigEnvName -Tool $Tool
    $action = if ($Tool -eq 'codex') { 'add' } else { 'install' }
    $commands = @(
        [string[]]@($Tool, 'plugin', 'marketplace', 'add', $Source),
        [string[]]@($Tool, 'plugin', $action, 'ps-ai@ps-ai-marketplace')
    )
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
    $result = @{ ExitCode = $process.ExitCode; Output = @(($output + $errorTask.Result) -split "`r?`n" | Where-Object { $_ }) }
    $process.Dispose()
    return $result
}

function Test-InstallStepDone {
    param([string[]]$Command, [string]$ConfigEnv, [string]$ConfigDir)
    $list = if ($Command[2] -eq 'marketplace') { @($Command[0], 'plugin', 'marketplace', 'list') }
    elseif ($Command[0] -eq 'claude') { @($Command[0], 'plugin', 'list', '--json') }
    else { @($Command[0], 'plugin', 'list') }
    $kind = if ($Command[2] -eq 'marketplace') { 'marketplace' } else { 'plugin' }
    $previous = if ($ConfigEnv) { [Environment]::GetEnvironmentVariable($ConfigEnv, 'Process') } else { $null }
    try {
        if ($ConfigDir) { [Environment]::SetEnvironmentVariable($ConfigEnv, $ConfigDir, 'Process') }
        return Test-InstallListing -Kind $kind -Tool $Command[0] -Lines (Invoke-ClosedInput -Command $list).Output
    } finally {
        if ($ConfigDir) { [Environment]::SetEnvironmentVariable($ConfigEnv, $previous, 'Process') }
    }
}

function Test-InstallListing {
    # Plugin listings also show available plugins ("not installed") and live but disabled ones; only enabled counts.
    param([ValidateSet('marketplace', 'plugin')][string]$Kind, [string]$Tool, [string[]]$Lines)
    if ($Kind -eq 'marketplace') {
        return [bool](@($Lines) | Where-Object { $_ -match '(^|[\s`])ps-ai-marketplace(\s|`|"|$)' })
    }
    if ($Tool -eq 'claude') {
        try {
            $plugins = @((($Lines -join "`n") | ConvertFrom-Json -ErrorAction Stop))
            return [bool](@($plugins | Where-Object { $_.id -eq 'ps-ai@ps-ai-marketplace' -and $_.enabled -eq $true }).Count)
        } catch { return $false }
    }
    $matching = @($Lines) | Where-Object { $_ -match 'ps-ai@ps-ai-marketplace' }
    return [bool](@($matching) | Where-Object { $_ -notmatch 'not installed|disabled' })
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

function Test-InstallCommandAvailable {
    param([string]$Name)
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Get-InstallPowerShellCommand {
    $command = Get-Command pwsh -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($command) { return $command }
    $portable = Join-Path (Get-InstallHome) '.agents/tools/pwsh/pwsh.exe'
    if (Test-Path -LiteralPath $portable) { return @{ Source=$portable } }
    if ($env:OS -eq 'Windows_NT' -and $env:ProgramFiles) {
        $candidate = Join-Path $env:ProgramFiles 'PowerShell/7/pwsh.exe'
        if (Test-Path -LiteralPath $candidate) { return @{ Source=$candidate } }
    }
}

function Get-InstallUserPath {
    return [Environment]::GetEnvironmentVariable('Path', 'User')
}

function Set-InstallUserPath {
    param([string]$Path)
    [Environment]::SetEnvironmentVariable('Path', $Path, 'User')
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
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -ErrorAction Stop
}

function Invoke-InstallWinget {
    $result = Invoke-ClosedInput -Command @('winget', 'install', '--id', 'Microsoft.PowerShell', '-e')
    foreach ($line in $result.Output) { Write-Host $line }
    return $result.ExitCode
}

function Install-PowerShellZip {
    $temporary = Join-Path (Get-InstallHome) ('.agents/temp/ps-ai-install-' + [guid]::NewGuid().ToString('N'))
    $metadata = Join-Path $temporary 'release.json'
    $archive = Join-Path $temporary 'pwsh.zip'
    try {
        New-Item -ItemType Directory -Path $temporary -Force -ErrorAction Stop | Out-Null
        Invoke-InstallDownload -Url 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -OutFile $metadata
        $release = Get-Content -LiteralPath $metadata -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $version = $release.tag_name -replace '^v', ''
        $asset = $release.assets | Where-Object { $_.name -eq "PowerShell-$version-win-x64.zip" } | Select-Object -First 1
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
        if (-not (Test-Path -LiteralPath (Join-Path $destination 'pwsh.exe'))) { throw 'PowerShell ZIP does not contain pwsh.exe.' }
        Add-InstallPowerShellPath -Path $destination
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
        $portable = Join-Path (Get-InstallHome) '.agents/tools/pwsh'
        if ($OnWindows -and -not $DryRun -and $command.Source -eq (Join-Path $portable 'pwsh.exe')) {
            Add-InstallPowerShellPath -Path $portable
        }
        return $true
    }
    Write-Host 'PowerShell 7 is missing.'
    if (-not $OnWindows) {
        Write-Host 'Install PowerShell 7: https://learn.microsoft.com/powershell/scripting/install/installing-powershell'
        return $false
    }
    Write-Host 'winget install --id Microsoft.PowerShell -e'
    Write-Host 'ZIP fallback: latest official PowerShell-<v>-win-x64.zip, verified with its SHA-256 digest, to ~/.agents/tools/pwsh/ (user and process PATH).'
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
    param([string[]]$Tools, [string]$Source = 'BlackGad/ps-ai-marketplace', [string]$ConfigDir, [switch]$DryRun, [switch]$Yes)
    $ready = Ensure-InstallPowerShell -DryRun:$DryRun -Yes:$Yes
    if (-not $ready -and -not $DryRun) { return }
    if (-not $Tools -or $Tools.Count -eq 0) {
        $Tools = @('claude', 'codex', 'copilot') | Where-Object { Test-InstallCommandAvailable -Name $_ }
    }
    if (-not $Tools -or $Tools.Count -eq 0) {
        'No coding CLI is installed. Install one, then run this script again:'
        'irm https://claude.ai/install.ps1 | iex'
        'npm install -g @openai/codex'
        'npm install -g @github/copilot'
        return
    }
    $results = @()
    $Source = Resolve-InstallSource -Source $Source
    foreach ($tool in $Tools) {
        $configEnv = Get-ConfigEnvName -Tool $tool
        Invoke-PsAiInstallSteps -Tool $tool -Source $Source -ConfigEnv $configEnv -ConfigDir $ConfigDir -DryRun:$DryRun
        if (-not $DryRun) {
            $version = (& $tool --version 2>$null | Select-Object -First 1)
            $hooks = switch ($tool) { claude { 'active' } codex { 'trust once with /hooks' } copilot { 'unknown' } }
            $results += [pscustomobject]@{ Tool = $tool; Version = $version; Plugin = 'ps-ai'; Hooks = $hooks }
        }
    }
    if ($Tools -contains 'codex') { 'Codex: approve the ps-ai hooks once with /hooks in a Codex session.' }
    if (-not $DryRun) { $results | Format-Table Tool, Version, Plugin, Hooks -AutoSize }
}

if (-not $NoRun) {
    Invoke-PsAiInstaller -Tools $Tools -Source $Source -ConfigDir $ConfigDir -DryRun:$DryRun -Yes:$Yes
}
