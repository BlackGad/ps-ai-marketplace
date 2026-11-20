$repo = Split-Path $PSScriptRoot -Parent
$accountScript = Join-Path $repo 'plugins/ps-ai/bin/ps-ai-account.ps1'
. $accountScript -NoRun
. (Join-Path $PSScriptRoot 'FakeAz.ps1')

$claude = Get-PsAiTool -Tool claude
$standardDeployments = @(
    @{name='opus-5-1';model='claude-opus-5-1'},
    @{name='opus-5.5-2';model='claude-opus-5-5'},
    @{name='claude-sonnet-5-5';model='claude-sonnet-5-5'},
    @{name='haiku-5-5';model='claude-haiku-5-5'},
    @{name='fable-5-2';model='claude-fable-5-2'},
    @{name='notopus-99';model='claude-notopus-99'}
)
$mapping = Select-PsAiFoundryStandard -Deployments $standardDeployments -Tool $claude
Assert-Equal 'opus-5.5-2=opus|claude-sonnet-5-5=sonnet|haiku-5-5=haiku' ($mapping.Aliases -join '|') 'Standard maps separate tokens and compares numeric versions'
Assert-Equal 'claude-sonnet-5-5' $mapping.Default 'Claude standard defaults to sonnet'
Assert-Equal 0 @($mapping.Unresolved).Count 'Complete mapping resolves all aliases'

$modelOnly = @(
    @{name='primary';model='CLAUDE_OPUS 5.10'},
    @{name='secondary';model='claude.opus.5.9'},
    $standardDeployments[2], $standardDeployments[3]
)
$mapping = Select-PsAiFoundryStandard -Deployments $modelOnly -Tool $claude
Assert-Equal 'primary=opus' $mapping.Aliases[0] 'Model tokens match without case sensitivity and compare numerically'

$tie = @($standardDeployments) + @(@{name='other-opus-5-5-2';model='claude-opus'})
$mapping = Select-PsAiFoundryStandard -Deployments $tie -Tool $claude
Assert-Equal 'opus' $mapping.Unresolved[0].Alias 'Equal highest versions leave the alias unresolved'
Assert-Equal 'opus-5.5-2|other-opus-5-5-2' ($mapping.Unresolved[0].Candidates -join '|') 'Tie names only the tied candidates'
Assert-True (-not ($mapping.Aliases -match '=opus$')) 'Ties never silently choose an alias'
$mapping = Select-PsAiFoundryStandard -Deployments @($standardDeployments[0],$standardDeployments[3]) -Tool $claude
Assert-Equal 'sonnet' $mapping.Unresolved[0].Alias 'Missing alias is unresolved'
Assert-Equal 'opus-5-1' $mapping.Default 'Without sonnet the first mapped alias is the default'
Assert-Equal 'opus-5-1|haiku-5-5' ($mapping.Unresolved[0].Candidates -join '|') 'Missing alias supplies available candidates'

$gpt = @(
    @{name='gpt-6.1-sol';model='gpt-6.1-sol'},
    @{name='gpt-6.2-sol';model='gpt-6.2-sol'},
    @{name='gpt-9-astra';model='gpt-9-astra'}
)
foreach ($toolId in @('codex','copilot')) {
    $descriptor = Get-PsAiTool -Tool $toolId
    $mapping = Select-PsAiFoundryStandard -Deployments $gpt -Tool $descriptor
    Assert-Equal 'gpt-6.2-sol' $mapping.Default "$toolId prefers the newest sol deployment"
    Assert-Equal 0 @($mapping.Aliases).Count "$toolId saves no aliases"
    $mapping = Select-PsAiFoundryStandard -Deployments @($standardDeployments[0],$standardDeployments[1],@{name='fable-99';model='claude-fable-99'}) -Tool $descriptor
    Assert-Equal 'opus-5.5-2' $mapping.Default "$toolId falls back to newest without choosing Fable"
    $mapping = Select-PsAiFoundryStandard -Deployments @() -Tool $descriptor
    Assert-Equal 'default' $mapping.Unresolved[0].Alias "$toolId leaves an empty default unresolved"
    $mapping = Select-PsAiFoundryStandard -Deployments @($gpt[1],@{name='other-sol-6-2';model='gpt-sol'}) -Tool $descriptor
    Assert-Equal 'default' $mapping.Unresolved[0].Alias "$toolId leaves a tied default unresolved"
    $mapping = Select-PsAiFoundryStandard -Deployments @(@{name='fable-99';model='claude-fable-99'}) -Tool $descriptor
    Assert-Equal $null $mapping.Default "$toolId cannot choose Fable as its only default"
}

