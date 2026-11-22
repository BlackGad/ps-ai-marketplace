param([string]$Case)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
. (Join-Path $root 'plugins/legion/bin/lib/limits.ps1')
$scratch = Join-Path $root ('.agents/temp/limits-regression-' + [guid]::NewGuid().ToString('N'))
$savedPath = $env:PATH
$savedLog = $env:LEGION_FAKE_LOG
$savedSession = $env:LEGION_FAKE_SESSION
$fixtures = Join-Path $PSScriptRoot 'fixtures/limits'
try {
    New-Item -ItemType Directory -Path $scratch -Force | Out-Null
    if (-not $Case -or $Case -eq 'launcher') {
        $stock = Join-Path $scratch $(if ($IsWindows) { 'claude.cmd' } else { 'claude' })
        [IO.File]::WriteAllText($stock, $(if ($IsWindows) { '@exit /b 99' } else { "#!/bin/sh`nexit 99`n" }))
        if (-not $IsWindows) { [IO.File]::SetUnixFileMode($stock, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserExecute) }
        $env:PATH = $scratch + [IO.Path]::PathSeparator + $env:PATH
        $target = Join-Path $fixtures 'fake-cli.ps1'
        New-LegionWrappers -Id 'custom-a' -Tool claude -HomeRoot $scratch -RealCommand $target | Out-Null
        $env:LEGION_FAKE_LOG = Join-Path $scratch 'call.json'
        $env:LEGION_FAKE_STDOUT = Join-Path $fixtures 'claude-stream.jsonl'
        $agent = @{ id='custom-a'; tool='claude'; configDir='~/.legion/agents/custom-a' }
        $rows = @(Get-LegionAccountLimits -Agent $agent -HomeRoot $scratch -TimeoutSeconds 30)
        Assert-Equal '69%' $rows[0].Used 'Limits runs the registered account launcher instead of the stock CLI'
        $call = Get-Content -LiteralPath $env:LEGION_FAKE_LOG -Raw | ConvertFrom-Json
        Assert-Equal (Join-Path $scratch '.legion/agents/custom-a') $call.claude 'The launcher selects the account folder'
        Remove-Item -LiteralPath (Get-LegionWrapperCommand 'custom-a' $scratch)
        $rows = @(Get-LegionAccountLimits -Agent $agent -HomeRoot $scratch -TimeoutSeconds 30)
        Assert-Equal 'launcher missing; run legion setup' $rows[0].Status 'Missing launcher requests setup'
    }
    if (-not $Case -or $Case -in @('failed', 'timeout', 'concurrent')) {
        $folder = Join-Path $scratch 'codex'
        $sessions = Join-Path $folder 'sessions'
        New-Item -ItemType Directory -Path $sessions -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $fixtures 'codex-session.jsonl') -Destination (Join-Path $sessions 'old.jsonl')
        function Invoke-LegionProcess {
            param($Command, $Arguments, $WorkingDirectory)
            if ($Case -eq 'concurrent') {
                $other = Join-Path $sessions 'other.jsonl'
                Copy-Item -LiteralPath (Join-Path $fixtures 'codex-session.jsonl') -Destination $other
            }
            return @{ ExitCode=$(if ($Case -eq 'failed') { 1 } elseif ($Case -eq 'timeout') { -1 } else { 0 });
                Output=''; Error='probe failed'; TimedOut=($Case -eq 'timeout') }
        }
        foreach ($scenario in $(if ($Case) { @($Case) } else { @('failed','timeout','concurrent') })) {
            $Case = $scenario
            $rows = @(& (Join-Path $root 'plugins/legion/skills/legion-codex/scripts/limits.ps1') -Command 'unused' -Folder $folder -TimeoutSeconds 1)
            $expected = switch ($Case) { failed { 'ping failed: probe failed' } timeout { 'ping timed out' } concurrent { 'no limit readout' } }
            Assert-Equal $expected $rows[0].Status "Codex $Case does not reuse unrelated session windows"
            Assert-Equal 'unknown' $rows[0].Used "Codex $Case does not reuse old percentages"
        }
    }
} finally {
    $env:PATH = $savedPath
    $env:LEGION_FAKE_LOG = $savedLog
    $env:LEGION_FAKE_SESSION = $savedSession
    Remove-Item Env:LEGION_FAKE_STDOUT -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
