$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $expectedRemove = @{
        claude='claude plugin marketplace remove ps-ai-marketplace'
        codex='codex plugin marketplace remove ps-ai-marketplace'
        copilot='copilot plugin marketplace remove ps-ai-marketplace --force'
    }
    function Ensure-InstallPowerShell { $true }
    function Get-InstallSourceText { throw 'No network in tests' }
    function Test-InstallCommandAvailable { $true }
    function claude { 'fixture-version' }
    function codex { 'fixture-version' }
    function copilot { 'fixture-version' }
    $calls = [Collections.Generic.List[string]]::new()
    $state = @{ ConflictTool=''; Unknown=$false; FailList=$false }
    function Invoke-ClosedInput {
        param($Command)
        $line = $Command -join '|'
        $calls.Add($line)
        if ($Command[2] -eq 'marketplace' -and $Command[3] -eq 'list') {
            if ($state.FailList) { return @{ExitCode=4; Output=@()} }
            if ($Command[0] -in @($state.ConflictTool)) {
                $source = if ($state.Unknown) { '' } else { 'https://github.com/example/old-source' }
                if ($state.Unknown) {
                    $output = if ($Command[0] -eq 'copilot') { '[{"name":"ps-ai-marketplace","source":""}]' } else { 'ps-ai-marketplace' }
                } else { $output = Get-FixtureMarketplaceListing -Tool $Command[0] -Source $source }
                return @{ExitCode=0; Output=@($output)}
            }
            return @{ExitCode=0; Output=@(Get-FixtureMarketplaceListing -Tool $Command[0])}
        }
        if ($Command[2] -eq 'list') {
            $output = if ($Command[0] -eq 'claude') { @('[]') } else { @() }
            return @{ExitCode=0; Output=$output}
        }
        if ($Command -contains 'remove') { throw 'Conflict must never remove anything' }
        return @{ExitCode=0; Output=@("fixture write: $line")}
    }
    foreach ($tool in @('claude','codex','copilot')) {
        $state.ConflictTool=$tool
        $calls.Clear()
        $output = [Collections.Generic.List[object]]::new()
        $failure = ''
        try {
            Invoke-PsAiInstaller -Tools claude,codex,copilot -Source 'example/new-source' -ConfigDir 'selected account' -Catalog $catalog -Yes |
                ForEach-Object { $output.Add($_) }
        } catch { $failure=$_.Exception.Message }
        $text = $output -join "`n"
        Assert-True ($text.Contains("$tool in selected account")) 'Conflict identifies tool and selected config'
        Assert-True ($text.Contains('https://github.com/example/old-source')) 'Conflict shows current source'
        Assert-True ($text.Contains($expectedRemove[$tool])) 'Conflict prints exact removal command from tool data'
        $entry = $catalog.tools | Where-Object id -EQ $tool
        Assert-True ($text.Contains('$env:' + $entry.configEnv + " = 'selected account'; " + $expectedRemove[$tool])) 'Removal hint selects the conflicting config in PowerShell'
        if ($tool -eq 'codex') { Assert-True ($text.Contains('removes hook approval')) 'Codex removal explains lost hook approval' }
        foreach ($other in $catalog.tools | Where-Object id -NE $tool) {
            Assert-True ($calls -contains ((@($other.command) + $other.plugin.install) -join '|')) 'Other tools finish installing despite conflict'
        }
        Assert-True ($failure -match '1.*conflict') 'Run fails only after other tools finish'
        Assert-Equal 0 @($calls | Where-Object { $_ -match "^$tool\|" -and $_ -notmatch '\|list(?:\|--json)?$' }).Count 'Conflicting tool is not mutated'
        Assert-Equal 0 @($calls | Where-Object { $_ -match '\|remove\|' }).Count 'Removal command is advice only'
    }
    $state.Unknown=$true
    $output.Clear()
    try {
        Invoke-PsAiInstaller -Tools copilot -Source 'example/new-source' -Catalog $catalog -Yes | ForEach-Object { $output.Add($_) }
    } catch { }
    Assert-True (($output -join "`n").Contains('copilot in default config')) 'Default config is named'
    Assert-True (($output -join "`n").Contains('current source: unknown')) 'Missing source is explicit'

    $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
    $fourth | Add-Member installHint 'fixture only'
    $catalog.tools += $fourth
    function fourth-cli { 'fixture-version' }
    $state.ConflictTool=@('claude','fourth-cli')
    $state.Unknown=$false
    $output.Clear()
    $failure=''
    try {
        Invoke-PsAiInstaller -Tools claude,fourth,copilot -Source 'example/new-source' -Catalog $catalog -Yes | ForEach-Object { $output.Add($_) }
    } catch { $failure=$_.Exception.Message }
    Assert-True ($failure -match '2.*conflict') 'Multiple conflicts are counted at the end'
    Assert-True (($output -join "`n").Contains('fourth-cli plugin marketplace unregister ps-ai-marketplace')) 'Future tool removal command uses its descriptor'
    Assert-True (($output -join "`n").Contains('Fixture removal hint.')) 'Future tool removal hint uses its descriptor'
    Assert-True (($output -join "`n").Contains('fixture write: copilot|plugin|install')) 'Tools after multiple conflicts still install'

    $state.FailList=$true
    Assert-Throws { Invoke-PsAiInstaller -Tools claude -Source 'example/new-source' -Catalog $catalog -Yes } 'Ordinary listing failures still propagate'
}
