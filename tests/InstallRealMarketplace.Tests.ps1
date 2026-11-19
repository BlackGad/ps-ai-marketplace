$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $fixtures = Join-Path $PSScriptRoot 'fixtures/install/listings'
    foreach ($tool in @('claude', 'codex', 'copilot')) {
        $lines = Get-Content (Join-Path $fixtures "$tool-marketplaces.json")
        foreach ($source in @('BlackGad/ps-ai-marketplace', 'https://github.com/blackgad/ps-ai-marketplace.git', 'https://github.com/BlackGad/ps-ai-marketplace/')) {
            Assert-True (Test-InstallListing -Kind marketplace -Tool $tool -Lines $lines -Source $source) "$tool captured source matches GitHub spelling"
        }
        Assert-Throws { Test-InstallListing -Kind marketplace -Tool $tool -Lines $lines -Source 'example/different' } "$tool different recorded source remains a conflict"
        Assert-True (-not (Test-InstallListing -Kind marketplace -Tool $tool -Lines @('[]') -Source 'example/different')) "$tool empty marketplace listing is absent"
        Assert-Throws { Test-InstallListing -Kind marketplace -Tool $tool -Lines @('broken JSON') } "$tool malformed marketplace listing is not absence"
        function Invoke-ClosedInput {
            param($Command)
            Assert-Equal "$tool|plugin|marketplace|list|--json" ($Command -join '|') 'Marketplace detection requests JSON'
            @{ExitCode=0; Output=$lines; ErrorOutput=@('unrelated warning')}
        }
        $command = (Get-InstallCommands -Tool $tool -Source 'BlackGad/ps-ai-marketplace')[0]
        Assert-True (Test-InstallStepDone -Command $command) "$tool detection uses captured JSON through process boundary"
    }
    $lines = Get-Content (Join-Path $fixtures 'codex-marketplaces.json') -Raw | ConvertFrom-Json
    $lines.marketplaces[0].marketplaceSource.source = 'https://github.com/example/different.git'
    Assert-Throws { Test-InstallListing -Kind marketplace -Tool codex -Lines @($lines | ConvertTo-Json -Depth 10) -Source 'BlackGad/ps-ai-marketplace' } 'Matching Codex checkout root cannot override a different Git source'
    $lines.marketplaces[0].marketplaceSource = $null
    Assert-Throws { Test-InstallListing -Kind marketplace -Tool codex -Lines @($lines | ConvertTo-Json -Depth 10) -Source 'BlackGad/ps-ai-marketplace' } 'Checkout root alone cannot prove a Git source'
    Assert-True (Test-InstallListing -Kind marketplace -Tool codex -Lines @($lines | ConvertTo-Json -Depth 10) -Source 'C:/Users/example/.codex/.tmp/marketplaces/ps-ai-marketplace') 'Local registration still compares its recorded root'
    foreach ($invalid in @(@{'bad-name'='1'}, @{FIXTURE_FLAG=$true})) {
        $catalog = Get-InstallCatalog -Source $repo
        $catalog.tools[0].plugin.listingEnv = $invalid
        Assert-Throws { Get-InstallCatalog -Catalog $catalog } 'Invalid listing environment is rejected before any process starts'
    }
}
