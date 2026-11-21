$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-validate.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ps-ai-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $ownerFile = Join-Path $PSScriptRoot 'fixtures/personalisation/valid-owner.json'
    $projectFile = Join-Path $PSScriptRoot 'fixtures/project/valid.json'
    $output = & pwsh -NoProfile -File $script -Kind personalisation -Path $ownerFile
    Assert-Equal 0 $LASTEXITCODE 'Valid owner exits zero'
    Assert-Equal 0 @($output).Count 'Valid owner has no output'
    $output = & pwsh -NoProfile -File $script -Kind project -Path $projectFile
    Assert-Equal 0 $LASTEXITCODE 'Valid project exits zero'
    Assert-Equal 0 @($output).Count 'Valid project has no output'
    $cases = @{
        'invalid-tool' = 'personalisation'
        'invalid-version' = 'personalisation'
        'invalid-duplicate' = 'personalisation'
        'invalid-id' = 'personalisation'
    }
    foreach ($name in $cases.Keys) {
        $kind = $cases[$name]
        $fixture = Join-Path $PSScriptRoot "fixtures/$kind/$name.json"
        $output = & pwsh -NoProfile -File $script -Kind $kind -Path $fixture
        Assert-Equal 1 $LASTEXITCODE "$name exits one"
        Assert-True (@($output).Count -gt 0) "$name emits issue"
        Assert-True (@($output)[0] -match '^[^:]+: ') "$name issue format"
    }
    $expected = @{
        'invalid-duplicate' = "agents: duplicate id 'codex-a'"
    }
    foreach ($name in $expected.Keys) {
        $fixture = Join-Path $PSScriptRoot "fixtures/personalisation/$name.json"
        $output = & pwsh -NoProfile -File $script -Kind personalisation -Path $fixture
        Assert-True ($output -contains $expected[$name]) "$name exact issue"
    }
    $raw = Get-Content -Raw $ownerFile
    $bomFile = Join-Path $tempRoot 'bom-crlf.json'
    [System.IO.File]::WriteAllText($bomFile, [char]0xFEFF + ($raw -replace "`r?`n", "`r`n"))
    $output = & pwsh -NoProfile -File $script -Kind personalisation -Path $bomFile
    Assert-Equal 0 $LASTEXITCODE 'BOM CRLF owner exits zero'
    Assert-Equal 0 @($output).Count 'BOM CRLF owner has no output'
    . $script -NoRun
    Assert-Equal 1 (Read-LegionJson -Path $bomFile).schemaVersion 'Read-LegionJson accepts BOM CRLF'
    $foundryFile = Join-Path $PSScriptRoot 'fixtures/personalisation/valid-foundry.json'
    Assert-Equal 0 @(Invoke-LegionValidation -Kind personalisation -Path $foundryFile).Count 'Foundry provider validates'
    $foundryIssues = @{
        'invalid-foundry-default' = @("agents[0].provider: default 'x' is not a deployment")
        'invalid-foundry-alias' = @(
            "agents[0].provider: alias 'sonnet' used twice",
            "agents[0].provider: duplicate deployment 'x'",
            "agents[1].provider: alias 'sonnet' is not supported by tool 'codex'"
        )
    }
    foreach ($name in $foundryIssues.Keys) {
        $issues = @(Invoke-LegionValidation -Kind personalisation -Path (Join-Path $PSScriptRoot "fixtures/personalisation/$name.json"))
        foreach ($expectedIssue in $foundryIssues[$name]) {
            Assert-True ($issues -contains $expectedIssue) "$name exact provider issue: $expectedIssue"
        }
    }
    $foundry = Read-LegionJson -Path $foundryFile
    foreach ($change in @(
        { param($p) $p.kind = 'bedrock' },
        { param($p) $p.endpoint += '/anthropic/' },
        { param($p) $p.deployments = @() },
        { param($p) $p | Add-Member extra 'no' },
        { param($p) $p.deployments[0] | Add-Member extra 'no' },
        { param($p) $p.deployments[0].alias = 'other' }
    )) {
        $copy = $foundry | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        & $change $copy.agents[5].provider
        $copy | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $tempRoot 'invalid-shape.json')
        Assert-True (@(Invoke-LegionValidation -Kind personalisation -Path (Join-Path $tempRoot 'invalid-shape.json')).Count -gt 0) 'Invalid provider shape rejected'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
