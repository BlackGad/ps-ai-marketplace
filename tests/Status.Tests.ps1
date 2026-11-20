$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$statusScript = Join-Path $root 'plugins/ps-ai/bin/ps-ai-status.ps1'
Assert-True (Test-Path -LiteralPath $statusScript) 'Status script exists'
$scratch = Join-Path $root ('.agents/temp/status-' + [guid]::NewGuid().ToString('N'))
$fixtureHome = Join-Path $scratch 'home'
$repo = Join-Path $scratch 'repo'
New-Item -ItemType Directory -Path $fixtureHome, $repo -Force | Out-Null
$savedPath = $env:PATH
$savedLog = $env:PS_AI_FAKE_TOOL_LOG
try {
    $lines = @(& pwsh -NoProfile -File $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-Equal 0 $LASTEXITCODE 'Status without settings exits zero'
    Assert-True ($lines -contains 'no ps-ai settings yet') 'No-settings explanation'
    Assert-True ($lines -contains 'repo none') 'No orchestration reports repo none'

    . $statusScript -NoRun -HomeRoot $fixtureHome -Repo $repo
    $bin = Join-Path $fixtureHome '.legion/bin'
    $env:PATH = $bin
    Assert-True (Test-StatusPathEntry -Folder $bin) 'Exact PATH entry'
    $env:PATH = $bin + [IO.Path]::DirectorySeparatorChar
    Assert-True (Test-StatusPathEntry -Folder $bin) 'Trailing separator in PATH'
    $env:PATH = $bin
    Assert-True (Test-StatusPathEntry -Folder ($bin + [IO.Path]::DirectorySeparatorChar)) 'Trailing separator in folder'
    $env:PATH = $bin + '-other'
    Assert-Equal $false (Test-StatusPathEntry -Folder $bin) 'PATH prefixes are not exact entries'
    $env:PATH = $bin.ToUpperInvariant()
    Assert-Equal ([bool]$IsWindows) (Test-StatusPathEntry -Folder $bin) 'PATH case follows the platform'

    $config = Join-Path $fixtureHome '.legion/configuration'
    $manifest = Join-Path $fixtureHome '.claude/plugins/cache/ps-ai-marketplace/ps-ai/0.6.0/plugin.json'
    New-Item -ItemType Directory -Path $config, $bin, (Split-Path $manifest) -Force | Out-Null
    '{"name":"ps-ai","version":"0.6.0"}' | Set-Content -LiteralPath $manifest
    @{
        schemaVersion = 1
        agents = @(
            @{ id = 'claude-a'; tool = 'claude'; configDir = '~/.claude' },
            @{ id = 'codex-a'; tool = 'codex'; configDir = '~/.codex-work' }
        )
        channels = @(@{ id = 'my-telegram'; kind = 'telegram'; target = '123'; accounts = @('claude-a') })
    } | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $config 'ps-ai-personalisation.json')
    $commands = Get-PsAiOwnerCommands
    foreach ($name in $commands.Keys) {
        (Get-PsAiShimText -Script (Join-Path $root "plugins/ps-ai/bin/$($commands[$name])")) |
            Set-Content -LiteralPath (Join-Path $bin $name)
        if ($IsWindows) {
            (Get-PsAiShimText -Script (Join-Path $root "plugins/ps-ai/bin/$($commands[$name])") -Windows) |
                Set-Content -LiteralPath (Join-Path $bin "$name.cmd")
        }
    }

    $fakeBin = Join-Path $scratch 'fake-bin'
    New-Item -ItemType Directory -Path $fakeBin -Force | Out-Null
    $fakeTool = Join-Path $PSScriptRoot 'fixtures/fake-tools/Invoke-FakeTool.ps1'
    $env:PS_AI_FAKE_TOOL_LOG = Join-Path $scratch 'cli-calls.json'
    foreach ($name in @('claude', 'codex', 'copilot')) {
        if ($IsWindows) {
            "@pwsh -NoProfile -File `"$fakeTool`" %*" | Set-Content -LiteralPath (Join-Path $fakeBin "$name.cmd")
        } else {
            ("#!/bin/sh`nexec pwsh -NoProfile -File " + (ConvertTo-PsAiShellLiteral $fakeTool) + ' "$@"') |
                Set-Content -LiteralPath (Join-Path $fakeBin $name)
            & chmod +x (Join-Path $fakeBin $name)
        }
    }
    $env:PATH = $fakeBin + [IO.Path]::PathSeparator + $bin + [IO.Path]::PathSeparator + $savedPath
    $before = @(Get-ChildItem -LiteralPath $fixtureHome -File -Recurse | Sort-Object FullName | ForEach-Object {
        $_.FullName + ':' + $_.LastWriteTimeUtc.Ticks + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join '|'
    $lines = @(& pwsh -NoProfile -File $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-Equal 0 $LASTEXITCODE 'Configured status exits zero'
    Assert-True ($lines -match 'claude-a\s+claude\s+.*ps-ai 0\.6\.0') 'Account with installed ps-ai'
    Assert-True ($lines -match 'codex-a\s+codex\s+.*ps-ai missing') 'Account missing ps-ai'
    Assert-True ($lines -match 'on PATH: yes') 'PATH yes output'
    Assert-True ($lines -contains 'commands: yes') 'All owner commands recognized'
    Assert-True ($lines -match 'my-telegram \(telegram\) -> claude-a') 'Channel binding output'
    $after = @(Get-ChildItem -LiteralPath $fixtureHome -File -Recurse | Sort-Object FullName | ForEach-Object {
        $_.FullName + ':' + $_.LastWriteTimeUtc.Ticks + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash
    }) -join '|'
    Assert-Equal $before $after 'Status preserves home files and modification times'
    Assert-Equal $false (Test-Path -LiteralPath $env:PS_AI_FAKE_TOOL_LOG) 'Status never starts the fake CLIs'

    # In-process probes forbid every process launch, including git, for repo and command status.
    function Start-Process { throw 'Status must not start a process' }
    function git { throw 'Status must not start git' }
    function pwsh { throw 'Status must not start pwsh' }
    $env:PATH = $fakeBin
    $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-True ($lines -match 'on PATH: no') 'PATH no output'
    foreach ($name in @('legion', 'legion.cmd')) {
        $path = Join-Path $bin $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-True ($lines -contains 'commands: missing legion') 'Missing owner command named'
    'owner command' | Set-Content -LiteralPath (Join-Path $bin 'legion')
    $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-True ($lines -contains 'commands: blocked legion') 'Unrelated legion command is blocked'
    if ($IsWindows) {
        (Get-PsAiShimText -Script (Join-Path $root 'plugins/ps-ai/bin/legion.ps1') -Windows) |
            Set-Content -LiteralPath (Join-Path $bin 'legion.cmd')
        $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
        Assert-True ($lines -contains 'commands: blocked legion') 'Conflicting extensionless file remains blocked beside a valid cmd shim'
    }

    $legion = Join-Path $repo '.legion'
    New-Item -ItemType Directory -Path (Join-Path $legion 'state'), (Join-Path $legion 'temp') -Force | Out-Null
    'handoff fixture' | Set-Content -LiteralPath (Join-Path $legion 'state/handoff.md')
    $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-True ($lines -match '^repo\s+Shared\s+lease: free\s+handoff: yes$') 'Shared repo and free lease'
    New-Item -ItemType Directory -Path (Join-Path $legion '.git') -Force | Out-Null
    $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-True ($lines -match '^repo\s+Private\s+lease: free\s+handoff: yes$') 'Private repo'
    $process = Get-Process -Id $PID
    @{ host = [Net.Dns]::GetHostName(); pid = $PID; processStartedAt = $process.StartTime.ToUniversalTime().ToString('o') } |
        ConvertTo-Json | Set-Content -LiteralPath (Join-Path $legion 'temp/overseer.lock')
    $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-True ($lines -match '^repo\s+Private\s+lease: held\s+handoff: yes$') 'Held lease shown without taking it'
    Assert-Equal $false (Test-Path -LiteralPath $env:PS_AI_FAKE_TOOL_LOG) 'No CLI was called by any status probe'
} finally {
    $env:PATH = $savedPath
    $env:PS_AI_FAKE_TOOL_LOG = $savedLog
}
