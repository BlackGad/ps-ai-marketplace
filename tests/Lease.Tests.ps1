$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-lease.ps1'
$hook = Join-Path $root 'plugins/ps-ai/hooks/detect-mode.ps1'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
$repo = Join-Path $tempRoot 'repo'
New-Item -ItemType Directory -Path $repo -Force | Out-Null
try {
    # Each helper exits before the next starts; their non-shell ancestor stays alive.
    & pwsh -NoProfile -File $script -Action take -Repo $repo -Tool codex -Account session | Out-Null
    . (Join-Path $root 'plugins/ps-ai/bin/lib/common.ps1')
    Assert-Equal 'held' (Get-PsAiLease -Repo $repo).State 'A short-lived helper leases for its long-lived parent'
    $path = Join-Path $repo '.legion/temp/overseer.lock'
    $saved = Get-Content $path -Raw | ConvertFrom-Json
    Assert-True ([bool]$saved.processStartedAt) 'Lease records owner process lifetime'
    & pwsh -NoProfile -File $script -Action release -Repo $repo | Out-Null
    Assert-True (-not (Test-Path $path)) 'A fresh helper releases the session lock'

    # A terminal's native parent may have exited. Keep a session alive beyond a
    # short launcher, then run separate helpers through bash, as Claude does.
    # Windows also ships a WSL bash launcher; this case needs Git's MSYS shell.
    $bash = Get-Command bash -All -CommandType Application -ErrorAction SilentlyContinue | Where-Object {
        $directory = Split-Path $_.Source -Parent
        (Test-Path (Join-Path $directory 'msys-2.0.dll')) -or
        (Test-Path (Join-Path $directory '../usr/bin/msys-2.0.dll'))
    } | Select-Object -First 1
    if ($IsWindows -and $bash) {
        $sessionScript = Join-Path $tempRoot 'session.ps1'
        @'
param($Root, $LeaseScript, $Repo, $Bash, $Ready)
$ErrorActionPreference = 'Stop'
while (-not (Test-Path -LiteralPath $Ready)) { Start-Sleep -Milliseconds 25 }
. (Join-Path $Root 'tests/Assert.ps1')
. (Join-Path $Root 'plugins/ps-ai/bin/lib/common.ps1')
$env:PS_AI_TEST_LEASE_SCRIPT = $LeaseScript
$env:PS_AI_TEST_LEASE_REPO = $Repo
& $Bash -c 'pwsh -NoProfile -File "$PS_AI_TEST_LEASE_SCRIPT" -Action take -Repo "$PS_AI_TEST_LEASE_REPO" -Tool codex -Account session'
Assert-Equal 0 $LASTEXITCODE 'Bash helper takes the session lease'
Assert-Equal 'held' (Get-PsAiLease -Repo $Repo).State 'A short-lived bash helper leases for its long-lived parent'
$lease = Get-Content (Join-Path $Repo '.legion/temp/overseer.lock') -Raw | ConvertFrom-Json
Assert-Equal $PID $lease.pid 'Shell-only ancestry uses the surviving session, not bash or the helper'
Assert-Equal (Get-Process -Id $PID).StartTime.ToUniversalTime() ([datetime]$lease.processStartedAt).ToUniversalTime() 'Lease start time belongs to the selected session'
& $Bash -c 'pwsh -NoProfile -File "$PS_AI_TEST_LEASE_SCRIPT" -Action release -Repo "$PS_AI_TEST_LEASE_REPO"'
Assert-Equal 0 $LASTEXITCODE 'Another bash helper releases the session lease'
Assert-Equal 'free' (Get-PsAiLease -Repo $Repo).State 'Bash release removes the session lease'
'bash session passed'
'@ | Set-Content -LiteralPath $sessionScript
        $launcher = Join-Path $tempRoot 'launch.ps1'
        @'
param($SessionScript, $Root, $LeaseScript, $Repo, $Bash, $Ready, $Output, $Errors, $PidFile)
$arguments = @('-NoProfile', '-File', "`"$SessionScript`"", "`"$Root`"", "`"$LeaseScript`"", "`"$Repo`"", "`"$Bash`"", "`"$Ready`"")
$session = Start-Process pwsh -ArgumentList $arguments -PassThru -WindowStyle Hidden -RedirectStandardOutput $Output -RedirectStandardError $Errors
$session.Id | Set-Content -LiteralPath $PidFile
'@ | Set-Content -LiteralPath $launcher
        $ready = Join-Path $tempRoot 'ready'
        $output = Join-Path $tempRoot 'session.out'
        $errors = Join-Path $tempRoot 'session.err'
        $pidFile = Join-Path $tempRoot 'session.pid'
        $launchArguments = @('-NoProfile', '-File', "`"$launcher`"", "`"$sessionScript`"", "`"$root`"", "`"$script`"", "`"$repo`"", "`"$($bash.Source)`"", "`"$ready`"", "`"$output`"", "`"$errors`"", "`"$pidFile`"")
        $launchProcess = Start-Process pwsh -ArgumentList $launchArguments -PassThru -WindowStyle Hidden
        Assert-True ($launchProcess.WaitForExit(10000)) 'Transient session launcher exits'
        $sessionId = Get-Content -LiteralPath $pidFile
        $session = Get-Process -Id ([int]$sessionId)
        try {
            # The launcher has exited before its child walks the ancestor chain.
            Set-Content -LiteralPath $ready -Value 'go'
            Assert-True ($session.WaitForExit(30000)) 'Bash session finishes within its deadline'
            $sessionErrors = Get-Content -LiteralPath $errors -Raw
            Assert-True ([string]::IsNullOrWhiteSpace($sessionErrors)) "Bash session has no errors: $sessionErrors"
            Assert-True ((Get-Content -LiteralPath $output -Raw).Contains('bash session passed')) 'Bash chain checks completed'
        } finally {
            if (-not $session.HasExited) { $session.Kill() }
        }
    }
    $invalid = $saved | Select-Object * -ExcludeProperty processStartedAt
    foreach ($leaseHost in @($saved.host, 'fixture-foreign-host')) {
        $invalid.host = $leaseHost
        $invalid | ConvertTo-Json | Set-Content $path
        Assert-Equal 'stale' (Get-PsAiLease -Repo $repo).State 'A lease without process identity is invalid on any host'
    }
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
    $leasePath = Join-Path $repo '.legion/temp/overseer.lock'
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
