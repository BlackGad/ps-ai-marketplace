$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $fixtures = Join-Path $PSScriptRoot 'fixtures/install/listings'
    foreach ($tool in @('claude', 'codex', 'copilot')) {
        $lines = Get-Content (Join-Path $fixtures "$tool-marketplaces.json")
        Assert-True (Test-InstallListing -Kind marketplace -Tool $tool -Lines $lines) "$tool captured JSON identifies the marketplace"
        Assert-True (-not (Test-InstallListing -Kind marketplace -Tool $tool -Lines @('[]'))) "$tool empty listing is absent"
        Assert-Throws { Test-InstallListing -Kind marketplace -Tool $tool -Lines @('broken JSON') } "$tool malformed listing is not absence"
        function Invoke-ClosedInput {
            param($Command)
            Assert-Equal "$tool|plugin|marketplace|list|--json" ($Command -join '|') 'Marketplace detection requests JSON'
            @{ExitCode=0; Output=$lines; ErrorOutput=@('unrelated warning')}
        }
        $command = (Get-InstallCommands -Tool $tool -Source 'example/requested-source')[0]
        Assert-True (Test-InstallStepDone -Command $command -Kind marketplace) "$tool existing registration is reused regardless of source"
    }
    foreach ($invalid in @(@{'bad-name'='1'}, @{FIXTURE_FLAG=$true})) {
        $catalog = Get-InstallCatalog -Source $repo
        $catalog.tools[0].plugin.listingEnv = $invalid
        Assert-Throws { Get-InstallCatalog -Catalog $catalog } 'Invalid listing environment is rejected before any process starts'
    }
}
