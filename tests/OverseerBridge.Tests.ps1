$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/legion/bin/legion-overseer.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('overseer-bridge-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tempRoot -Force | Out-Null
. $script -NoRun -HomeRoot $tempRoot

$owner = [pscustomobject]@{schemaVersion=1;agents=@(
    @{id='claude-a';tool='claude';configDir='~/a'},
    @{id='codex-a';tool='codex';configDir='~/c'}
);channels=@(
    @{id='main';kind='telegram';target='123';accounts=@('claude-a','codex-a')}
)}
$repoPath = Join-Path $tempRoot 'my project'
New-Item -ItemType Directory $repoPath -Force | Out-Null
$botFolder = Get-LegionHomePath -HomeRoot $tempRoot -Path 'channels/telegram/main'
New-Item -ItemType Directory $botFolder -Force | Out-Null

# A fake uv: a sleeping pwsh stands in for the bridge.
function Get-LegionPythonCommand {
    param([string[]]$Arguments = @(), [string]$HomeRoot = $HOME)
    $pwsh = (Get-Process -Id $PID).Path
    return @{ Command = $pwsh; Arguments = @('-NoProfile', '-Command', 'Start-Sleep 60') + $Arguments; Environment = @{ UV_PROJECT_ENVIRONMENT = 'fixture-env' } }
}

$launch = Get-OverseerLaunch -Personalisation $owner -AccountId codex-a -Tool codex -Channel @('main') -HomeRoot $tempRoot -Repo $repoPath
Assert-Equal 'continue as the overseer' ($launch.Args -join '|') 'Codex gets no extra channel arguments'
Assert-Equal $botFolder $launch.Environment['TELEGRAM_STATE_DIR'] 'A Codex Telegram launch carries the bot folder'
Assert-Equal 'telegram|bridge|--channel|main|--repo' (($launch.Bridge.Arguments | Select-Object -Skip 3 | Select-Object -First 5) -join '|') 'Codex Telegram launch gets a bridge for the channel'
Assert-Equal $repoPath $launch.Bridge.Arguments[-1] 'The bridge writes into this repository'
Assert-True ($launch.Bridge.ArgumentText.Contains('"' + $repoPath + '"')) 'A repository path with spaces is quoted for Start-Process'
Assert-True ($null -eq (Get-OverseerLaunch -Personalisation $owner -AccountId claude-a -Tool claude -Channel @('main') -HomeRoot $tempRoot -Repo $repoPath).Bridge) 'Claude launch starts no bridge'
Assert-True ($null -eq (Get-OverseerLaunch -Personalisation $owner -AccountId codex-a -Tool codex -HomeRoot $tempRoot -Repo $repoPath).Bridge) 'Codex launch without a channel starts no bridge'
& {
    function Get-LegionPythonCommand { return $null }
    $missing = Get-OverseerLaunch -Personalisation $owner -AccountId codex-a -Tool codex -Channel @('main') -HomeRoot $tempRoot -Repo $repoPath 3>&1
    $warnings = @($missing | Where-Object { $_ -is [Management.Automation.WarningRecord] })
    $missing = @($missing | Where-Object { $_ -isnot [Management.Automation.WarningRecord] })[0]
    Assert-True ($null -eq $missing.Bridge) 'Without uv there is no bridge'
    Assert-True ("$warnings".Contains('uv is missing')) 'Without uv the owner is told'
}

$dry = @(Start-OverseerLaunch -Repo $repoPath -Launch $launch -DryRun -InPlace)
Assert-True (@($dry | Where-Object { "$_" -like 'bridge: * telegram bridge --channel main --repo *' }).Count -eq 1) 'Dry run shows the bridge command'
$plainDry = @(Start-OverseerLaunch -Repo $repoPath -Launch @{Command='codex-fixture';Args=@('x')} -DryRun -InPlace)
Assert-True (@($plainDry | Where-Object { "$_" -like 'bridge:*' }).Count -eq 0) 'Dry run without a bridge shows none'

# The real start and stop, with a sleeping process in place of the bridge.
$started = Start-OverseerBridge -Bridge $launch.Bridge -Repo $repoPath
Assert-True (-not $started.HasExited) 'The bridge starts in the background'
Set-Content -LiteralPath (Join-Path $botFolder 'bridge.pid') -Value $started.Id
Stop-OverseerBridge -Process $started -Bridge $launch.Bridge
$started.WaitForExit(5000) | Out-Null
Assert-True $started.HasExited 'The bridge stops'
Assert-True (-not (Test-Path -LiteralPath (Join-Path $botFolder 'bridge.pid'))) 'Stopping removes the bridge pid file'
Stop-OverseerBridge -Process $null -Bridge $launch.Bridge

# In place: start before the session, stop after it, also when the session fails.
& {
    $state = @{ Events = @() }
    function Start-OverseerBridge { param($Bridge, $Repo) $state.Events += 'start'; return [pscustomobject]@{ Id = 1 } }
    function Stop-OverseerBridge { param($Process, $Bridge) $state.Events += 'stop' }
    function Invoke-OverseerInRepo { param($Repo, $Command, $Arguments, $Environment, $Remove) $state.Events += 'session' }
    Start-OverseerLaunch -Repo $repoPath -Launch $launch -InPlace
    Assert-Equal 'start|session|stop' ($state.Events -join '|') 'An in-place launch starts the bridge, runs the session, then stops the bridge'
    function Invoke-OverseerInRepo { param($Repo, $Command, $Arguments, $Environment, $Remove) throw 'fixture failure' }
    $state.Events = @()
    Assert-Throws { Start-OverseerLaunch -Repo $repoPath -Launch $launch -InPlace } 'A failing session propagates'
    Assert-Equal 'start|stop' ($state.Events -join '|') 'The bridge is stopped when the session fails'
}

if ($IsWindows) {
    & {
        $state = @{Arguments=@()}
        function fixture-terminal { $state.Arguments = @($args) }
        function Get-Command { param($Name, $CommandType, $ErrorAction) @{Source='fixture-terminal'} }
        Start-OverseerLaunch -Repo $repoPath -Launch $launch
        $decoded = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($state.Arguments[-1]))
        $start = $decoded.IndexOf('Start-Process')
        $session = $decoded.IndexOf('try { & ')
        $stop = $decoded.IndexOf('finally {')
        Assert-True ($start -ge 0 -and $start -lt $session -and $session -lt $stop) 'The new tab starts the bridge, runs the session, then stops the bridge'
        Assert-True ($decoded.Contains('telegram bridge --channel main --repo')) 'The new tab starts the bridge for the channel'
        Assert-True ($decoded.Contains('$bridge.Kill($true)') -and $decoded.Contains("bridge.pid'") -and $decoded.EndsWith('exit $code')) 'The new tab stops the bridge and keeps the session exit code'
        $dryTab = @(Start-OverseerLaunch -Repo $repoPath -Launch $launch -DryRun)
        Assert-True (@($dryTab | Where-Object { "$_" -like 'bridge: *' }).Count -eq 1 -and $dryTab -contains 'wt') 'Dry run for the new tab shows the bridge'
        $state.Arguments = @()
        Start-OverseerLaunch -Repo $repoPath -Launch @{Command='codex-fixture';Args=@('x')}
        $plain = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($state.Arguments[-1]))
        Assert-True (-not $plain.Contains('Start-Process')) 'A launch without a bridge starts none in the new tab'
    }
}
Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction Ignore
