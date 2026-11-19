$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-lease.ps1'
. (Join-Path $root 'plugins/ps-ai/bin/lib/common.ps1')
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
$repo = Join-Path $tempRoot 'repo'
$leasePath = Join-Path $repo '.agents/temp/overseer.lock'
New-Item -ItemType Directory -Path (Split-Path $leasePath -Parent) -Force | Out-Null
try {
    # A lease file that was just created but not yet written belongs to a session that is taking it.
    [System.IO.File]::WriteAllText($leasePath, '')
    Assert-Equal 'held' (Get-PsAiLease -Repo $repo).State 'A lease being written is held, not stale'
    & $script -Action take -Repo $repo -Tool codex -Account other -ProcessId $PID 2>$null | Out-Null
    Assert-Equal 1 $LASTEXITCODE 'A lease being written cannot be taken'
    [System.IO.File]::SetLastWriteTimeUtc($leasePath, [DateTime]::UtcNow.AddMinutes(-5))
    Assert-Equal 'stale' (Get-PsAiLease -Repo $repo).State 'An old unreadable lease is stale'

    # Several sessions find the same stale lease at once: exactly one takes it.
    $stale = @{ tool = 'codex'; account = 'dead'; pid = 99999999; host = [System.Net.Dns]::GetHostName(); startedAt = '2026-11-18T09:00:00Z' }
    [System.IO.File]::WriteAllText($leasePath, ($stale | ConvertTo-Json -Compress))
    $runner = Join-Path $tempRoot 'runner.ps1'
    @'
param($LeaseScript, $Repo, $Account)
& $LeaseScript -Action take -Repo $Repo -Tool codex -Account $Account -ProcessId $PID
$result = $LASTEXITCODE
Start-Sleep -Seconds 3
exit $result
'@ | Set-Content -LiteralPath $runner
    $processes = 1..5 | ForEach-Object {
        $arguments = @('-NoProfile', '-File', "`"$runner`"", "`"$script`"", "`"$repo`"", "racer$_")
        Start-Process pwsh -ArgumentList $arguments -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $tempRoot "racer$_.out") -RedirectStandardError (Join-Path $tempRoot "racer$_.err")
    }
    $processes | Wait-Process
    $winners = @($processes | Where-Object ExitCode -eq 0)
    Assert-Equal 1 $winners.Count 'Exactly one session replaces a stale lease'
    Assert-True (-not (Test-Path -LiteralPath "$leasePath.takeover")) 'Takeover guard is removed'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