$savedPath = $env:PATH
$savedAnswers = $env:PS_AI_FAKE_AZ
$savedLog = $env:PS_AI_FAKE_AZ_LOG
$sandbox = Join-Path $repo ('.agents/temp/foundry-standard-' + [guid]::NewGuid().ToString('N'))
$file = Join-Path $sandbox '.legion/configuration/ps-ai-personalisation.json'
New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
@{schemaVersion=1;agents=@();channels=@()} | ConvertTo-Json | Set-Content $file
try {
    $deploymentCommand = 'cognitiveservices account deployment list --name res-a --resource-group rg-a'
    $answers = @{
        'account get-access-token --resource https://cognitiveservices.azure.com' = @{exit=0;stdout='{"accessToken":"fake-token","expiresOn":"2026-11-18T18:30:00+00:00"}'}
        'cognitiveservices account list' = @{exit=0;stdout='[{"name":"res-a","resourceGroup":"rg-a"}]'}
        $deploymentCommand = @{exit=0;stdout=(@($standardDeployments + $gpt | ForEach-Object { @{name=$_.name;properties=@{model=@{name=$_.model}}} }) | ConvertTo-Json -Depth 10)}
    }
    Use-FakeAz -Answers $answers
    $common = @{HomeRoot=$sandbox;Endpoint='https://res-a.cognitiveservices.azure.com';Provider='foundry'}
    & $accountScript -Action add -Id claude-standard -Tool claude @common -Standard | Out-Null
    $agent = (Get-Content $file -Raw | ConvertFrom-Json).agents[0]
    Assert-Equal 'claude-sonnet-5-5' $agent.provider.default 'Standard add saves the mapped default'
    Assert-Equal 'opus-5.5-2' ($agent.provider.deployments | Where-Object alias -EQ opus).name 'Standard add saves the newest opus alias'
    Assert-True (-not ($agent.provider.deployments | Where-Object alias -EQ fable)) 'Standard add saves no Fable alias'
    $before = [IO.File]::ReadAllText($file)
    $repeat = & $accountScript -Action models -Id claude-standard -HomeRoot $sandbox -Standard
    Assert-Equal 'skip: models claude-standard (no changes)' $repeat 'Standard update is safe to repeat'
    Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Repeated standard update preserves bytes'
    & $accountScript -Action add -Id codex-standard -Tool codex @common -Standard | Out-Null
    $agent = (Get-Content $file -Raw | ConvertFrom-Json).agents | Where-Object id -EQ codex-standard
    Assert-Equal 'gpt-6.2-sol' $agent.provider.default 'Codex add saves newest sol default'
    Assert-Equal 0 @($agent.provider.deployments | Where-Object alias).Count 'Codex standard persists no aliases'
    & $accountScript -Action add -Id copilot-standard -Tool copilot @common -Standard | Out-Null
    $agent = (Get-Content $file -Raw | ConvertFrom-Json).agents | Where-Object id -EQ copilot-standard
    Assert-Equal 'notopus-99' $agent.provider.default 'Copilot standard uses newest supported deployment without sol'
    Assert-Equal 0 @($agent.provider.deployments | Where-Object alias).Count 'Copilot standard persists no aliases'

    $updatedModels = @($standardDeployments + $gpt) + @(@{name='claude-sonnet-5-6';model='claude-sonnet-5-6'})
    $answers[$deploymentCommand].stdout = (@($updatedModels | ForEach-Object { @{name=$_.name;properties=@{model=@{name=$_.model}}} }) | ConvertTo-Json -Depth 10)
    Use-FakeAz -Answers $answers
    & $accountScript -Action models -Id claude-standard -HomeRoot $sandbox -Standard | Out-Null
    $agent = (Get-Content $file -Raw | ConvertFrom-Json).agents | Where-Object id -EQ claude-standard
    Assert-Equal 'claude-sonnet-5-6' $agent.provider.default 'Standard update selects a newly discovered version'
    Assert-Equal 'claude-sonnet-5-6' ($agent.provider.deployments | Where-Object alias -EQ sonnet).name 'Standard update moves the sonnet alias'
    & $accountScript -Action models -Id codex-standard -HomeRoot $sandbox -Standard -Deployments gpt-6.1-sol | Out-Null
    $agent = (Get-Content $file -Raw | ConvertFrom-Json).agents | Where-Object id -EQ codex-standard
    Assert-Equal 'gpt-6.1-sol' $agent.provider.default 'Standard can limit mapping to selected discovered deployments'
    Assert-Equal 1 $agent.provider.deployments.Count 'Limited standard saves only selected deployments'

    $answers[$deploymentCommand].stdout = (@($tie | ForEach-Object { @{name=$_.name;properties=@{model=@{name=$_.model}}} }) | ConvertTo-Json -Depth 10)
    Use-FakeAz -Answers $answers
    $before = [IO.File]::ReadAllText($file)
    try {
        & $accountScript -Action models -Id claude-standard -HomeRoot $sandbox -Standard | Out-Null
        throw 'Expected unresolved opus'
    } catch {
        Assert-True ($_.Exception.Message -match 'opus.*opus-5\.5-2.*other-opus-5-5-2') 'Tie stops with the alias and candidates'
    }
    Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Unresolved update preserves personalisation'
    $answers[$deploymentCommand].stdout = '[{"name":"opus-5-1","properties":{"model":{"name":"claude-opus-5-1"}}},{"name":"claude-sonnet-5-5","properties":{"model":{"name":"claude-sonnet-5-5"}}}]'
    Use-FakeAz -Answers $answers
    try {
        & $accountScript -Action add -Id claude-missing -Tool claude @common -Standard | Out-Null
        throw 'Expected unresolved haiku'
    } catch {
        Assert-True ($_.Exception.Message -match 'haiku.*opus-5-1.*claude-sonnet-5-5') 'Missing alias stops with available candidates'
    }
    Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Unresolved add preserves personalisation'
    Assert-True (-not (Test-Path (Join-Path $sandbox '.legion/agents/claude-missing'))) 'Unresolved add creates no account folder'
    foreach ($choice in @(@{Default='opus-5-1'},@{Aliases=@('opus-5-1=opus')})) {
        Assert-Throws { & $accountScript -Action add -Id invalid -Tool claude @common -Standard @choice } 'Standard add rejects explicit mapping flags'
        Assert-Throws { & $accountScript -Action models -Id claude-standard -HomeRoot $sandbox -Standard @choice } 'Standard update rejects explicit mapping flags'
    }
    & $accountScript -Action models -Id claude-standard -HomeRoot $sandbox -Deployments opus-5-1,claude-sonnet-5-5 -Default opus-5-1 -Aliases opus-5-1=opus,claude-sonnet-5-5=sonnet | Out-Null
    $agent = (Get-Content $file -Raw | ConvertFrom-Json).agents | Where-Object id -EQ claude-standard
    Assert-Equal 'opus-5-1' $agent.provider.default 'Explicit mapping still works after an unresolved standard mapping'
} finally {
    $env:PATH = $savedPath
    $fakeRoot = Split-Path $env:PS_AI_FAKE_AZ -Parent
    $env:PS_AI_FAKE_AZ = $savedAnswers
    $env:PS_AI_FAKE_AZ_LOG = $savedLog
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe fixture cleanup' }
    Remove-Item -LiteralPath $sandbox -Recurse -Force
    if ($fakeRoot -and [IO.Path]::GetFullPath($fakeRoot).StartsWith([IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetTempPath()) 'ps-ai-tests')) + [IO.Path]::DirectorySeparatorChar)) {
        Remove-Item -LiteralPath $fakeRoot -Recurse -Force
    }
}
