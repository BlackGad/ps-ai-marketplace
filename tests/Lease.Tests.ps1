$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-lease.ps1'
$hook = Join-Path $root 'plugins/ps-ai/hooks/detect-mode.ps1'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
$repo = Join-Path $tempRoot 'repo'
New-Item -ItemType Directory -Path $repo -Force | Out-Null
try {
    # Each helper exits before the next starts; their non-shell ancestor stays alive.
    & pwsh -NoProfile -File $script -Action take -Repo $repo -Tool codex -Account session | Out-Null
    . (Join-Path $root 'plugins/ps-ai/bin/PsAi.Common.ps1')
    Assert-Equal 'held' (Get-PsAiLease -Repo $repo).State 'A short-lived helper leases for its long-lived parent'
    $path = Join-Path $repo '.agents/temp/overseer.lock'
    $saved = Get-Content $path -Raw | ConvertFrom-Json
    Assert-True ([bool]$saved.processStartedAt) 'Lease records owner process lifetime'
    & pwsh -NoProfile -File $script -Action release -Repo $repo | Out-Null
    Assert-True (-not (Test-Path $path)) 'A fresh helper releases the session lock'
    $saved.pid = $PID
    $saved.processStartedAt = (Get-Process -Id $PID).StartTime.ToUniversalTime().AddSeconds(-1).ToString('o')
    $saved | ConvertTo-Json | Set-Content $path
    Assert-Equal 'stale' (Get-PsAiLease -Repo $repo).State 'Reused PID with a different start time is stale'
    & $script -Action release -Repo $repo -ProcessId $PID 2>$null | Out-Null
    Assert-True (Test-Path $path) 'Reused PID cannot release the old process lock'
    Remove-Item -LiteralPath $path
    $runner = Join-Path $tempRoot 'runner.ps1'
    @'
param($LeaseScript, $Repo, $Account)
& $LeaseScript -Action take -Repo $Repo -Tool codex -Account $Account -ProcessId $PID
$result = $LASTEXITCODE
Start-Sleep -Seconds 2
exit $result
'@ | Set-Content -LiteralPath $runner
    $outputs = 1..2 | ForEach-Object { Join-Path $tempRoot "take$_.out" }
    $errors = 1..2 | ForEach-Object { Join-Path $tempRoot "take$_.err" }
    $processes = 1..2 | ForEach-Object {
        Start-Process pwsh -ArgumentList @('-NoProfile', '-File', "`"$runner`"", "`"$script`"", "`"$repo`"", "unit$_") -PassThru -Wait:$false -RedirectStandardOutput $outputs[$_ - 1] -RedirectStandardError $errors[$_ - 1] -WindowStyle Hidden
    }
    $processes | Wait-Process
    Assert-Equal 1 @($processes | Where-Object ExitCode -eq 0).Count 'Only one concurrent lease take succeeds'
    $leasePath = Join-Path $repo '.agents/temp/overseer.lock'
    $lease = Get-Content -Raw $leasePath | ConvertFrom-Json
    Assert-Equal ([System.Net.Dns]::GetHostName()) $lease.host 'Lease records DNS host'
    . $hook -NoRun
    $repo = Join-Path $tempRoot 'repo'
    Assert-Equal 'stale' (Get-PsAiLease -Repo $repo).State "Hook sees the exited process as stale; outputs: $((Get-Content $outputs -Raw) -join '|'); errors: $((Get-Content $errors -Raw) -join '|')"
    & $script -Action take -Repo $repo -Tool codex -Account $lease.account -ProcessId $PID | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'Stale lease can be taken'
    Assert-Equal 'held' (Get-PsAiLease -Repo $repo).State 'Hook sees a live lease'
    $again = & $script -Action take -Repo $repo -Tool codex -Account $lease.account -ProcessId $PID
    Assert-Equal 0 $LASTEXITCODE 'Current holder may take twice'
    Assert-True (@($again) -match 'skip:') 'Second take is a skip'
    & $script -Action release -Repo $repo -Tool codex -Account wrong -ProcessId 99999999 | Out-Null
    Assert-True (Test-Path $leasePath) 'Other process cannot release a lease'
    & $script -Action release -Repo $repo -Tool codex -Account $lease.account -ProcessId $PID | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'Holder releases lease'
    Assert-True (-not (Test-Path $leasePath)) 'Release removes lease'
    $repeat = & $script -Action release -Repo $repo -Tool codex -Account $lease.account -ProcessId $PID
    Assert-Equal 0 $LASTEXITCODE 'Release twice succeeds'
    Assert-True (@($repeat) -match 'skip:') 'Second release is a skip'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
