$root = Split-Path $PSScriptRoot -Parent
$accountScript = Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1'
. (Join-Path $root 'plugins/ps-ai/bin/ps-ai-validate.ps1') -NoRun
. (Join-Path $PSScriptRoot 'FakeAz.ps1')
$savedPath = $env:PATH
$savedAnswers = $env:PS_AI_FAKE_AZ
$savedLog = $env:PS_AI_FAKE_AZ_LOG
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $homeRoot = Join-Path $tempRoot 'owner with spaces'
    $file = Join-Path $homeRoot '.agents/configuration/ps-ai-personalisation.json'
    New-Item -ItemType Directory -Path (Split-Path $file -Parent) -Force | Out-Null
    @{schemaVersion=1;communication=@{channels=@{}};agents=@();routing=@{};knowledge=@{backend='none'};projects=@{};default=@{notify=@()}} |
        ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $file
    $answers = @{
        'account get-access-token --resource https://cognitiveservices.azure.com' = @{exit=0;stdout='{"accessToken":"fake-token","expiresOn":"2026-11-18T18:30:00+00:00"}'}
        'cognitiveservices account list' = @{exit=0;stdout='[{"name":"res-a","resourceGroup":"rg-a"}]'}
        'cognitiveservices account deployment list --name res-a --resource-group rg-a' = @{exit=0;stdout='[{"name":"claude-opus-x","properties":{"model":{"name":"claude-opus-x"}}},{"name":"claude-sonnet-x","properties":{"model":{"name":"claude-sonnet-x"}}},{"name":"gpt-x","properties":{"model":{"name":"gpt-x"}}}]'}
    }
    Use-FakeAz -Answers $answers
    $fakeRoot = Split-Path $env:PS_AI_FAKE_AZ -Parent
    $common = @{HomeRoot=$homeRoot;Id='claude-dev';Tool='claude';Provider='foundry';Endpoint='https://res-a.cognitiveservices.azure.com/anthropic'}
    $before = [Convert]::ToBase64String([IO.File]::ReadAllBytes($file))
    $listOutput = & $accountScript -Action add @common -List
    Assert-True (($listOutput -join "`n").TrimStart().StartsWith('{')) 'Foundry add -List emits JSON'
    $listed = $listOutput | ConvertFrom-Json -ErrorAction Stop
    Assert-Equal 'management' $listed.source 'Add lists management deployments'
    Assert-Equal 'claude-opus-x|claude-sonnet-x' ($listed.deployments.name -join '|') 'Add lists matching models'
    Assert-Equal 'new|new' ($listed.deployments.state -join '|') 'Add states are new'
    Assert-Equal $before ([Convert]::ToBase64String([IO.File]::ReadAllBytes($file))) 'List leaves personalisation bytes unchanged'
    Assert-True (-not (Test-Path (Join-Path $homeRoot '.agents/bin'))) 'List creates no wrappers'
    $claudeDir = Join-Path $homeRoot '.agents/accounts/claude-dev'
    New-Item -ItemType Directory -Path $claudeDir -Force | Out-Null
    $settings = Join-Path $claudeDir 'settings.json'
    '{"theme":"dark"}' | Set-Content -LiteralPath $settings
    $selection = @{Deployments=@('claude-opus-x','claude-sonnet-x');Default='claude-opus-x';Aliases=@('claude-opus-x=opus','claude-sonnet-x=sonnet')}
    $addOutput = & $accountScript -Action add @common @selection
    Assert-Equal 1 @($addOutput).Count 'Foundry add emits only the next-step message'
    Assert-True (@($addOutput) -contains "Run 'claude-dev' in a terminal; it signs in to Azure through az when needed.") 'Foundry add prints next step'
    $data = Read-PsAiJson -Path $file
    $agent = $data.agents[0]
    Assert-Equal 'https://res-a.cognitiveservices.azure.com' $agent.provider.endpoint 'Add normalises endpoint'
    Assert-Equal 'claude-opus-x' $agent.provider.deployments[0].model 'Add fills model name'
    Assert-Equal 'sonnet' $agent.provider.deployments[1].alias 'Add saves alias'
    Assert-Equal 0 $agent.roles.Count 'Foundry agent starts without roles'
    Assert-Equal '~/.agents/bin/claude-dev' $agent.command 'Foundry command'
    Assert-Equal '~/.agents/accounts/claude-dev' $agent.configDir 'Foundry config dir'
    Assert-Equal 0 @(Invoke-PsAiValidation -Kind personalisation -Path $file).Count 'Added Foundry agent validates'
    $picker = Get-Content -Raw $settings | ConvertFrom-Json
    Assert-Equal 'dark' $picker.theme 'Claude preserves other settings'
    Assert-True $picker.modelPicker.replaceBuiltInOptions 'Claude picker replaces builtins'
    Assert-Equal 'claude-opus-x|claude-sonnet-x' ($picker.modelPicker.options.model -join '|') 'Picker uses deployment names'
    Assert-Equal 'claude-opus-x|claude-sonnet-x' ($picker.modelPicker.options.label -join '|') 'Picker labels'
    foreach ($name in @('claude-dev','claude-dev.cmd','ps-ai-foundry.ps1','PsAi.Foundry.ps1')) {
        Assert-True (Test-Path (Join-Path $homeRoot ".agents/bin/$name")) "Foundry writes $name"
    }
    $tracked = @($file, $settings, (Join-Path $homeRoot '.agents/bin/claude-dev'), (Join-Path $homeRoot '.agents/bin/ps-ai-foundry.ps1'))
    $timestamps = @($tracked | ForEach-Object { [IO.File]::GetLastWriteTimeUtc($_).Ticks })
    $repeat = & $accountScript -Action add @common @selection
    Assert-Equal 'skip: account claude-dev (already done)' $repeat 'Repeated add skips'
    Assert-Equal ($timestamps -join '|') (@($tracked | ForEach-Object { [IO.File]::GetLastWriteTimeUtc($_).Ticks }) -join '|') 'Repeat writes nothing'
    $output = & $accountScript -Action models -Id claude-dev -HomeRoot $homeRoot @selection
    Assert-Equal 'skip: models claude-dev (no changes)' $output 'Identical models skip'
    Assert-Equal ($timestamps -join '|') (@($tracked | ForEach-Object { [IO.File]::GetLastWriteTimeUtc($_).Ticks }) -join '|') 'Identical models write nothing'
    $before = Get-Content -Raw $file
    try {
        & $accountScript -Action models -Id claude-dev -HomeRoot $homeRoot -Deployments claude-opus-x -Default x | Out-Null
        throw 'Expected invalid default'
    } catch { Assert-Equal "default 'x' is not one of -Deployments" $_.Exception.Message 'Default must be selected' }
    Assert-Equal $before (Get-Content -Raw $file) 'Invalid update leaves personalisation unchanged'
    $answers['cognitiveservices account deployment list --name res-a --resource-group rg-a'].stdout = '[{"name":"claude-opus-x","properties":{"model":{"name":"claude-opus-x"}}},{"name":"claude-haiku-x","properties":{"model":{"name":"claude-haiku-x"}}}]'
    Use-FakeAz -Answers $answers
    $listed = & $accountScript -Action models -Id claude-dev -HomeRoot $homeRoot -List | ConvertFrom-Json
    Assert-Equal 'kept' @($listed.deployments | Where-Object name -eq claude-opus-x)[0].state 'Existing deployment kept'
    Assert-Equal 'new' @($listed.deployments | Where-Object name -eq claude-haiku-x)[0].state 'New deployment detected'
    Assert-Equal 'gone' @($listed.deployments | Where-Object name -eq claude-sonnet-x)[0].state 'Missing deployment marked gone'
    $failedAnswers = @{ 'account get-access-token --resource https://cognitiveservices.azure.com' = $answers['account get-access-token --resource https://cognitiveservices.azure.com'] }
    Use-FakeAz -Answers $failedAnswers
    $listed = & $accountScript -Action models -Id claude-dev -HomeRoot $homeRoot -List | ConvertFrom-Json
    Assert-Equal 'none' $listed.source 'Failed management source'
    Assert-Equal 0 @($listed.deployments | Where-Object state -eq gone).Count 'Failed management never marks gone'
    Assert-Equal 2 @($listed.deployments | Where-Object state -eq kept).Count 'Failed management retains selected models'
    Assert-True ($listed.error -match 'fake az: no answer') 'List exposes discovery failure'
    Assert-Equal $before (Get-Content -Raw $file) 'Lists never change saved selection'
    & $accountScript -Action models -Id claude-dev -HomeRoot $homeRoot @selection | Out-Null
    Assert-Equal $before (Get-Content -Raw $file) 'Failed discovery preserves known models on unchanged update'
    Use-FakeAz -Answers $answers
    $modelsOutput = @(& $accountScript -Action models -Id claude-dev -HomeRoot $homeRoot -Deployments claude-opus-x,claude-haiku-x -Default claude-haiku-x -Aliases claude-opus-x=opus,claude-haiku-x=haiku)
    Assert-Equal 0 $modelsOutput.Count 'Changed models does not leak the config adapter return value'
    $updated = (Read-PsAiJson $file).agents[0]
    Assert-Equal 'claude-haiku-x' $updated.provider.default 'Models updates default'
    Assert-Equal 'haiku' $updated.provider.deployments[1].alias 'Models updates aliases'
    Assert-Equal 'claude-opus-x|claude-haiku-x' ((Get-Content -Raw $settings | ConvertFrom-Json).modelPicker.options.model -join '|') 'Models refreshes picker'
    $badDir = Join-Path $homeRoot '.agents/accounts/claude-bad'
    New-Item -ItemType Directory -Path $badDir -Force | Out-Null
    $badSettings = Join-Path $badDir 'settings.json'
    [IO.File]::WriteAllText($badSettings, '{bad')
    try {
        & $accountScript -Action add -Id claude-bad -Tool claude -Provider foundry -Endpoint $common.Endpoint -HomeRoot $homeRoot @selection | Out-Null
        throw 'Expected invalid settings'
    } catch { Assert-Equal 'settings.json is not valid JSON; fix or remove it' $_.Exception.Message 'Unreadable settings stops add' }
    Assert-Equal '{bad' (Get-Content -Raw $badSettings) 'Unreadable settings unchanged'
    Assert-Equal 1 (Read-PsAiJson $file).agents.Count 'Invalid settings does not add partial account'
    $codexDir = Join-Path $homeRoot '.agents/accounts/codex-dev'
    New-Item -ItemType Directory -Path $codexDir -Force | Out-Null
    $toml = Join-Path $codexDir 'config.toml'
    @'
