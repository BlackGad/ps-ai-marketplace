$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $fourth = Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/legion-fourth/tool.json') -Raw | ConvertFrom-Json
    $script:installCatalog.tools += $fourth
    foreach ($entry in $script:installCatalog.tools) {
        $state = @{ Added=$false }
        $writes = [Collections.Generic.List[string]]::new()
        function Invoke-ClosedInput {
            param($Command)
            Assert-Equal 'selected account' ([Environment]::GetEnvironmentVariable($entry.configEnv, 'Process')) 'Every step uses selected config'
            $line = $Command -join '|'
            if ($line -ceq ((@($entry.command) + $entry.plugin.marketplaceList) -join '|')) {
                $source = if ($state.Added) { 'example/new-source' } else { '' }
                $output = @(Get-FixtureMarketplaceListing -Tool $entry.id -Source $source)
                return @{ExitCode=0; Output=$output}
            }
            if ($line -ceq ((@($entry.command) + $entry.plugin.list) -join '|')) {
                $output = if ($entry.plugin.listing.format -eq 'json') { @('[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]') }
                    else { @('ps-ai@ps-ai-marketplace installed, enabled') }
                return @{ExitCode=0; Output=$output}
            }
            $writes.Add($line)
            if ($Command -contains 'example/new-source' -or $Command -contains 'example/new-source#stable') { $state.Added=$true }
            return @{ExitCode=0; Output=@()}
        }
        $null = Invoke-LegionInstallSteps -Tool $entry.id -Source 'example/new-source' -ConfigEnv $entry.configEnv -ConfigDir 'selected account'
        Assert-True ($writes -contains ((@($entry.command) + $entry.plugin.install) -join '|')) "$($entry.id) newly added marketplace reinstalls an existing cached plugin"
        Assert-Equal 3 $writes.Count "$($entry.id) runs add, refresh and install from descriptor"
        Assert-Equal ((@($entry.command) + $entry.plugin.marketplaceUpdate) -join '|') $writes[1] 'Refresh uses tool data'
        $writes.Clear()
        $repeat = @(Invoke-LegionInstallSteps -Tool $entry.id -Source 'example/new-source' -ConfigEnv $entry.configEnv -ConfigDir 'selected account')
        Assert-Equal 0 $writes.Count 'Matching marketplace and installed plugin remain idempotent'
        Assert-Equal 2 @($repeat | Where-Object { $_ -match '^skip: ' }).Count 'Repeat skips both steps'
    }
}
