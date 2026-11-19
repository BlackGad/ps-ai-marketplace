# LaunchAdapterContract: invoke adapters, never dot-source their internals.
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
        foreach ($configDir in @('~/.legion-agent-a', (Join-Path $homeRoot 'absolute config'))) {
            $adapterAgent = [pscustomobject]@{ id = 'agent-a'; tool = $id; configDir = $configDir; provider = $provider }
            $result = @(& $adapter -Agent $adapterAgent -HomeRoot $homeRoot -Token $injectedToken)
            Assert-Equal 1 $result.Count "$id emits exactly one object"
            $launch = $result[0]
            Assert-True ($launch -is [hashtable]) "$id returns a hashtable"
            Assert-Equal 'Clear|Notice|ProvidersFile|ProvidersJson|Set' (($launch.Keys | Sort-Object) -join '|') "$id launch contract has exactly five fields"
            Assert-True ($launch.Clear -is [string[]]) "$id clear list is typed"
            if ($id -eq 'copilot') {
                $json = $launch.ProvidersJson | ConvertFrom-Json
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

# ConfigAdaptersPreserveAndSkip: config writers have one return value and no repeat writes.
& {
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $skillRoot = Join-Path $repoRoot 'plugins/ps-ai/skills'
    . (Join-Path $repoRoot 'plugins/ps-ai/bin/lib/tools.ps1')
    foreach ($adapterId in @('claude', 'codex')) {
        Assert-True (Test-Path -LiteralPath (Join-Path $skillRoot "ps-ai-$adapterId/scripts/foundry-config.ps1")) "$adapterId config adapter exists"
    }
    $scratchRoot = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $configRoot = Join-Path $scratchRoot ('config-' + [guid]::NewGuid().ToString('N'))
    $savedPath = $env:PATH
    $env:PATH = (Join-Path $PSScriptRoot 'fixtures/fake-az') + [IO.Path]::PathSeparator + $env:PATH
    function Get-FoundryToken { throw 'Config adapters must not request a token' }
    $configProvider = @{ endpoint = 'https://resource.cognitiveservices.azure.com'; default = 'deployment-a'; deployments = @(
        @{ name = 'deployment-a' }, @{ name = 'deployment-b' }
    ) }
    try {
        foreach ($adapterId in @('claude', 'codex')) {
            $adapter = Join-Path $skillRoot "ps-ai-$adapterId/scripts/foundry-config.ps1"
            foreach ($seeded in @($false, $true)) {
                $configDir = Join-Path $configRoot "$adapterId-$seeded"
                $configAgent = @{ tool = $adapterId; configDir = $configDir; provider = $configProvider }
                $configName = if ($adapterId -eq 'claude') { 'settings.json' } else { 'config.toml' }
                $configFile = Join-Path $configDir $configName
                if ($seeded) {
                    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
                    $configAgent.configDir = "~/$adapterId-$seeded"
                    $seed = if ($adapterId -eq 'claude') { '{"theme":"dark","custom":{"label":"café","lastViewed":"2026-11-18T16:01:00+03:00"}}' } else { "approval_policy = `"never`"`n[other]`nmodel = `"kept-nested`"`n" }
                    [IO.File]::WriteAllText($configFile, $seed, [Text.UTF8Encoding]::new($false))
                }
                $results = @(& $adapter -Agent $configAgent -HomeRoot $configRoot)
                Assert-Equal 1 $results.Count "$adapterId writer returns exactly one object"
                $result = $results[0]
                Assert-True ($result -is [hashtable]) "$adapterId config result is a hashtable"
                Assert-Equal 'Changed|Path' (($result.Keys | Sort-Object) -join '|') "$adapterId config contract has exactly two fields"
                Assert-True ($result.Changed -is [bool] -and $result.Changed) "$adapterId reports a changed config"
                Assert-Equal $configFile $result.Path "$adapterId reports the resolved path"
                $configBytes = [IO.File]::ReadAllBytes($configFile)
                Assert-True (-not ($configBytes[0] -eq 239 -and $configBytes[1] -eq 187 -and $configBytes[2] -eq 191)) "$adapterId writes without BOM"
                $configText = [Text.UTF8Encoding]::new($false, $true).GetString($configBytes)
                if ($adapterId -eq 'claude') {
                    $settings = $configText | ConvertFrom-Json
                    Assert-True $settings.modelPicker.replaceBuiltInOptions 'Claude replaces built-in model options'
                    Assert-Equal 'deployment-a|deployment-b' ($settings.modelPicker.options.model -join '|') 'Claude picker models are deployment names'
                    Assert-Equal 'deployment-a|deployment-b' ($settings.modelPicker.options.label -join '|') 'Claude picker labels are deployment names'
                    if ($seeded) {
                        Assert-Equal 'dark' $settings.theme 'Claude preserves unrelated settings'
                        Assert-Equal 'café' $settings.custom.label 'Claude preserves nested Unicode settings'
                        $savedSettings = ConvertFrom-PsAiToolJson -Json $configText
                        Assert-Equal '2026-11-18T16:01:00+03:00' $savedSettings.custom.lastViewed 'Claude preserves unrelated timestamp strings and offsets'
                    }
                } else {
                    Assert-True ($configText.Contains('model = "deployment-a"')) 'Codex selects the default deployment'
                    Assert-True ($configText.Contains('base_url = "https://resource.cognitiveservices.azure.com/openai/v1"')) 'Codex uses the responses endpoint'
                    Assert-True ($configText.Contains('wire_api = "responses"')) 'Codex uses responses protocol'
                    Assert-True ($configText.Contains('command = ' + ((Get-Command az).Source | ConvertTo-Json -Compress))) 'Codex uses the full Azure CLI path'
                    Assert-True ($configText.Contains('args = ["account","get-access-token","--resource","https://cognitiveservices.azure.com","--query","accessToken","-o","tsv"]')) 'Codex keeps the complete token command'
                    Assert-True ($configText.Contains('refresh_interval_ms = 1800000')) 'Codex keeps the refresh interval'
                    if ($seeded) {
                        Assert-True ($configText.Contains('approval_policy = "never"')) 'Codex preserves root configuration'
                        Assert-True ($configText.Contains("[other]`nmodel = `"kept-nested`"")) 'Codex preserves unrelated table configuration'
                    }
                }
                [IO.File]::SetLastWriteTimeUtc($configFile, [datetime]'2020-01-01T00:00:00Z')
                $beforeTime = [IO.File]::GetLastWriteTimeUtc($configFile)
                $repeatResults = @(& $adapter -Agent $configAgent -HomeRoot $configRoot)
                Assert-Equal 1 $repeatResults.Count "$adapterId repeated writer returns one object"
                Assert-Equal $false $repeatResults[0].Changed "$adapterId repeated write reports no change"
                Assert-Equal $configFile $repeatResults[0].Path "$adapterId repeated write reports the same path"
                Assert-Equal ([Convert]::ToBase64String($configBytes)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($configFile))) "$adapterId repeat preserves bytes"
                Assert-Equal $beforeTime ([IO.File]::GetLastWriteTimeUtc($configFile)) "$adapterId repeat preserves mtime"
            }
        }
        # User settings allow case-distinct keys, comments and trailing commas.
        foreach ($syntax in @('json', 'comments-and-trailing-commas')) {
            $settingsDir = Join-Path $configRoot $syntax
            New-Item -ItemType Directory -Path $settingsDir -Force | Out-Null
            $settingsFile = Join-Path $settingsDir 'settings.json'
            $seed = '{"custom":"lower-root","Custom":"upper-root","env":{"http_proxy":"lower-proxy","HTTP_PROXY":"upper-proxy"}}'
            if ($syntax -eq 'comments-and-trailing-commas') {
                $seed = "// owner note`n" + $seed.Replace('"env":', '/* proxy settings */ "env":').Replace('}}', ',},}')
            }
            [IO.File]::WriteAllText($settingsFile, $seed)
            $settingsAgent = @{ tool='claude'; configDir=$settingsDir; provider=$configProvider }
            $writer = Join-Path $skillRoot 'ps-ai-claude/scripts/foundry-config.ps1'
            $result = & $writer -Agent $settingsAgent -HomeRoot $configRoot
            Assert-Equal $true $result.Changed "$syntax settings receive model picker"
            $bytes = [IO.File]::ReadAllBytes($settingsFile)
            $settings = [IO.File]::ReadAllText($settingsFile) | ConvertFrom-Json -AsHashtable
            Assert-Equal 'lower-root' $settings['custom'] "$syntax preserves lowercase root key"
            Assert-Equal 'upper-root' $settings['Custom'] "$syntax preserves uppercase root key"
            Assert-Equal 'lower-proxy' $settings.env['http_proxy'] "$syntax preserves lowercase nested key"
            Assert-Equal 'upper-proxy' $settings.env['HTTP_PROXY'] "$syntax preserves uppercase nested key"
            Assert-Equal 'deployment-a|deployment-b' ($settings.modelPicker.options.model -join '|') "$syntax updates model picker"
            [IO.File]::SetLastWriteTimeUtc($settingsFile, [datetime]'2020-01-01T00:00:00Z')
            $beforeTime = [IO.File]::GetLastWriteTimeUtc($settingsFile)
            $repeat = & $writer -Agent $settingsAgent -HomeRoot $configRoot
            Assert-Equal $false $repeat.Changed "$syntax repeat reports no change"
            Assert-Equal ([Convert]::ToBase64String($bytes)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($settingsFile))) "$syntax repeat preserves all bytes and keys"
            Assert-Equal $beforeTime ([IO.File]::GetLastWriteTimeUtc($settingsFile)) "$syntax repeat preserves mtime"
        }

        # Hashtable enumeration can change between processes; repeats must still be write-free.
        $childWriter = Join-Path $configRoot 'write-config.ps1'
        @'