approval_policy = "never"
model = "old"
model_provider = "old"
[model_providers.ps-ai-foundry]
base_url = "old"
obsolete = true
[model_providers.ps-ai-foundry.auth]
command = "old"
[other]
model = "kept-nested"
value = 1
'@ | Set-Content -LiteralPath $toml
    & $accountScript -Action add -Id codex-dev -Tool codex -Provider foundry -Endpoint $common.Endpoint -HomeRoot $homeRoot -Deployments gpt-x -Default gpt-x | Out-Null
    $content = Get-Content -Raw $toml
    Assert-True ($content.Contains('approval_policy = "never"')) 'Codex preserves root keys'
    Assert-True ($content.Contains('model = "kept-nested"')) 'Codex preserves other tables'
    Assert-True ($content.Contains('base_url = "https://res-a.cognitiveservices.azure.com/openai/v1"')) 'Codex endpoint'
    Assert-True ($content.Contains('command = ' + ((Get-Command az).Source | ConvertTo-Json -Compress))) 'Codex uses full az command'
    Assert-True ($content.Contains('refresh_interval_ms = 1800000')) 'Codex refresh interval'
    Assert-True ($content.Contains('wire_api = "responses"')) 'Codex responses protocol'
    Assert-True ($content.Contains('"--resource","https://cognitiveservices.azure.com","--query","accessToken","-o","tsv"')) 'Codex token command arguments'
    Assert-True (-not $content.Contains('obsolete')) 'Codex replaces provider table'
    Assert-Equal 1 ([regex]::Matches($content, '(?m)^model_provider = ').Count) 'Codex has one root provider'
    $tomlCases = @(
        @{
            id = 'codex-quoted'
            text = @'
"model" = "old-model"
'model_provider' = "old-provider"
approval_policy = "never"
[model_providers."ps-ai-foundry"]
base_url = "old-endpoint"
[model_providers.'ps-ai-foundry'.auth]
command = "old-command"
[other]
value = 1
'@
            preserved = "[other]`nvalue = 1"
        },
        @{
            id = 'codex-multiline'
            text = @'
developer_instructions = """
[context]
Preserve these instructions.
"""
model = "old-model"
model_provider = "old-provider"
approval_policy = "never"
'@
            preserved = "developer_instructions = `"`"`"`n[context]`nPreserve these instructions.`n`"`"`""
        },
        @{
            id = 'codex-escaped'
            text = @'
# Comment with """ and [model_providers.ps-ai-foundry]
developer_instructions = """
Escaped delimiter: \"""
[model_providers.ps-ai-foundry]
model = "preserved-prompt"
""" # comment with ''' and [model_providers.ps-ai-foundry.auth]
note = "escaped quote: \" and triple apostrophes '''" # """
approval_policy = "never"
model = "old-model"
model_provider = "old-provider"
[model_providers.ps-ai-foundry] # '''
base_url = "old-endpoint"
[model_providers.ps-ai-foundry.auth] # """
command = "old-command"
[other] # """
value = 1
'@
            preserved = "developer_instructions = `"`"`"`nEscaped delimiter: \`"`"`"`n[model_providers.ps-ai-foundry]`nmodel = `"preserved-prompt`"`n`"`"`" # comment with ''' and [model_providers.ps-ai-foundry.auth]"
        },
        @{
            id = 'codex-nested-array'
            text = @'
matrix = [
  [1, 2],
  [3, 4], # comment with """
]
model = "old-model"
model_provider = "old-provider"
approval_policy = "never"
'@
            preserved = "matrix = [`n  [1, 2],`n  [3, 4], # comment with `"`"`"`n]"
        },
        @{
            id = 'codex-multiline-provider'
            text = @'
developer_instructions = '''
[model_providers.ps-ai-foundry]
Preserve these instructions.
'''
model = "old-model"
model_provider = "old-provider"
approval_policy = "never"
'@
            preserved = "developer_instructions = '''`n[model_providers.ps-ai-foundry]`nPreserve these instructions.`n'''"
        }
    )
    foreach ($tomlCase in $tomlCases) {
        $caseDir = Join-Path $homeRoot ".agents/accounts/$($tomlCase.id)"
        New-Item -ItemType Directory -Path $caseDir -Force | Out-Null
        $caseFile = Join-Path $caseDir 'config.toml'
        [IO.File]::WriteAllText($caseFile, $tomlCase.text.Replace("`r`n", "`n"))
        & $accountScript -Action add -Id $tomlCase.id -Tool codex -Provider foundry -Endpoint $common.Endpoint -HomeRoot $homeRoot -Deployments gpt-x -Default gpt-x | Out-Null
        $caseContent = Get-Content -Raw $caseFile
        Assert-True (-not ($caseContent -match 'old-(model|provider|endpoint|command)')) "$($tomlCase.id) replaces equivalent root keys and provider tables"
        Assert-True ($caseContent.Contains($tomlCase.preserved)) "$($tomlCase.id) preserves unrelated TOML content"
        Assert-True ($caseContent.Contains('approval_policy = "never"')) "$($tomlCase.id) preserves approval policy"
    }
    & $accountScript -Action rename -Id claude-dev -NewId claude-renamed -HomeRoot $homeRoot | Out-Null
    Assert-True ((Get-Content -Raw (Join-Path $homeRoot '.agents/bin/claude-renamed')).Contains('-Agent claude-renamed')) 'Foundry rename retargets wrapper'
    & $accountScript -Action remove -Id claude-renamed -HomeRoot $homeRoot | Out-Null
    Assert-True (-not (Test-Path (Join-Path $homeRoot '.agents/bin/claude-renamed'))) 'Remove deletes Foundry wrapper'
    Assert-True (Test-Path $settings) 'Remove keeps Foundry settings'
} finally {
    $env:PATH = $savedPath
    $env:PS_AI_FAKE_AZ = $savedAnswers
    $env:PS_AI_FAKE_AZ_LOG = $savedLog
    if ($fakeRoot -and (Test-Path $fakeRoot)) { Remove-Item -LiteralPath $fakeRoot -Recurse -Force }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