# FourthToolAcrossSharedConsumers / DescriptorOverseerArgumentOrder.
& {
    $ErrorActionPreference = 'Stop'
    $repoRoot = Split-Path $PSScriptRoot -Parent
    $scratch = [IO.Path]::GetFullPath((Join-Path $repoRoot '.agents/temp/restructure'))
    $fixture = Join-Path $scratch ('consumers-' + [guid]::NewGuid().ToString('N'))
    $plugin = Join-Path $fixture 'plugin'
    $homeRoot = Join-Path $fixture 'home with spaces'
    $ownerPath = Join-Path $homeRoot '.legion/configuration/ps-ai-personalisation.json'
    $savedPath = $env:PATH
    try {
        New-Item -ItemType Directory (Split-Path $ownerPath -Parent) -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'plugins/ps-ai') $plugin -Recurse
        $fourthSkill = Join-Path $plugin 'skills/ps-ai-fourth'
        Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth') $fourthSkill -Recurse
        $owner = [pscustomobject]@{schemaVersion=1;agents=@();channels=@()}
        $owner | ConvertTo-Json -Depth 100 | Set-Content $ownerPath
        . (Join-Path $plugin 'bin/ps-ai-account.ps1') -HomeRoot $homeRoot
        Assert-Equal 'FOURTH_HOME' (Get-LegionTool -Tool fourth).configEnv 'Fourth config environment comes from descriptor'
        $env:PATH = @($fourthSkill,$env:PATH) -join [IO.Path]::PathSeparator
        & (Join-Path $plugin 'bin/ps-ai-account.ps1') -Action add -Tool fourth -Id fourth-dev -HomeRoot $homeRoot | Out-Null
        Assert-True ((Get-Content (Join-Path $homeRoot '.legion/bin/fourth-dev') -Raw).Contains((Join-Path $fourthSkill 'fourth-cli.ps1'))) 'Account default command uses descriptor executable'
        Assert-Equal 0 @(Invoke-LegionValidation -Kind personalisation -Path $ownerPath).Count 'Fourth account validates with matching skill'
        $discovery = @{Source='management';Deployments=@(@{name='model[1]-a';model='model[1]-a'})}
        $syntheticProvider = New-LegionFoundryProvider -Endpoint 'https://resource.cognitiveservices.azure.com' -Tool fourth -Deployments 'model[1]-a' -Default 'model[1]-a' -Aliases 'model[1]-a=alpha' -Discovery $discovery
        Assert-Equal 'alpha' $syntheticProvider.deployments[0].alias 'Fourth tool accepts its own alias'
        foreach ($tool in @('claude','codex','copilot')) {
            $issues = @(Get-LegionProviderIssues -Data @{agents=@(@{tool=$tool;provider=$syntheticProvider})})
            Assert-True ($issues -contains "agents[0].provider: alias 'alpha' is not supported by tool '$tool'") 'Alias membership is descriptor-specific'
        }
        Assert-Throws { New-LegionFoundryProvider -Endpoint $syntheticProvider.endpoint -Tool fourth -Deployments 'model[1]-a' -Default 'model[1]-a' -Aliases 'model[1]-a=opus' -Discovery $discovery } 'Fourth tool rejects built-in aliases'
        $owner = Read-LegionJson $ownerPath
        $owner.agents[0] | Add-Member provider $syntheticProvider
        $owner | ConvertTo-Json -Depth 100 | Set-Content $ownerPath
        Assert-Equal 0 @(Invoke-LegionValidation -Kind personalisation -Path $ownerPath).Count 'Synthetic alias passes schema and semantic validation'
        $azureCalls = [Collections.Generic.List[string]]::new()
        function Invoke-FoundryAz {
            param($Arguments)
            $azureCalls.Add(($Arguments -join ' '))
            $json = if ($Arguments -contains 'deployment') { '[{"name":"literal","properties":{"model":{"name":"model[1]-a"}}},{"name":"wildcard","properties":{"model":{"name":"model1-a"}}}]' } else { '[{"name":"resource","resourceGroup":"group"}]' }
            @{ExitCode=0;Output=$json;Error=''}
        }
        $found = Get-FoundryDeployments -Endpoint $syntheticProvider.endpoint -Tool fourth
        Assert-Equal 'literal' ($found.Deployments.name -join '|') 'Foundry prefix is literal rather than a wildcard'
        . (Join-Path $plugin 'bin/ps-ai-overseer.ps1') -NoRun -HomeRoot $homeRoot
        $launch = Get-OverseerLaunch -Personalisation $owner -AccountId fourth-dev -Tool fourth -Arguments @('--account','account value','','2026-11-19') -HomeRoot $homeRoot
        Assert-Equal '--account|account value||2026-11-19|--interactive|space value|continue as the overseer' ($launch.Args -join '|') 'Descriptor tail follows explicit literal arguments'
        $descriptorPath = Join-Path $fourthSkill 'tool.json'
        $descriptor = Get-Content $descriptorPath -Raw | ConvertFrom-Json
        $descriptor.foundry = $null
        $descriptor | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        try {
            & (Join-Path $plugin 'bin/ps-ai-account.ps1') -Action add -Id fourth-dev -Tool fourth -Provider foundry -Endpoint $syntheticProvider.endpoint -HomeRoot $homeRoot | Out-Null
            throw 'Expected unsupported repeated Foundry add'
        } catch { Assert-Equal "tool 'fourth' does not support Foundry" $_.Exception.Message 'Repeated Foundry add rejects null capability without writes' }
        $beforeCalls = $azureCalls.Count
        Assert-Throws { Get-FoundryDeployments -Endpoint $syntheticProvider.endpoint -Tool fourth } 'Null Foundry rejects discovery'
        function Test-FoundryToken { throw 'Azure token must not be requested' }
        try { Get-LegionFoundryDiscovery -Endpoint $syntheticProvider.endpoint -Tool fourth; throw 'Expected unsupported capability' }
        catch { Assert-Equal "tool 'fourth' does not support Foundry" $_.Exception.Message 'Null Foundry stops before token login' }
        Assert-Equal $beforeCalls $azureCalls.Count 'Null Foundry makes no Azure calls'
        Assert-Throws { Write-FoundryToolConfig -Agent $owner.agents[0] -HomeRoot $homeRoot } 'Null Foundry rejects config writes'
        Remove-Item (Join-Path $fourthSkill 'SKILL.md')
        Assert-True (@(Invoke-LegionValidation -Kind personalisation -Path $ownerPath).Count -gt 0) 'Absent matching skill rejects persisted tool'
        # Loading definitions and lease/hook operations must not discover malformed data.
        '{broken' | Set-Content $descriptorPath
        . (Join-Path $plugin 'bin/lib/common.ps1')
        Assert-Equal 'free' (Get-LegionLease -Repo $fixture).State 'Lease remains usable with a malformed descriptor'
        . (Join-Path $plugin 'hooks/detect-mode.ps1') -NoRun
        $output = & pwsh -NoProfile -File (Join-Path $plugin 'bin/ps-ai-lease.ps1') -Action status -Repo $fixture
        Assert-Equal 0 $LASTEXITCODE 'Lease script does not discover tools'
        Assert-Equal 'free' $output 'Lease output is unchanged'
        Assert-Throws { Get-LegionTool -Tool fourth } 'Tool operations discover malformed descriptor lazily'
    } finally {
        $env:PATH = $savedPath
        $cleanup = [IO.Path]::GetFullPath($fixture)
        if (-not $cleanup.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe consumer fixture cleanup' }
        Remove-Item -LiteralPath $cleanup -Recurse -Force
    }
}
