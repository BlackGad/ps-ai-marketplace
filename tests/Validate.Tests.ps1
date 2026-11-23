$root = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('legion-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null

# A tool case is the real descriptor with one edit: the value at a JSON pointer path, or no property there.
function Get-EditedDescriptor {
    param($Case)
    $data = Get-Content (Join-Path $root "plugins/legion/skills/legion-$($Case.tool)/tool.json") -Raw | ConvertFrom-Json
    if (-not $Case.path) { return $data }
    $keys = @($Case.path.Split('/') | Select-Object -Skip 1)
    $target = $data
    foreach ($key in @($keys | Select-Object -SkipLast 1)) {
        if ($target -is [array]) { $target = $target[[int]$key] } else { $target = $target.$key }
    }
    $last = $keys[-1]
    if ($Case.PSObject.Properties.Name -notcontains 'value') { $target.PSObject.Properties.Remove($last) }
    elseif ($target -is [array]) { $target[[int]$last] = $Case.value }
    else { $target.$last = $Case.value }
    return $data
}

try {
    . (Join-Path $root 'plugins/legion/bin/lib/settings.ps1')
    $ownerFile = Join-Path $PSScriptRoot 'fixtures/personalisation/valid-owner.json'
    # The command moved to Python (tests/python/legion/test_validate.py); both engines must give the verdicts recorded from the old run.
    $recorded = Get-Content (Join-Path $PSScriptRoot 'fixtures/validate/old-behaviour.json') -Raw | ConvertFrom-Json
    foreach ($case in $recorded.validate) {
        $issues = @(Invoke-LegionValidation -Kind $case.kind -Path (Join-Path $root $case.path) 2>$null)
        Assert-Equal ([int]($case.exit -ne 0)) ([int]($issues.Count -gt 0)) "$($case.name) verdict matches the recorded run"
        if (@($case.output).Count -gt 0 -and -not $case.output[0].StartsWith('$:')) {
            Assert-Equal (@($case.output) -join '|') ($issues -join '|') "$($case.name) semantic messages match the recorded run"
        }
    }
    foreach ($case in $recorded.tool) {
        $json = Get-EditedDescriptor $case | ConvertTo-Json -Depth 100
        $valid = [bool](Test-Json -Json $json -SchemaFile (Join-Path $root 'plugins/legion/schemas/tool.schema.json') -ErrorAction SilentlyContinue)
        Assert-Equal $case.valid $valid "Tool schema case $($case.name) matches the recorded run"
    }
    $raw = Get-Content -Raw $ownerFile
    $bomFile = Join-Path $tempRoot 'bom-crlf.json'
    [System.IO.File]::WriteAllText($bomFile, [char]0xFEFF + ($raw -replace "`r?`n", "`r`n"))
    Assert-Equal 0 @(Invoke-LegionValidation -Kind personalisation -Path $bomFile).Count 'BOM CRLF owner validates'
    Assert-Equal 1 (Read-LegionJson -Path $bomFile).schemaVersion 'Read-LegionJson accepts BOM CRLF'
    $foundry = Read-LegionJson -Path (Join-Path $PSScriptRoot 'fixtures/personalisation/valid-foundry.json')
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
    $ownerPath = Join-Path $homeRoot '.legion/configuration/personalisation.json'
    $savedPath = $env:PATH
    try {
        New-Item -ItemType Directory (Split-Path $ownerPath -Parent) -Force | Out-Null
        Copy-Item (Join-Path $repoRoot 'plugins/legion') $plugin -Recurse
        $fourthSkill = Join-Path $plugin 'skills/legion-fourth'
        Copy-Item (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth') $fourthSkill -Recurse
        $owner = [pscustomobject]@{schemaVersion=1;agents=@();channels=@()}
        $owner | ConvertTo-Json -Depth 100 | Set-Content $ownerPath
        . (Join-Path $plugin 'bin/lib/accounts.ps1')
        Assert-Equal 'FOURTH_HOME' (Get-LegionTool -Tool fourth).configEnv 'Fourth config environment comes from descriptor'
        $env:PATH = @($fourthSkill,$env:PATH) -join [IO.Path]::PathSeparator
        & (Join-Path $plugin 'bin/legion-account.ps1') -Action add -Tool fourth -Id fourth-dev -HomeRoot $homeRoot | Out-Null
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
        . (Join-Path $plugin 'bin/legion-overseer.ps1') -NoRun -HomeRoot $homeRoot
        $launch = Get-OverseerLaunch -Personalisation $owner -AccountId fourth-dev -Tool fourth -Arguments @('--account','account value','','2026-11-19') -HomeRoot $homeRoot
        Assert-Equal '--account|account value||2026-11-19|--interactive|space value|continue as the overseer' ($launch.Args -join '|') 'Descriptor tail follows explicit literal arguments'
        $descriptorPath = Join-Path $fourthSkill 'tool.json'
        $descriptor = Get-Content $descriptorPath -Raw | ConvertFrom-Json
        $descriptor.foundry = $null
        $descriptor | ConvertTo-Json -Depth 100 | Set-Content $descriptorPath
        try {
            & (Join-Path $plugin 'bin/legion-account.ps1') -Action add -Id fourth-dev -Tool fourth -Provider foundry -Endpoint $syntheticProvider.endpoint -HomeRoot $homeRoot | Out-Null
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
        Assert-Throws { Get-LegionTool -Tool fourth } 'Tool operations discover malformed descriptor lazily'
    } finally {
        $env:PATH = $savedPath
        $cleanup = [IO.Path]::GetFullPath($fixture)
        if (-not $cleanup.StartsWith($scratch + [IO.Path]::DirectorySeparatorChar)) { throw 'Unsafe consumer fixture cleanup' }
        Remove-Item -LiteralPath $cleanup -Recurse -Force
    }
}
