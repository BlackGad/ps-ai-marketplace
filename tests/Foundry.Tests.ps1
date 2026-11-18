$root = Split-Path $PSScriptRoot -Parent
$helper = Join-Path $root 'plugins/ps-ai/bin/PsAi.Foundry.ps1'
Assert-True (Test-Path $helper) 'Foundry helper exists'
. $helper
. (Join-Path $PSScriptRoot 'FakeAz.ps1')
$savedPath = $env:PATH
$savedAnswers = $env:PS_AI_FAKE_AZ
$savedLog = $env:PS_AI_FAKE_AZ_LOG
$tempRoot = $null
try {
    Assert-Equal 'https://res-a.cognitiveservices.azure.com' (ConvertTo-FoundryEndpoint 'https://res-a.cognitiveservices.azure.com/anthropic/') 'Endpoint strips path'
    Assert-Equal 'res-a' (Get-FoundryResourceName 'https://res-a.cognitiveservices.azure.com') 'Resource comes from host'
    try { ConvertTo-FoundryEndpoint 'http://x'; throw 'Expected HTTPS error' }
    catch { Assert-Equal 'endpoint must start with https://' $_.Exception.Message 'HTTPS required' }
    $tokenKey = 'account get-access-token --resource https://cognitiveservices.azure.com'
    Use-FakeAz -Answers @{ $tokenKey = @{ exit=0; stdout='{"accessToken":"fake-token","expiresOn":"2026-11-18T18:30:00+00:00"}' } }
    $tempRoot = Split-Path $env:PS_AI_FAKE_AZ -Parent
    Assert-True (Test-FoundryToken).Ok 'Token check succeeds'
    $token = Get-FoundryToken
    Assert-Equal 'fake-token' $token.Token 'Token read in memory'
    Assert-Equal ([DateTimeOffset]'2026-11-18T18:30:00+00:00') $token.ExpiresOn 'Expiry parsed'
    Use-FakeAz -Answers @{ $tokenKey = @{ exit=1; stdout='fake token denied' }; login = @{ exit=0; stdout='' } }
    Assert-True (-not (Test-FoundryToken).Ok) 'Failed token check returned'
    Assert-Equal 0 @(Get-FakeAzCalls | Where-Object { $_ -eq 'login' }).Count 'No login without switch'
    $check = Test-FoundryToken -Login
    Assert-True (-not $check.Ok) 'Retry result returned'
    Assert-Equal 'fake token denied' $check.Error 'Retry error retained'
    Assert-Equal 1 @(Get-FakeAzCalls | Where-Object { $_ -eq 'login' }).Count 'Login once'
    Assert-Equal 3 @(Get-FakeAzCalls | Where-Object { $_ -eq $tokenKey }).Count 'Token checked again after login'
    $accounts = '[{"name":"res-a","resourceGroup":"rg-a"}]'
    $deployments = '[{"name":"claude-opus-x","properties":{"model":{"name":"claude-opus-x"}}},{"name":"claude-sonnet-x","properties":{"model":{"name":"claude-sonnet-x"}}},{"name":"gpt-x","properties":{"model":{"name":"gpt-x"}}},{"name":"embed-x","properties":{"model":{"name":"embed-x"}}}]'
    $answers = @{
        'cognitiveservices account list' = @{ exit=0; stdout=$accounts }
        'cognitiveservices account deployment list --name res-a --resource-group rg-a' = @{ exit=0; stdout=$deployments }
    }
    Use-FakeAz -Answers $answers
    $result = Get-FoundryDeployments -Endpoint 'https://res-a.cognitiveservices.azure.com' -Tool claude
    Assert-Equal 'management' $result.Source 'Current subscription source'
    Assert-Equal 'claude-opus-x|claude-sonnet-x' ($result.Deployments.name -join '|') 'Claude excludes GPT and embeddings'
    Assert-Equal 1 @( (Get-FoundryDeployments -Endpoint 'https://res-a.cognitiveservices.azure.com' -Tool codex).Deployments ).Count 'Codex filters GPT'
    Assert-Equal 2 @( (Get-FoundryDeployments -Endpoint 'https://res-a.cognitiveservices.azure.com' -Tool copilot).Deployments ).Count 'Copilot filters Claude'
    $answers = @{
        'cognitiveservices account list' = @{ exit=0; stdout='[]' }
        'account list' = @{ exit=0; stdout="sub-1`nsub-2" }
        'cognitiveservices account list --subscription sub-1' = @{ exit=0; stdout='[]' }
        'cognitiveservices account list --subscription sub-2' = @{ exit=0; stdout=$accounts }
        'cognitiveservices account deployment list --name res-a --resource-group rg-a --subscription sub-2' = @{ exit=0; stdout=$deployments }
    }
    Use-FakeAz -Answers $answers
    $result = Get-FoundryDeployments -Endpoint 'https://res-a.cognitiveservices.azure.com' -Tool claude
    Assert-Equal 'management' $result.Source 'Other subscription discovered'
    Assert-Equal 2 $result.Deployments.Count 'Other subscription deployments'
    Assert-True ((Get-FakeAzCalls) -contains 'cognitiveservices account list --subscription sub-2') 'Search reaches second subscription'
    Use-FakeAz -Answers @{}
    $result = Get-FoundryDeployments -Endpoint 'https://res-a.cognitiveservices.azure.com' -Tool claude
    Assert-Equal 'none' $result.Source 'Read failure source'
    Assert-True ($result.Error -match 'fake az: no answer for cognitiveservices account list') 'Read failure preserves stderr'
    Assert-Equal 0 $result.Deployments.Count 'Failed read has no deployments'
} finally {
    $env:PATH = $savedPath
    $env:PS_AI_FAKE_AZ = $savedAnswers
    $env:PS_AI_FAKE_AZ_LOG = $savedLog
    if ($tempRoot) { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
}
