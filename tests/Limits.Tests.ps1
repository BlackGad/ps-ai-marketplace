. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'FakeAz.ps1')
$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/legion/bin/legion-limits.ps1'
$fixtures = Join-Path $PSScriptRoot 'fixtures/limits'
. (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
$scratch = Join-Path ([IO.Path]::GetTempPath()) ('legion-limits-test-' + [guid]::NewGuid().ToString('N'))
$home1 = Join-Path $scratch 'home'
$fakeBin = Join-Path $scratch 'bin'
$log = Join-Path $scratch 'call.json'
New-Item -ItemType Directory -Path (Join-Path $home1 '.legion/configuration'), $fakeBin -Force | Out-Null

# The three fake CLIs all run the one fixture script.
foreach ($name in @('claude', 'codex', 'copilot')) {
    New-TestCommandStub -Folder $fakeBin -Name $name -Script (Join-Path $fixtures 'fake-cli.ps1') | Out-Null
}
$agents = @(
    @{ id = 'claude-a'; tool = 'claude'; configDir = '~/.legion/agents/claude-a' }
    @{ id = 'codex-a'; tool = 'codex'; configDir = '~/.legion/agents/codex-a' }
    @{ id = 'copilot-a'; tool = 'copilot'; configDir = '~/.legion/agents/copilot-a' }
    @{ id = 'foundry-a'; tool = 'claude'; configDir = '~/.legion/agents/foundry-a'; provider = @{ kind = 'foundry' } }
)
foreach ($agent in $agents) {
    if ($agent.provider) { continue }
    $target = Join-Path $fakeBin $(if ($IsWindows) { "$($agent.tool).cmd" } else { $agent.tool })
    New-LegionWrappers -Id $agent.id -Tool $agent.tool -HomeRoot $home1 -ConfigDir $agent.configDir -RealCommand $target | Out-Null
}
Write-TestPersonalisation -HomeRoot $home1 -Agents $agents | Out-Null

function Get-Fixture { param([string]$Name) return Join-Path $fixtures $Name }
function Get-Time { param([long]$Seconds) return [DateTimeOffset]::FromUnixTimeSeconds($Seconds).ToLocalTime().ToString('yyyy-MM-dd HH:mm') }

# Runs the limits script for one account with the fake CLI behaving as the settings say.
function Invoke-Limits {
    param([string]$Account, [hashtable]$Fake = @{}, [int]$TimeoutSeconds = 60)
    foreach ($name in @('STDOUT', 'STDERR', 'EXIT', 'SESSION', 'SLEEP', 'CONCURRENT')) { Remove-Item "Env:LEGION_FAKE_$name" -ErrorAction SilentlyContinue }
    foreach ($key in $Fake.Keys) { Set-Item "Env:LEGION_FAKE_$key" -Value $Fake[$key] }
    Remove-Item -LiteralPath $log -ErrorAction SilentlyContinue
    return @(& $script -Account $Account -HomeRoot $home1 -TimeoutSeconds $TimeoutSeconds)
}

$savedPath = $env:PATH
$env:LEGION_FAKE_LOG = $log
$env:PATH = $fakeBin + [IO.Path]::PathSeparator + $env:PATH
try {
    # Claude: both windows from the rate_limit_event, stdin closed, the account's folder in CLAUDE_CONFIG_DIR.
    $lines = Invoke-Limits -Account 'claude-a' -Fake @{ STDOUT = (Get-Fixture 'claude-stream.jsonl') }
    Assert-True (($lines -join "`n") -match "claude-a\s+claude\s+five_hour\s+69%\s+$([regex]::Escape((Get-Time 1795350000)))\s+allowed") 'Claude five_hour row'
    Assert-True (($lines -join "`n") -match "seven_day\s+55%\s+$([regex]::Escape((Get-Time 1795654800)))\s+allowed") 'Claude seven_day row'
    $call = Get-Content -LiteralPath $log -Raw | ConvertFrom-Json
    Assert-Equal '-p --output-format stream-json --verbose ping' ($call.arguments -join ' ') 'Claude ping arguments'
    Assert-Equal '' $call.stdin 'Claude ping closes stdin'
    Assert-Equal (Join-Path $home1 '.legion/agents/claude-a') $call.claude 'Claude ping uses the account folder'
    Assert-True ((Split-Path $call.folder -Leaf) -like 'legion-limits-*') 'Claude pings from a disposable folder, away from any project'
    Assert-True (-not (Test-Path -LiteralPath $call.folder)) 'Claude disposable folder is removed'

    $lines = Invoke-Limits -Account 'claude-a' -Fake @{ STDOUT = (Get-Fixture 'claude-no-event.jsonl') }
    Assert-True (($lines -join "`n") -match 'claude-a\s+claude\s+-\s+unknown\s+unknown\s+no limit readout') 'Claude without an event is unknown'

    # Codex: only the probe's session, identified by its fresh git folder.
    $lines = Invoke-Limits -Account 'codex-a' -Fake @{ SESSION = (Get-Fixture 'codex-session.jsonl'); CONCURRENT='1' }
    Assert-True (($lines -join "`n") -match "codex-a\s+codex\s+5h\s+12%\s+$([regex]::Escape((Get-Time 1795350000)))\s+unknown") 'Codex primary row has usage without an invented status'
    Assert-True (($lines -join "`n") -match "7d\s+40%\s+$([regex]::Escape((Get-Time 1795654800)))\s+unknown") 'Codex secondary row'
    $call = Get-Content -LiteralPath $log -Raw | ConvertFrom-Json
    Assert-Equal 'exec ping' ($call.arguments -join ' ') 'Codex ping arguments'
    Assert-Equal '' $call.stdin 'Codex ping closes stdin'
    Assert-True ((Split-Path $call.folder -Leaf) -like 'legion-limits-*') 'Codex pings from a disposable folder'
    Assert-True (-not (Test-Path -LiteralPath $call.folder)) 'Codex disposable folder is removed'
    Assert-Equal (Join-Path $home1 '.legion/agents/codex-a') $call.codex 'Codex ping uses the account CODEX_HOME'

    $lines = Invoke-Limits -Account 'codex-a' -Fake @{ SESSION = (Get-Fixture 'codex-session-null.jsonl') }
    Assert-True (($lines -join "`n") -match 'codex-a\s+codex\s+-\s+unknown\s+unknown\s+no limit readout') 'Codex null windows are unknown'

    $lines = Invoke-Limits -Account 'codex-a' -Fake @{ STDERR = (Get-Fixture 'codex-quota.txt'); EXIT = '1' }
    Assert-True (($lines -join "`n") -match 'codex-a\s+codex\s+-\s+unknown\s+2:57 PM\s+limit reached') 'Codex quota error is limit reached with its retry time'

    # Copilot has no readout: a normal answer is only "answers", a quota error is the limit, anything else is a failure.
    $lines = Invoke-Limits -Account 'copilot-a'
    Assert-True (($lines -join "`n") -match 'copilot-a\s+copilot\s+-\s+unknown\s+unknown\s+answers; no limit readout') 'Copilot answer shows no percentages'
    $call = Get-Content -LiteralPath $log -Raw | ConvertFrom-Json
    Assert-Equal '-p ping -s' ($call.arguments -join ' ') 'Copilot ping arguments'
    Assert-True ((Split-Path $call.folder -Leaf) -like 'legion-limits-*') 'Copilot pings from a disposable folder, away from any project'
    Assert-True (-not (Test-Path -LiteralPath $call.folder)) 'Copilot disposable folder is removed'
    $lines = Invoke-Limits -Account 'copilot-a' -Fake @{ STDERR = (Get-Fixture 'copilot-quota.txt'); EXIT = '1' }
    Assert-True (($lines -join "`n") -match 'copilot-a\s+copilot\s+-\s+unknown\s+unknown\s+limit reached') 'Copilot quota error is limit reached'
    $lines = Invoke-Limits -Account 'copilot-a' -Fake @{ STDERR = (Get-Fixture 'codex-session-null.jsonl'); EXIT = '1' }
    Assert-True (($lines -join "`n") -match 'copilot-a\s+copilot\s+-\s+unknown\s+unknown\s+ping failed') 'A plain failure is not a limit'

    # A ping that never ends is stopped.
    $lines = Invoke-Limits -Account 'copilot-a' -Fake @{ SLEEP = '20' } -TimeoutSeconds 2
    Assert-True (($lines -join "`n") -match 'ping timed out') 'Slow ping times out'

    # Foundry accounts report the Azure token check.
    $tokenKey = 'account get-access-token --resource https://cognitiveservices.azure.com'
    Use-FakeAz -Answers @{ $tokenKey = @{ exit = 0; stdout = '{"accessToken":"fake-token","expiresOn":"2026-11-18T18:30:00+00:00"}' } }
    $lines = Invoke-Limits -Account 'foundry-a'
    Assert-True (($lines -join "`n") -match 'foundry-a\s+claude\s+-\s+-\s+-\s+token ok') 'Foundry token ok'
    Assert-True (($lines -join "`n") -notmatch 'fake-token') 'Foundry output never shows the token'
    Use-FakeAz -Answers @{ $tokenKey = @{ exit = 1; stdout = '' } }
    $lines = Invoke-Limits -Account 'foundry-a'
    Assert-True (($lines -join "`n") -notmatch 'token ok') 'Foundry token failure is not ok'

    # Without -Account every account is listed; an unknown account is an error.
    $lines = @(& $script -HomeRoot $home1 -TimeoutSeconds 60)
    foreach ($id in @('claude-a', 'codex-a', 'copilot-a', 'foundry-a')) { Assert-True (($lines -join "`n") -match $id) "All accounts list $id" }
    Assert-Throws { & $script -Account 'nobody' -HomeRoot $home1 } 'Unknown account is an error'
    try { & $script 'claude-a' 'codex-a' -HomeRoot $home1; throw 'Expected a second account name to fail' }
    catch { Assert-True ($_.Exception.Message -match 'positional parameter') 'A second account name is a clear argument error' }

    # The owner command passes the account along.
    . (Join-Path $root 'plugins/legion/bin/legion.ps1') -HomeRoot $home1
    $call = Get-LegionCall -Words @('limits', 'claude-a')
    Assert-Equal 'legion-limits.ps1' $call.Script 'limits script'
    Assert-Equal 'claude-a' $call.Splat.Account 'limits passes the account'
    Assert-True (-not (Get-LegionCall -Words @('limits')).Splat.ContainsKey('Account')) 'limits without an account lists all'
    Assert-Throws { Get-LegionCall -Words @('limits', 'a', 'b') } 'limits takes at most one account'
    Assert-True ((Get-LegionHelp) -match 'legion limits') 'help lists limits'
} finally {
    $env:PATH = $savedPath
    foreach ($name in @('LOG', 'STDOUT', 'STDERR', 'EXIT', 'SESSION', 'SLEEP', 'CONCURRENT')) { Remove-Item "Env:LEGION_FAKE_$name" -ErrorAction SilentlyContinue }
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
