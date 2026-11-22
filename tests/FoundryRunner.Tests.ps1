$root = Split-Path $PSScriptRoot -Parent
$runnerScript = Join-Path $root 'plugins/legion/bin/legion-foundry.ps1'
. $runnerScript -NoRun
Assert-True ([bool](Get-Command Get-FoundryLaunch -ErrorAction SilentlyContinue)) 'Foundry launch builder exists'
. (Join-Path $PSScriptRoot 'FakeAz.ps1')
. (Join-Path $PSScriptRoot 'lib/paths.ps1')
$savedEnvironment = @{}
foreach ($name in @('PATH','LEGION_FAKE_AZ','LEGION_FAKE_AZ_LOG','LEGION_FAKE_TOOL_LOG','LEGION_FAKE_TOOL_EXIT','CLAUDE_CODE_USE_BEDROCK','ANTHROPIC_DEFAULT_SONNET_MODEL','CLAUDE_CONFIG_DIR')) {
    $savedEnvironment[$name] = [Environment]::GetEnvironmentVariable($name)
}
$tempRoot = Join-Path (Get-TestTempPath) ('legion-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$fakeRoot = $null
try {
    $homeRoot = Join-Path $tempRoot 'owner with spaces'
    $config = Join-Path $homeRoot '.legion/configuration'
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    $provider = @{kind='foundry';endpoint='https://res-a.cognitiveservices.azure.com';default='claude-opus-x';deployments=@(@{name='claude-opus-x';model='claude-opus-x';alias='opus'},@{name='claude-sonnet-x'})}
    $claudeAgent = [pscustomobject]@{id='claude-dev';tool='claude';configDir='~/.legion/agents/claude-dev';provider=$provider}
    $copilotProvider = @{kind='foundry';endpoint=$provider.endpoint;default=$provider.default;deployments=@(@{name='claude-opus-x';model='claude-opus-x'},@{name='claude-sonnet-x'})}
    $copilotAgent = [pscustomobject]@{id='copilot-dev';tool='copilot';configDir='~/.legion/agents/copilot-dev';provider=$copilotProvider}
    $codexAgent = [pscustomobject]@{id='codex-dev';tool='codex';configDir='~/.legion/agents/codex-dev';provider=@{kind='foundry';endpoint=$provider.endpoint;default='gpt-x';deployments=@(@{name='gpt-x'})}}
    @{agents=@($claudeAgent,$copilotAgent,$codexAgent,@{id='subscription';tool='claude'})} |
        ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $config 'personalisation.json')
    $launch = Get-FoundryLaunch -Agent $claudeAgent -HomeRoot $homeRoot
    foreach ($name in @('ANTHROPIC_FOUNDRY_RESOURCE','ANTHROPIC_FOUNDRY_API_KEY','ANTHROPIC_FOUNDRY_AUTH_TOKEN','ANTHROPIC_SMALL_FAST_MODEL','CLAUDE_CODE_USE_BEDROCK','CLAUDE_CODE_USE_VERTEX','CLAUDE_CODE_USE_ANTHROPIC_AWS','CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD','CLAUDE_CODE_USE_MANTLE','CLAUDE_CODE_USE_GATEWAY')) {
        Assert-True ($launch.Clear -contains $name) "Claude clears $name"
    }
    $codexLaunch = Get-FoundryLaunch -Agent $codexAgent -HomeRoot $homeRoot
    Assert-Equal 'CODEX_HOME' ($codexLaunch.Set.Keys -join '|') 'Codex sets only config home'
    Assert-Equal 0 $codexLaunch.Clear.Count 'Codex clears no variables'
    $tokenKey = 'account get-access-token --resource https://cognitiveservices.azure.com'
    $answers = @{ $tokenKey = @{exit=0;stdout='{"accessToken":"fake-token","expiresOn":"2026-11-18T18:30:00+00:00"}'} }
    Use-FakeAz -Answers $answers
    $fakeRoot = Split-Path $env:LEGION_FAKE_AZ -Parent
    $fakeAzFolder = Join-Path $PSScriptRoot 'fixtures/fake-az'
    $fakeToolsFolder = Join-Path $PSScriptRoot 'fixtures/fake-tools'
    $pwshPath = (Get-Process -Id $PID).Path
    $env:PATH = @($fakeToolsFolder,$fakeAzFolder,$PSHOME,$(if ($IsWindows) { $null } else { "/bin:/usr/bin" })) -join [IO.Path]::PathSeparator
    $env:LEGION_FAKE_TOOL_LOG = Join-Path $tempRoot 'tool.json'
    $env:LEGION_FAKE_TOOL_EXIT = '0'
    $env:CLAUDE_CODE_USE_BEDROCK = '1'
    $env:CLAUDE_CONFIG_DIR = 'parent-config'
    $output = @(& $pwshPath -NoProfile -File $runnerScript -Agent claude-dev -HomeRoot $homeRoot -p hi 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Claude runner succeeds'
    $log = Get-Content -Raw $env:LEGION_FAKE_TOOL_LOG | ConvertFrom-Json
    Assert-Equal '1' $log.environment.CLAUDE_CODE_USE_FOUNDRY 'Claude enables Foundry'
    Assert-Equal 'https://res-a.cognitiveservices.azure.com/anthropic' $log.environment.ANTHROPIC_FOUNDRY_BASE_URL 'Claude endpoint'
    Assert-Equal 'claude-opus-x' $log.environment.ANTHROPIC_MODEL 'Claude default'
    Assert-Equal 'claude-opus-x' $log.environment.ANTHROPIC_DEFAULT_OPUS_MODEL 'Claude opus alias'
    Assert-Equal $null $log.environment.CLAUDE_CODE_USE_BEDROCK 'Claude child clears Bedrock'
    Assert-Equal (Join-Path $homeRoot '.legion/agents/claude-dev') $log.environment.CLAUDE_CONFIG_DIR 'Claude config home'
    Assert-Equal '-p|hi' ($log.arguments -join '|') 'Claude forwards arguments'
    Assert-Equal '1' $env:CLAUDE_CODE_USE_BEDROCK 'Parent Bedrock unchanged'
    Assert-Equal 'parent-config' $env:CLAUDE_CONFIG_DIR 'Parent config unchanged'
    $output = @(& $pwshPath -NoProfile -File $runnerScript -Agent codex-dev -HomeRoot $homeRoot -p 'hi there' 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Codex runner succeeds'
    $log = Get-Content -Raw $env:LEGION_FAKE_TOOL_LOG | ConvertFrom-Json
    Assert-Equal (Join-Path $homeRoot '.legion/agents/codex-dev') $log.environment.CODEX_HOME 'Codex config home'
    Assert-Equal '-p|hi there' ($log.arguments -join '|') 'Argument with space preserved'
    foreach ($exitCode in @(0,3)) {
        $env:LEGION_FAKE_TOOL_EXIT = [string]$exitCode
        $output = @(& $pwshPath -NoProfile -File $runnerScript -Agent copilot-dev -HomeRoot $homeRoot --resume 2>&1)
        Assert-Equal $exitCode $LASTEXITCODE 'Copilot exit code preserved'
        Assert-True (-not (($output -join "`n").Contains('fake-token'))) 'Runner never prints token'
        $expiry = ([DateTimeOffset]'2026-11-18T18:30:00+00:00').ToLocalTime().ToString('HH:mm')
        Assert-True (($output -join "`n").Contains("token valid until $expiry; after that restart with: copilot-dev --resume")) 'Copilot notice uses local expiry'
        $log = Get-Content -Raw $env:LEGION_FAKE_TOOL_LOG | ConvertFrom-Json
        Assert-True $log.providersExisted 'Copilot providers existed during run'
        Assert-True (-not (Test-Path -LiteralPath $log.environment.COPILOT_PROVIDERS_CONFIG)) 'Copilot providers deleted afterwards'
        Assert-Equal (Join-Path $homeRoot '.legion/agents/copilot-dev') $log.environment.COPILOT_HOME 'Copilot config home'
        Assert-Equal (Join-Path $homeRoot '.legion/temp') (Split-Path $log.environment.COPILOT_PROVIDERS_CONFIG -Parent) 'Provider file in per-home temp'
        $providers = $log.providersJson | ConvertFrom-Json
        Assert-Equal 1 $providers.providers.Count 'One Copilot provider'
        Assert-Equal 'legion-foundry' $providers.providers[0].name 'Copilot provider name'
        Assert-Equal 'anthropic' $providers.providers[0].type 'Copilot provider protocol'
        Assert-Equal 'https://res-a.cognitiveservices.azure.com/anthropic' $providers.providers[0].baseUrl 'Copilot endpoint'
        Assert-True ($providers.providers[0].bearerToken -ceq 'fake-token') 'Copilot uses bearer token'
        Assert-Equal '2023-06-01' $providers.providers[0].headers.'anthropic-version' 'Copilot version header'
        Assert-Equal 2 $providers.models.Count 'Copilot includes all deployments'
        Assert-Equal 'claude-sonnet-x' $providers.models[1].modelId 'Unknown model falls back to deployment'
        Assert-Equal 'claude-sonnet-x' $providers.models[1].wireModel 'Copilot wire model is deployment'
        Assert-Equal 'legion-foundry' $providers.models[1].provider 'Copilot model provider'
    }
    Remove-Item -LiteralPath $env:LEGION_FAKE_TOOL_LOG
    Use-FakeAz -Answers @{ $tokenKey = @{exit=1;stdout='fake token denied'}; login = @{exit=0;stdout=''} }
    $output = @(& $pwshPath -NoProfile -File $runnerScript -Agent claude-dev -HomeRoot $homeRoot 2>&1)
    Assert-Equal 1 $LASTEXITCODE 'Token failure exits one'
    Assert-True (($output -join "`n").Contains('fake token denied')) 'Token failure message'
    Assert-True (-not (Test-Path $env:LEGION_FAKE_TOOL_LOG)) 'Token failure starts no tool'
    Assert-Equal 1 @(Get-FakeAzCalls | Where-Object { $_ -eq 'login' }).Count 'Runner retries login once'
    Use-FakeAz -Answers $answers
    $env:PATH = @($fakeAzFolder,$PSHOME) -join [IO.Path]::PathSeparator
    $output = @(& $pwshPath -NoProfile -File $runnerScript -Agent claude-dev -HomeRoot $homeRoot 2>&1)
    Assert-Equal 1 $LASTEXITCODE 'Missing tool exits one'
    Assert-True (($output -join "`n").Contains('claude is not installed; run legion-install-tool.ps1 -Tool claude')) 'Missing tool installer hint'
    foreach ($case in @(@{id='x';error="unknown account 'x'"},@{id='subscription';error="account 'subscription' is not a Foundry agent"})) {
        $output = @(& $pwshPath -NoProfile -File $runnerScript -Agent $case.id -HomeRoot $homeRoot 2>&1)
        Assert-Equal 1 $LASTEXITCODE 'Invalid account exits one'
        Assert-True (($output -join "`n").Contains($case.error)) 'Invalid account message'
    }
    # A wrapper directory on PATH must not be selected as the real tool.
    $bin = Join-Path $homeRoot '.legion/bin'
    New-Item -ItemType Directory -Path $bin -Force | Out-Null
    $bundledRunner = & {
        . (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
        foreach ($id in @('codex','copilot')) { $null = Sync-LegionFoundryRuntime -Tool $id -HomeRoot $homeRoot }
        Sync-LegionFoundryRuntime -Tool claude -HomeRoot $homeRoot
    }
    'throw "wrapper selected as real tool"' | Set-Content -LiteralPath (Join-Path $bin 'claude.ps1')
    $env:PATH = @($bin,$fakeToolsFolder,$fakeAzFolder,$PSHOME) -join [IO.Path]::PathSeparator
    $env:LEGION_FAKE_TOOL_EXIT = '0'
    $output = @(& $pwshPath -NoProfile -File $bundledRunner -Agent claude-dev -HomeRoot $homeRoot -p hi 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Installed runner skips wrappers and loads local helper'
    Assert-True (Test-Path $env:LEGION_FAKE_TOOL_LOG) 'Installed runner starts fake tool'
    # FourthToolLaunchAndStartFailureCleanup: extension uses only the added skill.
    $runtime = Split-Path (Split-Path $bundledRunner -Parent) -Parent
    $fourthSkill = Join-Path $runtime 'skills/legion-fourth'
    Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth') $fourthSkill -Recurse
    $env:PATH = @($bin,$fourthSkill,$fakeToolsFolder,$fakeAzFolder,$PSHOME) -join [IO.Path]::PathSeparator
    'throw "owned wrapper selected"' | Set-Content (Join-Path $bin 'fourth-cli.ps1')
    $file = Join-Path $config 'personalisation.json'
    $data = Get-Content $file -Raw | ConvertFrom-Json
    $data.agents += @([pscustomobject]@{id='fourth-dev';tool='fourth';configDir='~/.legion/agents/fourth-dev';provider=$provider})
    $data | ConvertTo-Json -Depth 100 | Set-Content $file
    $output = @(& $pwshPath -NoProfile -File $bundledRunner -Agent fourth-dev -HomeRoot $homeRoot --flag 'space value' 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Fourth runner resolves descriptor executable rather than id'
    $log = Get-Content $env:LEGION_FAKE_TOOL_LOG -Raw | ConvertFrom-Json
    Assert-Equal (Join-Path $homeRoot '.legion/agents/fourth-dev') $log.config 'Fourth adapter sets child config home'
    Assert-Equal '--flag|space value' ($log.arguments -join '|') 'Fourth runner preserves argument boundaries'
    $descriptorPath = Join-Path $fourthSkill 'tool.json'
    $descriptor = Get-Content $descriptorPath -Raw | ConvertFrom-Json
    $descriptor.foundry = $null
    $descriptor | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
    foreach ($tool in @('fourth','missing')) {
        $data.agents[-1].tool = $tool
        $data | ConvertTo-Json -Depth 100 | Set-Content $file
        $calls = @(Get-FakeAzCalls).Count
        if (Test-Path $env:LEGION_FAKE_TOOL_LOG) { Remove-Item $env:LEGION_FAKE_TOOL_LOG }
        $output = @(& $pwshPath -NoProfile -File $bundledRunner -Agent fourth-dev -HomeRoot $homeRoot 2>&1)
        Assert-Equal 1 $LASTEXITCODE 'Unsupported capability exits one'
        Assert-Equal $calls @(Get-FakeAzCalls).Count 'Unsupported capability stops before Azure'
        Assert-True (-not (Test-Path $env:LEGION_FAKE_TOOL_LOG)) 'Unsupported capability starts no tool'
        Assert-Equal 0 @(Get-ChildItem (Join-Path $homeRoot '.legion/temp') -Filter '*providers*' -ErrorAction SilentlyContinue).Count 'Unsupported capability creates no provider file'
    }
    # An invalid executable fails Process.Start after provider JSON has been written.
    $brokenName = if ($IsWindows) { 'broken-child.exe' } else { 'broken-child' }
    $brokenPath = Join-Path $tempRoot $brokenName
    [IO.File]::WriteAllBytes($brokenPath, [byte[]]@(0,1,2,3))
    if (-not $IsWindows) { [IO.File]::SetUnixFileMode($brokenPath, [IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite -bor [IO.UnixFileMode]::UserExecute) }
    $copilotDescriptorPath = Join-Path $runtime 'skills/legion-copilot/tool.json'
    $copilotDescriptor = Get-Content $copilotDescriptorPath -Raw | ConvertFrom-Json
    $copilotDescriptor.command = $brokenName
    $copilotDescriptor | ConvertTo-Json -Depth 100 | Set-Content $copilotDescriptorPath
    $env:PATH = @($tempRoot,$fakeAzFolder,$PSHOME,$(if ($IsWindows) { $null } else { "/bin:/usr/bin" })) -join [IO.Path]::PathSeparator
    $output = @(& $pwshPath -NoProfile -File $bundledRunner -Agent copilot-dev -HomeRoot $homeRoot 2>&1)
    Assert-Equal 1 $LASTEXITCODE 'Child start failure exits one'
    Assert-True (($output -join "`n").Contains('token valid until')) 'Child start failure occurs after provider construction'
    Assert-Equal 0 @(Get-ChildItem (Join-Path $homeRoot '.legion/temp') -Filter '*providers*').Count 'Child start failure cleans provider file'
    Assert-True (-not (($output -join "`n").Contains('fake-token'))) 'Start failure never prints token'

} finally {
    foreach ($name in $savedEnvironment.Keys) { [Environment]::SetEnvironmentVariable($name, $savedEnvironment[$name]) }
    if ($fakeRoot -and (Test-Path $fakeRoot)) { Remove-Item -LiteralPath $fakeRoot -Recurse -Force }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

