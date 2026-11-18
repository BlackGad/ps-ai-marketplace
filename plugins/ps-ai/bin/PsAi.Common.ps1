function Get-ConfigEnvName {
    param([string]$Tool)
    switch ($Tool) {
        claude { return 'CLAUDE_CONFIG_DIR' }
        codex { return 'CODEX_HOME' }
        copilot { return 'COPILOT_HOME' }
        default { throw "unknown tool '$Tool'" }
    }
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
        if (-not $data.host -or -not $data.pid) { return @{ State = 'stale'; Data = $data } }
        if ($data.host -ine [System.Net.Dns]::GetHostName()) { return @{ State = 'foreign'; Data = $data } }
        if (Get-Process -Id ([int]$data.pid) -ErrorAction SilentlyContinue) { return @{ State = 'held'; Data = $data } }
        return @{ State = 'stale'; Data = $data }
    } catch {
        # An unreadable lease that was written moments ago is still being written by its taker, not abandoned.
        $age = [DateTime]::UtcNow - [System.IO.File]::GetLastWriteTimeUtc($path)
        if ($age.TotalSeconds -lt 10) { return @{ State = 'held'; Data = $null } }
        return @{ State = 'stale'; Data = $null }
    }
}