param([string]$Adapter, [string]$AgentPath, [string]$HomeRoot)
$agentData = Get-Content -LiteralPath $AgentPath -Raw | ConvertFrom-Json
& $Adapter -Agent $agentData -HomeRoot $HomeRoot | ConvertTo-Json -Compress
'@ | Set-Content -LiteralPath $childWriter
        $childConfig = Join-Path $configRoot 'claude-processes/settings.json'
        $childAgent = @{ tool = 'claude'; configDir = (Split-Path $childConfig -Parent); provider = $configProvider }
        $childAgentPath = Join-Path $configRoot 'agent.json'
        $childAgent | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $childAgentPath
        $claudeWriter = Join-Path $skillRoot 'ps-ai-claude/scripts/foundry-config.ps1'
        $null = & $claudeWriter -Agent $childAgent -HomeRoot $configRoot
        [IO.File]::SetLastWriteTimeUtc($childConfig, [datetime]'2020-01-01T00:00:00Z')
        $childTime = [IO.File]::GetLastWriteTimeUtc($childConfig)
        $childBytes = [Convert]::ToBase64String([IO.File]::ReadAllBytes($childConfig))
        foreach ($attempt in 1..8) {
            $childOutput = & pwsh -NoProfile -File $childWriter -Adapter $claudeWriter -AgentPath $childAgentPath -HomeRoot $configRoot
            Assert-Equal 0 $LASTEXITCODE 'Config writer succeeds in a fresh process'
            $childResult = $childOutput | ConvertFrom-Json -ErrorAction Stop
            Assert-Equal $false $childResult.Changed 'Claude repeat in a fresh process reports no change'
            Assert-Equal $childBytes ([Convert]::ToBase64String([IO.File]::ReadAllBytes($childConfig))) 'Fresh process preserves Claude settings bytes'
            Assert-Equal $childTime ([IO.File]::GetLastWriteTimeUtc($childConfig)) 'Fresh process preserves Claude settings mtime'
        }

        $invalidDir = Join-Path $configRoot 'invalid-json'
        New-Item -ItemType Directory -Path $invalidDir -Force | Out-Null
        $invalidFile = Join-Path $invalidDir 'settings.json'
        foreach ($invalidJson in @('{bad', '[]', '[{"existing":"preserve"}]', 'null')) {
            [IO.File]::WriteAllText($invalidFile, $invalidJson)
            $invalidAgent = @{ tool = 'claude'; configDir = $invalidDir; provider = $configProvider }
            $configError = ''
            try { & (Join-Path $skillRoot 'ps-ai-claude/scripts/foundry-config.ps1') -Agent $invalidAgent -HomeRoot $configRoot | Out-Null }
            catch { $configError = $_.Exception.Message }
            Assert-Equal 'settings.json is not valid JSON; fix or remove it' $configError 'Claude retains the invalid JSON diagnostic'
            Assert-Equal $invalidJson ([IO.File]::ReadAllText($invalidFile)) 'Claude leaves invalid JSON untouched'
        }

        # Exercise the account delegator against real, relocated discovery data.
        $pluginCopy = Join-Path $configRoot 'plugin'
        Copy-Item -LiteralPath (Join-Path $repoRoot 'plugins/ps-ai') -Destination $pluginCopy -Recurse
        $fourthCopy = Join-Path $pluginCopy 'skills/ps-ai-fourth'
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth') -Destination $fourthCopy -Recurse
        $homeCopy = Join-Path $configRoot 'delegation home'
        $personalisation = Join-Path $homeCopy '.agents/configuration/ps-ai-personalisation.json'
        New-Item -ItemType Directory -Path (Split-Path $personalisation -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($personalisation, '{"schemaVersion":1,"agents":[]}')
        & {
            . (Join-Path $pluginCopy 'bin/ps-ai-account.ps1') -HomeRoot $homeCopy
            foreach ($adapterId in @('copilot', 'fourth')) {
                $absentDir = Join-Path $homeCopy $adapterId
                $configAgent = @{ tool = $adapterId; configDir = $absentDir; provider = $configProvider }
                $results = @(Write-FoundryToolConfig -Agent $configAgent -HomeRoot $homeCopy)
                Assert-Equal 1 $results.Count 'Missing optional writer returns one result'
                Assert-Equal 'Changed|Path' (($results[0].Keys | Sort-Object) -join '|') 'Missing writer returns the config contract'
                Assert-Equal $false $results[0].Changed 'Missing writer reports no changes'
                Assert-Equal $null $results[0].Path 'Missing writer has no config path'
                Assert-True (-not (Test-Path -LiteralPath $absentDir)) 'Missing writer creates no directory'
            }
            $fourthFile = Join-Path $fourthCopy 'tool.json'
            $fourthData = Get-Content -LiteralPath $fourthFile -Raw | ConvertFrom-Json -AsHashtable
            $fourthData.foundry = $null
            $fourthData | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $fourthFile
            foreach ($adapterId in @('fourth', 'absent')) {
                $absentDir = Join-Path $homeCopy "$adapterId-unsupported"
                $configAgent = @{ tool = $adapterId; configDir = $absentDir; provider = $configProvider }
                $configError = ''
                try { Write-FoundryToolConfig -Agent $configAgent -HomeRoot $homeCopy | Out-Null }
                catch { $configError = $_.Exception.Message }
                $expectedError = if ($adapterId -eq 'fourth') { "tool 'fourth' does not support Foundry" } else { "unknown tool 'absent'" }
                Assert-Equal $expectedError $configError 'Unsupported and unknown config operations fail clearly'
                Assert-True (-not (Test-Path -LiteralPath $absentDir)) 'Rejected capability creates no directory'
            }
        }
    } finally {
        $env:PATH = $savedPath
        $cleanupPath = [IO.Path]::GetFullPath($configRoot)
        if (-not $cleanupPath.StartsWith($scratchRoot + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe test cleanup path' }
        if (Test-Path -LiteralPath $cleanupPath) { Remove-Item -LiteralPath $cleanupPath -Recurse -Force }
    }
}

