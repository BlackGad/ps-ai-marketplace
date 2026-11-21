$repo = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'fixtures/install/MarketplaceListing.ps1')
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome (Join-Path $repo ('.agents/temp/unused-installer-' + [guid]::NewGuid().ToString('N')))
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path (Get-InstallHome) 'installed')
    function Invoke-InstallRefresh { }
    function Invoke-ClosedInput {
        param($Command)
        Assert-Equal 'copilot' $Command[0] 'Only fake Copilot commands run'
        if ($Command -contains 'list') {
            $listing = if ($Command -contains 'marketplace') { Get-FixtureMarketplaceListing -Tool copilot } else { "ps-ai@ps-ai-marketplace installed (enabled) $fixturePlugin" }
            return @{ExitCode=0; Output=@($listing)}
        }
        return @{ExitCode=0; Output=@()}
    }
    $catalog = Get-InstallCatalog -Source $repo
    $table = Invoke-LegionInstaller -Tools copilot -Source $repo -Catalog $catalog -Yes | Out-String
    Assert-True ($table.Contains('loaded with plugin')) 'Copilot summary explains hook loading from tool data'
    Assert-True (-not $table.Contains('unknown')) 'Successful Copilot install never reports unknown hooks'
    Assert-Equal 'loaded with plugin' ($catalog.tools | Where-Object id -EQ copilot).hooks.status 'Hook status lives in descriptor data'
}
