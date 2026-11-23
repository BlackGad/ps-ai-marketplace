. (Join-Path $PSScriptRoot 'paths.ps1')
. (Join-Path $PSScriptRoot 'tools.ps1')

# Get-LegionLease and Get-LegionLeaseOwnerProcess serve status, the hook and the overseer; milestone 2 task 4 removes them.
function Get-LegionLease {
    param([string]$Repo)
    $path = Get-LegionRepoPath -Repo $Repo -Path 'temp/overseer.lock'
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
            (Test-LegionSameStartTime $process.StartTime ([datetime]$data.processStartedAt))) {
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

function Get-LegionLeaseOwnerProcess {
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
function Get-LegionWrapperCommand {
    param([string]$Id, [string]$HomeRoot = $HOME)
    if ($Id -cnotmatch '^[a-z][a-z0-9-]*$') { throw 'invalid account id' }
    $name = if ($IsWindows) { "$Id.cmd" } else { $Id }
    return [IO.Path]::GetFullPath((Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$name"))
}
