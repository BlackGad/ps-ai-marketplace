param(
    [ValidateSet('take', 'release', 'status')][string]$Action,
    [string]$Repo = (Get-Location).Path,
    [string]$Tool,
    [string]$Account,
    [int]$ProcessId
)

. (Join-Path $PSScriptRoot 'lib/common.ps1')
$path = Get-LegionRepoPath -Repo $Repo -Path 'temp/overseer.lock'
$hostName = [System.Net.Dns]::GetHostName()

if ($Action -eq 'status') {
    $lease = Get-LegionLease -Repo $Repo
    $lease.State
    exit 0
}

$ownerProcess = if ($PSBoundParameters.ContainsKey('ProcessId')) {
    Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
} else { Get-LegionLeaseOwnerProcess }
$ProcessId = if ($ownerProcess) { $ownerProcess.Id } else { $ProcessId }
$processStartedAt = if ($ownerProcess) { $ownerProcess.StartTime.ToUniversalTime().ToString('o') } else { $null }

function Open-LegionLeaseGuard {
    param([string]$Path)
    $guardPath = "$Path.takeover"
    if ((Test-Path -LiteralPath $guardPath) -and
        ([DateTime]::UtcNow - [System.IO.File]::GetLastWriteTimeUtc($guardPath)).TotalSeconds -gt 30) {
        Remove-Item -LiteralPath $guardPath -Force -ErrorAction SilentlyContinue
    }
    try {
        return [System.IO.File]::Open($guardPath, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
    } catch [System.IO.IOException] {
        return $null
    }
}

if ($Action -eq 'release') {
    if (-not (Test-Path -LiteralPath $path)) { 'skip: lease release (already done)'; exit 0 }
    $guard = Open-LegionLeaseGuard -Path $path
    if (-not $guard) {
        [Console]::Error.WriteLine('lease change in progress in another session; retry')
        exit 1
    }
    try {
        $lease = Get-LegionLease -Repo $Repo
        if ($lease.State -eq 'free') { 'skip: lease release (already done)'; exit 0 }
        if ($lease.Data -and $processStartedAt -and $lease.Data.host -ieq $hostName -and
            [int]$lease.Data.pid -eq $ProcessId -and $lease.Data.processStartedAt -and
            (Test-LegionSameStartTime ([datetime]$lease.Data.processStartedAt) $ownerProcess.StartTime)) {
            Remove-Item -LiteralPath $path -Force
            'lease released'
            exit 0
        }
        [Console]::Error.WriteLine('lease belongs to another session; cannot release it')
        exit 1
    } finally {
        $guard.Dispose()
        Remove-Item -LiteralPath "$path.takeover" -Force -ErrorAction SilentlyContinue
    }
}

function Remove-LegionStaleLease {
    # Only one session at a time may replace a stale lease, and only the exact stale lease it saw.
    param([string]$Path, $Seen)
    $guard = Open-LegionLeaseGuard -Path $Path
    if (-not $guard) { return $false }
    try {
        $current = Get-LegionLease -Repo $Repo
        if ($current.State -ne 'stale') { return $true }
        $unchanged = ($null -eq $Seen -and $null -eq $current.Data) -or
            ($null -ne $Seen -and $null -ne $current.Data -and $Seen.pid -eq $current.Data.pid -and $Seen.startedAt -eq $current.Data.startedAt)
        if ($unchanged) { Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue }
        return $true
    } finally {
        $guard.Dispose()
        Remove-Item -LiteralPath "$Path.takeover" -Force -ErrorAction SilentlyContinue
    }
}

if (-not $Tool -or -not $Account) { throw 'take requires -Tool and -Account' }
if (-not $ownerProcess) { throw 'lease owner process is not running' }
New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
$data = @{ tool = $Tool; account = $Account; pid = $ProcessId; processStartedAt = $processStartedAt; host = $hostName; startedAt = [DateTimeOffset]::UtcNow.ToString('o') }
for ($attempt = 0; $attempt -lt 2; $attempt++) {
    try {
        $stream = [System.IO.File]::Open($path, [System.IO.FileMode]::CreateNew, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $bytes = [System.Text.Encoding]::UTF8.GetBytes(($data | ConvertTo-Json -Compress) + "`n")
            $stream.Write($bytes, 0, $bytes.Length)
        } finally { $stream.Dispose() }
        'lease taken'
        exit 0
    } catch [System.IO.IOException] {
        $lease = Get-LegionLease -Repo $Repo
        if ($lease.State -eq 'held' -and $lease.Data.host -ieq $hostName -and [int]$lease.Data.pid -eq $ProcessId) {
            'skip: lease take (already done)'
            exit 0
        }
        if ($lease.State -eq 'foreign') {
            [Console]::Error.WriteLine("lease from host $($lease.Data.host); ask the owner")
            exit 1
        }
        if ($lease.State -eq 'held' -and $null -eq $lease.Data) {
            [Console]::Error.WriteLine('lease is being taken by another session; retry')
            exit 1
        }
        if ($lease.State -eq 'held') {
            [Console]::Error.WriteLine("lease held by $($lease.Data.tool) $($lease.Data.account) since $($lease.Data.startedAt)")
            exit 1
        }
        if ($attempt -eq 0 -and $lease.State -eq 'stale') {
            if (-not (Remove-LegionStaleLease -Path $path -Seen $lease.Data)) {
                [Console]::Error.WriteLine('lease takeover in progress in another session; retry')
                exit 1
            }
            continue
        }
        [Console]::Error.WriteLine('lease unavailable; retry takeover')
        exit 1
    }
}
