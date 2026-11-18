param(
    [string[]]$Tools,
    [string]$Source = 'BlackGad/ps-ai-marketplace',
    [string]$ConfigDir,
    [switch]$DryRun,
    [switch]$NoRun
)

. (Join-Path $PSScriptRoot '../plugins/ps-ai/bin/PsAi.Common.ps1')

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
    $info = [System.Diagnostics.ProcessStartInfo]::new((Get-Command $Command[0] -CommandType Application)[0].Source)
    foreach ($argument in $Command[1..($Command.Count - 1)]) { $info.ArgumentList.Add($argument) }
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $process = [System.Diagnostics.Process]::Start($info)
    $process.StandardInput.Close()
    $errorTask = $process.StandardError.ReadToEndAsync()
    $output = $process.StandardOutput.ReadToEnd()
    $process.WaitForExit()
    return @{ ExitCode = $process.ExitCode; Output = @(($output + $errorTask.Result) -split "`r?`n" | Where-Object { $_ }) }
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

if (-not $NoRun) {
    if (-not $Tools -or $Tools.Count -eq 0) {
        $Tools = @('claude', 'codex', 'copilot') | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue }
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
    if (-not $DryRun) { $results | Format-Table Tool, Version, Plugin, Hooks -AutoSize }
}
