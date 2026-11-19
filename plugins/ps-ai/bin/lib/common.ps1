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
    # Shell helpers are transient; the nearest non-shell ancestor owns the CLI session.
    $process = (Get-Process -Id $PID).Parent
    while ($process -and $process.ProcessName -in @('pwsh', 'powershell', 'cmd', 'sh', 'bash', 'zsh')) {
        $process = $process.Parent
    }
    if (-not $process) { throw 'cannot find the agent session process; pass -ProcessId explicitly' }
    return $process
}
