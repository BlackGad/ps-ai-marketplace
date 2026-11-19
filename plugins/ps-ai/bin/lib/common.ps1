. (Join-Path $PSScriptRoot 'tools.ps1')

function Get-ConfigEnvName {
    param([string]$Tool)
    return (Get-PsAiTool -Tool $Tool).configEnv
}

function Get-PsAiLease {
    param([string]$Repo)
    $path = Join-Path $Repo '.agents/temp/overseer.lock'
    if (-not (Test-Path -LiteralPath $path)) { return @{ State = 'free'; Data = $null } }
    try {
        for ($readAttempt = 0; $readAttempt -lt 5; $readAttempt++) {
            try {
                $content = [System.IO.File]::ReadAllText($path)
                break
            } catch [System.IO.IOException] {
                if ($readAttempt -eq 4) { throw }
                Start-Sleep -Milliseconds 25
            }
        }
        if ([string]::IsNullOrWhiteSpace($content)) { throw "lease file is empty" }
        $data = $content | ConvertFrom-Json -ErrorAction Stop
        if (-not $data.host -or -not $data.pid -or -not $data.processStartedAt) { return @{ State = 'stale'; Data = $data } }
        if ($data.host -ine [System.Net.Dns]::GetHostName()) { return @{ State = 'foreign'; Data = $data } }
        $process = Get-Process -Id ([int]$data.pid) -ErrorAction SilentlyContinue
        if ($process -and
            $process.StartTime.ToUniversalTime() -eq ([datetime]$data.processStartedAt).ToUniversalTime()) {
            return @{ State = 'held'; Data = $data }
        }
        return @{ State = 'stale'; Data = $data }
    } catch {
        # An unreadable lease that was written moments ago is still being written by its taker, not abandoned.
        $age = [DateTime]::UtcNow - [System.IO.File]::GetLastWriteTimeUtc($path)
        if ($age.TotalSeconds -lt 10) { return @{ State = 'held'; Data = $null } }
        return @{ State = 'stale'; Data = $null }
    }
}

function Get-PsAiLeaseOwnerProcess {
    # Prefer the agent CLI over its shell helpers. A terminal session can have
    # only shell ancestors after its launcher exits; keep the oldest live one.
    $process = (Get-Process -Id $PID).Parent
    $sessionShell = $null
    while ($process -and $process.ProcessName -in @('pwsh', 'powershell', 'cmd', 'sh', 'bash', 'zsh')) {
        $sessionShell = $process
        $process = $process.Parent
    }
    if (-not $process) { $process = $sessionShell }
    if (-not $process) { throw 'cannot find the agent session process; pass -ProcessId explicitly' }
    return $process
}
function Get-PsAiWrapperCommand {
    param([string]$Id, [string]$HomeRoot = $HOME)
    if ($Id -cnotmatch '^[a-z][a-z0-9-]*$') { throw 'invalid account id' }
    $name = if ($IsWindows) { "$Id.cmd" } else { $Id }
    return [IO.Path]::GetFullPath((Join-Path $HomeRoot ".agents/bin/$name"))
}

function Get-PsAiExplicitModelArguments {
    param([string]$Model, [string[]]$Arguments, [switch]$Codex)
    $choices = [Collections.Generic.List[string]]::new()
    if ($Model) { $choices.Add($Model) }
    $explicit = $false
    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]
        $value = $null
        if ($arg -cin @('--model', '-m')) {
            if ($i + 1 -ge $Arguments.Count -or -not $Arguments[$i + 1] -or $Arguments[$i + 1].StartsWith('-')) { throw "missing model value after '$arg'" }
            $value = $Arguments[++$i]
        } elseif ($arg -cmatch '^(--model|-m)=(.*)$') {
            $value = $Matches[2]
            if (-not $value) { throw "missing model value in '$arg'" }
        } elseif ($Codex) {
            $config = $null
            if ($arg -cin @('--config=', '-c=')) { throw "missing config value in '$arg'" }
            if ($arg -cin @('-c', '--config')) {
                if ($i + 1 -ge $Arguments.Count -or -not $Arguments[$i + 1] -or $Arguments[$i + 1].StartsWith('-')) { throw "missing config value after '$arg'" }
                $config = $Arguments[++$i]
            } elseif ($arg -cmatch '^(--config=|-c=?)(.+)$') { $config = $Matches[2] }
            if ($config -cmatch '^\s*model\s*=\s*(.*)$') {
                $value = $Matches[1].Trim().Trim('"', "'")
                if (-not $value) { throw 'missing model value in config override' }
            }
        }
        if ($null -ne $value) { $explicit = $true; $choices.Add($value) }
    }
    if (@($choices | Select-Object -Unique -CaseInsensitive:$false).Count -gt 1) { throw 'conflicting explicit model choices' }
    if ($Model -and -not $explicit) { '--model'; $Model }
}
