param([string]$Finding)
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
$savedStatusBin = $env:PS_AI_STATUS_BIN
try {
    $lines = @(& pwsh -NoProfile -File $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-Equal 0 $LASTEXITCODE 'Status without settings exits zero'
    Assert-True ($lines -contains 'no ps-ai settings yet') 'No-settings explanation'
    Assert-True ($lines -contains 'repo none') 'No orchestration reports repo none'

    . $statusScript -NoRun -HomeRoot $fixtureHome -Repo $repo
    $bin = Join-Path $fixtureHome '.legion/bin'
    if (-not $Finding -or $Finding -eq 'R4B5') {
        & {
            $permissionBin = Join-Path $scratch 'permission-bin'
            New-Item -ItemType Directory -Path $permissionBin -Force | Out-Null
            foreach ($entry in (Get-PsAiOwnerCommands).GetEnumerator()) {
                foreach ($suffix in $(if ($IsWindows) { @('', '.cmd') } else { @('') })) {
                    Get-PsAiShimText -Script (Join-Path $root "plugins/ps-ai/bin/$($entry.Value)") -Windows:([bool]$suffix) |
                        Set-Content -LiteralPath (Join-Path $permissionBin "$($entry.Key)$suffix")
                    if (-not $IsWindows -and $entry.Key -ne 'legion') {
                        $path = Join-Path $permissionBin $entry.Key
                        [IO.File]::SetUnixFileMode($path, ([IO.File]::GetUnixFileMode($path) -bor [IO.UnixFileMode]::UserExecute))
                    }
                }
            }
            if ($IsWindows) {
                function Test-PsAiLauncherExecutable { param($Path) return ((Split-Path $Path -Leaf) -ne 'legion') }
            }
            $lines = @(Write-StatusCommands -Bin $permissionBin)
            Assert-True ($lines -contains 'commands: not executable legion') 'R4 B5 status names a command needing execute permission'
            Assert-True ($lines -notcontains 'commands: yes') 'R4 B5 nonexecutable commands are not ready'
        }
    }
    if (-not $Finding -or $Finding -eq 'G3') {
        & {
            $originalWindows = $IsWindows
            try {
                Set-Variable IsWindows -Value $false -Force
                $env:PS_AI_STATUS_BIN = $bin
                Assert-Equal $false (Test-PsAiPathEntry -Path '%PS_AI_STATUS_BIN%' -Folder $bin) 'G3 Unix PATH entries keep literal percent variables'
            } finally { Set-Variable IsWindows -Value $originalWindows -Force }
        }
    }
    if (-not $Finding -or $Finding -eq 'E2') {
        $probeRepo = Join-Path $scratch 'scratch-only-repo'
        $probeLegion = Join-Path $probeRepo '.legion'
        New-Item -ItemType Directory -Path (Join-Path $probeLegion 'temp') -Force | Out-Null
        Assert-Equal 'repo none' (Write-StatusRepository -Repo $probeRepo) 'E2 scratch-only legion folder is not Shared setup'
        foreach ($file in @('configuration/project.json', 'configuration/workflow.md', 'scripts/index.md')) {
            $path = Join-Path $probeLegion $file
            New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
            'fixture' | Set-Content -LiteralPath $path
        }
        Assert-Equal 'repo none' (Write-StatusRepository -Repo $probeRepo) 'G3 untracked scaffold is not Shared setup'
        $git = (Get-Command git -CommandType Application | Select-Object -First 1).Source
        & $git -C $probeRepo init --quiet
        & $git -C $probeRepo add -- .legion/configuration/project.json .legion/configuration/workflow.md .legion/scripts/index.md
        Assert-True ((Write-StatusRepository -Repo $probeRepo) -match '^repo Shared') 'G3 tracked scaffold identifies Shared setup without a handoff'
        & $git -C $probeRepo rm --cached --quiet -- .legion/scripts/index.md
        Assert-Equal 'repo none' (Write-StatusRepository -Repo $probeRepo) 'G3 every required scaffold path must be tracked'
        & $git -C $probeRepo add -- .legion/scripts/index.md
        foreach ($file in @('configuration/project.json', 'configuration/workflow.md', 'scripts/index.md')) {
            $path = Join-Path $probeLegion $file
            Remove-Item -LiteralPath $path
            Assert-Equal 'repo none' (Write-StatusRepository -Repo $probeRepo) 'E2 incomplete Shared scaffold is not setup'
            'fixture' | Set-Content -LiteralPath $path
        }
        & $git -C $probeLegion init --quiet
        Assert-Equal 'repo none' (Write-StatusRepository -Repo $probeRepo) 'G3 untracked Private scaffold is not setup'
        & $git -C $probeLegion add -- configuration/project.json configuration/workflow.md scripts/index.md
        Assert-True ((Write-StatusRepository -Repo $probeRepo) -match '^repo Private') 'G3 Private scaffold uses its inner tracking history'
        $global:LASTEXITCODE = 7
        Write-StatusRepository -Repo $probeRepo | Out-Null
        Assert-Equal 7 $LASTEXITCODE 'G3 status preserves the caller native exit status'
    }
    if (-not $Finding -or $Finding -eq 'E3') {
        $env:PS_AI_STATUS_BIN = $bin
        $env:PATH = '%PS_AI_STATUS_BIN%'
        Assert-Equal ([bool]$IsWindows) (Test-PsAiPathEntry -Path $env:PATH -Folder $bin) 'E3 only Windows expands percent environment variables in PATH entries'
        $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
        $expectedPath = if ($IsWindows) { 'yes' } else { 'no' }
        Assert-True ($lines -match "on PATH: $expectedPath") 'E3 status uses the shared platform PATH test'
        $needsPath = & {
            . (Join-Path $root 'plugins/ps-ai/bin/ps-ai-setup.ps1') -NoRun
            function Get-SetupUserPath { return $env:PATH }
            (Get-SetupPlan -HomeRoot $fixtureHome).NeedsPath
        }
        Assert-Equal (-not $IsWindows) $needsPath 'E3 setup uses the same platform PATH test as status'
    }
    if ($Finding) { return }
    $env:PATH = $bin
    Assert-True (Test-PsAiPathEntry -Path $env:PATH -Folder $bin) 'Exact PATH entry'
    $env:PATH = $bin + [IO.Path]::DirectorySeparatorChar
    Assert-True (Test-PsAiPathEntry -Path $env:PATH -Folder $bin) 'Trailing separator in PATH'
    $env:PATH = $bin
    Assert-True (Test-PsAiPathEntry -Path $env:PATH -Folder ($bin + [IO.Path]::DirectorySeparatorChar)) 'Trailing separator in folder'
    $env:PATH = $bin + '-other'
    Assert-Equal $false (Test-PsAiPathEntry -Path $env:PATH -Folder $bin) 'PATH prefixes are not exact entries'
    $env:PATH = $bin.ToUpperInvariant()
    Assert-Equal ([bool]$IsWindows) (Test-PsAiPathEntry -Path $env:PATH -Folder $bin) 'PATH case follows the platform'

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
        if (-not $IsWindows) {
            $path = Join-Path $bin $name
            [IO.File]::SetUnixFileMode($path, ([IO.File]::GetUnixFileMode($path) -bor [IO.UnixFileMode]::UserExecute))
        }
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
            (Get-PsAiShimText -Script $fakeTool) |
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

    # Only the read-only Git tracking probe is allowed; no CLI or agent can launch.
    function Start-Process { throw 'Status must not start a process' }
    function git {
        Assert-True ($args -contains 'ls-files') 'Status only asks Git about tracked scaffold files'
        $global:LASTEXITCODE = 0
    }
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

    # C-2: an owned command whose script is gone is stale, and status does not call it ready.
    foreach ($name in @('legion', 'legion.cmd')) {
        $path = Join-Path $bin $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path }
    }
    (Get-PsAiShimText -Script (Join-Path $scratch 'gone/bin/legion.ps1')) | Set-Content -LiteralPath (Join-Path $bin 'legion')
    if ($IsWindows) { (Get-PsAiShimText -Script (Join-Path $scratch 'gone/bin/legion.ps1') -Windows) | Set-Content -LiteralPath (Join-Path $bin 'legion.cmd') }
    $lines = @(& $statusScript -HomeRoot $fixtureHome -Repo $repo)
    Assert-True ($lines -contains 'commands: stale legion') 'A command whose script is gone is stale'
    Assert-True ($lines -notcontains 'commands: yes') 'A stale command is not ready'
    $legion = Join-Path $repo '.legion'
    New-Item -ItemType Directory -Path (Join-Path $legion 'state'), (Join-Path $legion 'temp') -Force | Out-Null
    foreach ($file in @('configuration/project.json', 'configuration/workflow.md', 'scripts/index.md')) {
        $path = Join-Path $legion $file
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        'fixture' | Set-Content -LiteralPath $path
    }
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
    $env:PS_AI_STATUS_BIN = $savedStatusBin
}
