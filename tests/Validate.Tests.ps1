$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-validate.ps1'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
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
        'invalid-tool' = 'personalisation'; 'invalid-role' = 'personalisation'
        'invalid-version' = 'personalisation'; 'invalid-backend' = 'personalisation'
        'invalid-duplicate' = 'personalisation'; 'invalid-routing' = 'personalisation'
        'invalid-notify' = 'personalisation'; 'invalid-id' = 'personalisation'
        'invalid-delivery' = 'project'; 'invalid-steps' = 'project'
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
        'invalid-duplicate' = "agents[3].id: duplicate id 'codex-a'"
        'invalid-routing' = "routing.implement[1]: unknown agent 'codex9'"
        'invalid-notify' = "projects.x.notify[0]: unknown channel 'slack'"
        'invalid-id' = 'agents[0].id: must match ^[a-z][a-z0-9-]*$'
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
    Assert-Equal 1 (Read-PsAiJson -Path $bomFile).schemaVersion 'Read-PsAiJson accepts BOM CRLF'
    $foundryFile = Join-Path $PSScriptRoot 'fixtures/personalisation/valid-foundry.json'
    Assert-Equal 0 @(Invoke-PsAiValidation -Kind personalisation -Path $foundryFile).Count 'Foundry provider validates'
    $foundryIssues = @{
        'invalid-foundry-default' = @("agents[5].provider: default 'x' is not a deployment")
        'invalid-foundry-alias' = @(
            "agents[5].provider: alias 'sonnet' used twice",
            "agents[5].provider: duplicate deployment 'x'",
            'agents[6].provider: aliases are for claude agents only'
        )
    }
    foreach ($name in $foundryIssues.Keys) {
        $issues = @(Invoke-PsAiValidation -Kind personalisation -Path (Join-Path $PSScriptRoot "fixtures/personalisation/$name.json"))
        foreach ($expectedIssue in $foundryIssues[$name]) {
            Assert-True ($issues -contains $expectedIssue) "$name exact provider issue: $expectedIssue"
        }
    }
    Assert-True (@(Invoke-PsAiValidation -Kind personalisation -Path (Join-Path $PSScriptRoot 'fixtures/personalisation/invalid-foundry-kind.json')).Count -gt 0) 'Unknown provider kind fails schema'
    $foundry = Read-PsAiJson -Path $foundryFile
    foreach ($change in @(
        { param($p) $p.endpoint += '/anthropic/' },
        { param($p) $p.deployments = @() },
        { param($p) $p | Add-Member extra 'no' },
        { param($p) $p.deployments[0] | Add-Member extra 'no' },
        { param($p) $p.deployments[0].alias = 'other' }
    )) {
        $copy = $foundry | ConvertTo-Json -Depth 100 | ConvertFrom-Json
        & $change $copy.agents[5].provider
        $copy | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath (Join-Path $tempRoot 'invalid-shape.json')
        Assert-True (@(Invoke-PsAiValidation -Kind personalisation -Path (Join-Path $tempRoot 'invalid-shape.json')).Count -gt 0) 'Invalid provider shape rejected'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
