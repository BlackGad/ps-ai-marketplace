$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/legion/bin/legion-lease.ps1'
$savedThread = $env:CODEX_THREAD_ID
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('lease-session-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    foreach ($case in @(
        @{ Tool = 'codex'; Thread = 'fixture-thread'; Expected = 'fixture-thread' },
        @{ Tool = 'codex'; Thread = ''; Expected = $null },
        @{ Tool = 'claude'; Thread = 'fixture-thread'; Expected = $null }
    )) {
        $repo = Join-Path $tempRoot ([guid]::NewGuid())
        New-Item -ItemType Directory -Path $repo | Out-Null
        $env:CODEX_THREAD_ID = $case.Thread
        & pwsh -NoProfile -File $script -Action take -Repo $repo -Tool $case.Tool -Account codex-a -ProcessId $PID | Out-Null
        Assert-Equal 0 $LASTEXITCODE 'Lease take succeeds'
        $lease = Get-Content (Join-Path $repo '.legion/temp/overseer.lock') -Raw | ConvertFrom-Json -AsHashtable
        if ($case.Expected) {
            Assert-Equal $case.Expected $lease.session 'Codex lease records its thread'
        } else {
            Assert-True (-not $lease.ContainsKey('session')) 'Other leases have no session field'
        }
    }
} finally {
    $env:CODEX_THREAD_ID = $savedThread
    $resolvedTemp = [IO.Path]::GetFullPath($tempRoot)
    $allowedTemp = [IO.Path]::GetFullPath([IO.Path]::GetTempPath())
    if (-not $resolvedTemp.StartsWith($allowedTemp, [StringComparison]::Ordinal)) { throw 'Unsafe fixture cleanup' }
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
}
