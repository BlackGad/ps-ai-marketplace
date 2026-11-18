# LaunchAdaptersMatchExistingObjects: invoke adapters, never dot-source their internals.
& {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $skillRoot = Join-Path $repoRoot 'plugins/ps-ai/skills'
    . (Join-Path $repoRoot 'plugins/ps-ai/bin/ps-ai-foundry.ps1') -NoRun
    function Get-FoundryToken { throw 'Unexpected token request' }
    $homeRoot = Join-Path $repoRoot '.agents/temp/restructure/adapter home'
    $injectedToken = @{ Token = 'fake-token'; ExpiresOn = [DateTimeOffset]'2026-11-18T18:30:00+00:00' }
    $provider = @{ endpoint = 'https://resource.cognitiveservices.azure.com'; default = 'deployment-a'; deployments = @(
        @{ name = 'deployment-a'; model = 'model-a'; alias = 'opus' },
        @{ name = 'deployment-b'; alias = 'sonnet' },
        @{ name = 'deployment-c'; alias = 'haiku' },
        @{ name = 'deployment-d'; alias = 'fable' }
    ) }
    foreach ($id in @('claude', 'codex', 'copilot')) {
        $adapter = Join-Path $skillRoot "ps-ai-$id/scripts/foundry-launch.ps1"
        Assert-True (Test-Path -LiteralPath $adapter) "$id launch adapter exists"
        foreach ($configDir in @('~/.agents/accounts/agent-a', (Join-Path $homeRoot 'absolute config'))) {
            $adapterAgent = [pscustomobject]@{ id = 'agent-a'; tool = $id; configDir = $configDir; provider = $provider }
            $old = Get-FoundryLaunch -Agent $adapterAgent -HomeRoot $homeRoot -Token $injectedToken
            $result = @(& $adapter -Agent $adapterAgent -HomeRoot $homeRoot -Token $injectedToken)
            Assert-Equal 1 $result.Count "$id emits exactly one object"
            $launch = $result[0]
            Assert-True ($launch -is [hashtable]) "$id returns a hashtable"
            Assert-Equal 'Clear|Notice|ProvidersFile|ProvidersJson|Set' (($launch.Keys | Sort-Object) -join '|') "$id launch contract has exactly five fields"
            Assert-True ($launch.Clear -is [string[]]) "$id clear list is typed"
            Assert-Equal ($old.Clear -join '|') ($launch.Clear -join '|') "$id clear list matches old runner"
            Assert-Equal ($old.Set.Keys | Sort-Object | Out-String) ($launch.Set.Keys | Sort-Object | Out-String) "$id environment keys match old runner"
            foreach ($key in $old.Set.Keys) {
                if ($key -ne 'COPILOT_PROVIDERS_CONFIG') { Assert-Equal $old.Set[$key] $launch.Set[$key] "$id environment value preserved" }
            }
            Assert-Equal $old.Notice $launch.Notice "$id notice preserved"
            if ($id -eq 'copilot') {
                $json = $launch.ProvidersJson | ConvertFrom-Json
                $oldJson = $old.ProvidersJson | ConvertFrom-Json
                Assert-Equal ($oldJson.providers | ConvertTo-Json -Depth 20 -Compress) ($json.providers | ConvertTo-Json -Depth 20 -Compress) 'Copilot provider payload matches old runner'
                Assert-Equal ($oldJson.models | ConvertTo-Json -Depth 20 -Compress) ($json.models | ConvertTo-Json -Depth 20 -Compress) 'Copilot models match old runner'
                Assert-Equal 'fake-token' $json.providers[0].bearerToken 'Copilot uses the injected fixed token'
                Assert-Equal 'model-a' $json.models[0].modelId 'Copilot prefers known model id'
                Assert-Equal 'deployment-b' $json.models[1].modelId 'Copilot falls back to deployment id'
                Assert-Equal 'deployment-b' $json.models[1].wireModel 'Copilot wire model is deployment id'
                Assert-True (-not ($json.PSObject.Properties.Name -contains 'default')) 'Copilot does not select the saved default'
                Assert-Equal (Join-Path $homeRoot '.agents/temp') (Split-Path $launch.ProvidersFile -Parent) 'Copilot provider file stays in per-home temp'
                Assert-Equal $launch.ProvidersFile $launch.Set.COPILOT_PROVIDERS_CONFIG 'Provider env points to returned file'
                Assert-True (-not (Test-Path -LiteralPath $launch.ProvidersFile)) 'Adapter leaves file creation to the runner'
            } else {
                Assert-Equal $null $launch.ProvidersFile "$id has no provider file"
                Assert-Equal $null $launch.ProvidersJson "$id has no provider JSON"
                $withoutToken = @(& $adapter -Agent $adapterAgent -HomeRoot $homeRoot)
                Assert-Equal 1 $withoutToken.Count "$id does not request a token"
                if ($id -eq 'claude') {
                    Assert-Equal 8 $launch.Set.Count 'Claude has four base values and four aliases'
                    Assert-Equal 10 $launch.Clear.Count 'Claude clears ten conflicting variables'
                    Assert-Equal 'https://resource.cognitiveservices.azure.com/anthropic' $launch.Set.ANTHROPIC_FOUNDRY_BASE_URL 'Claude endpoint suffix preserved'
                    Assert-Equal 'deployment-a' $launch.Set.ANTHROPIC_MODEL 'Claude saved default is selected'
                } else { Assert-Equal 'CODEX_HOME' ($launch.Set.Keys -join '|') 'Codex only sets its config home' }
            }
        }
    }
    function Get-FoundryToken { return $injectedToken }
    $adapterAgent = [pscustomobject]@{ id = 'agent-a'; tool = 'copilot'; configDir = '~/config'; provider = $provider }
    $result = @(& (Join-Path $skillRoot 'ps-ai-copilot/scripts/foundry-launch.ps1') -Agent $adapterAgent -HomeRoot $homeRoot)
    Assert-Equal 1 $result.Count 'Copilot obtains token only when omitted'
    Assert-Equal 'fake-token' (($result[0].ProvidersJson | ConvertFrom-Json).providers[0].bearerToken) 'Copilot uses caller token helper'
    Assert-True (-not (Test-Path -LiteralPath $homeRoot)) 'Launch adapters make no directories or config writes'
}
