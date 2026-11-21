$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path $root ('.agents/temp/restructure/lease-release-' + [guid]::NewGuid().ToString('N'))
$repo = Join-Path $tempRoot 'repo'
$leasePath = Join-Path $repo '.legion/temp/overseer.lock'
$guardPath = "$leasePath.takeover"
$eventsPath = Join-Path $tempRoot 'events.txt'
$fixtureScript = Join-Path $tempRoot 'legion-lease.ps1'
New-Item -ItemType Directory -Path (Split-Path $leasePath -Parent) -Force | Out-Null
try {
    Copy-Item (Join-Path $root 'plugins/legion/bin/legion-lease.ps1') $fixtureScript
    New-Item -ItemType Directory -Path (Join-Path $tempRoot 'lib') -Force | Out-Null
    Copy-Item (Join-Path $root 'plugins/legion/bin/lib/paths.ps1') (Join-Path $tempRoot 'lib/paths.ps1')
    # A contender tries to replace the lease at both release boundaries. Only common I/O is replaced.
    @'
. (Join-Path $PSScriptRoot 'paths.ps1')
function Invoke-FixtureTakeover {
    param([string]$Boundary)
    $leasePath = Join-Path $Repo '.legion/temp/overseer.lock'
    $guardPath = "$leasePath.takeover"
    $eventsPath = Join-Path $PSScriptRoot '../events.txt'
    try {
        $contender = [IO.File]::Open($guardPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    } catch [IO.IOException] {
        Add-Content -LiteralPath $eventsPath -Value "${Boundary}:blocked"
        return
    }
    try {
        [IO.File]::WriteAllText($leasePath, '{"account":"successor","pid":99999999,"host":"fixture","startedAt":"replacement"}')
        Add-Content -LiteralPath $eventsPath -Value "${Boundary}:admitted"
    } finally {
        $contender.Dispose()
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $guardPath -Force
    }
}
function Get-LegionLease {
    param([string]$Repo)
    $leasePath = Join-Path $Repo '.legion/temp/overseer.lock'
    if (-not (Test-Path -LiteralPath $leasePath)) { return @{ State = 'free'; Data = $null } }
    $snapshot = [IO.File]::ReadAllText($leasePath) | ConvertFrom-Json
    Invoke-FixtureTakeover -Boundary read
    return @{ State = 'held'; Data = $snapshot }
}
function Remove-Item {
    [CmdletBinding()]
    param([string]$LiteralPath, [switch]$Force)
    if ($LiteralPath -eq (Join-Path $Repo '.legion/temp/overseer.lock')) {
        Invoke-FixtureTakeover -Boundary remove
    }
    Microsoft.PowerShell.Management\Remove-Item @PSBoundParameters
}
'@ | Set-Content -LiteralPath (Join-Path $tempRoot 'lib/common.ps1')
    $owner = @{
        tool = 'codex'; account = 'owner'; pid = $PID
        host = [Net.Dns]::GetHostName()
        processStartedAt = (Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o')
        startedAt = '2026-11-18T10:00:00Z'
    }
    $owner | ConvertTo-Json | Set-Content -LiteralPath $leasePath
    $output = & pwsh -NoProfile -File $fixtureScript -Action release -Repo $repo -ProcessId $PID 2>&1
    Assert-Equal 0 $LASTEXITCODE 'Owner release succeeds while competing takeover is blocked'
    Assert-Equal 'read:blocked,remove:blocked' ((Get-Content -LiteralPath $eventsPath) -join ',') 'Release protects its identity read and removal with the takeover guard'
    Assert-True (-not (Test-Path -LiteralPath $leasePath)) 'Guarded release removes the original owner lease'
    Assert-True (-not (Test-Path -LiteralPath $guardPath)) 'Release disposes and removes its guard'

    $owner | ConvertTo-Json | Set-Content -LiteralPath $leasePath
    Remove-Item -LiteralPath $eventsPath
    $otherGuard = [IO.File]::Open($guardPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $output = & pwsh -NoProfile -File $fixtureScript -Action release -Repo $repo -ProcessId $PID 2>&1
        Assert-Equal 1 $LASTEXITCODE 'Release retries when another session holds the change guard'
        Assert-Equal 'owner' ((Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json).account) 'Contended release preserves the current lease'
        Assert-True (-not (Test-Path -LiteralPath $eventsPath)) 'Contended release does not read unguarded ownership'
        Assert-True (Test-Path -LiteralPath $guardPath) 'Release preserves another session guard'
    } finally {
        $otherGuard.Dispose()
        Remove-Item -LiteralPath $guardPath -Force
    }

    $owner.pid = 99999999
    $owner | ConvertTo-Json | Set-Content -LiteralPath $leasePath
    $output = & pwsh -NoProfile -File $fixtureScript -Action release -Repo $repo -ProcessId $PID 2>&1
    Assert-Equal 1 $LASTEXITCODE 'Release rejects ownership changed before its guarded read'
    Assert-Equal 99999999 ((Get-Content -LiteralPath $leasePath -Raw | ConvertFrom-Json).pid) 'Guarded identity check preserves the replacement owner'
    Assert-True (-not (Test-Path -LiteralPath $guardPath)) 'Rejected release also disposes its guard'
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp/restructure')) + [IO.Path]::DirectorySeparatorChar
    if (-not ([IO.Path]::GetFullPath($tempRoot)).StartsWith($allowed)) { throw 'unsafe lease release fixture cleanup' }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
