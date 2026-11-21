$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $fixtures = Join-Path $PSScriptRoot 'fixtures/install/listings'
    $sandbox = Join-Path $repo ('.agents/temp/dry-listings-' + [guid]::NewGuid().ToString('N'))
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed') -Version '0.3.0'
    $calls = [Collections.Generic.List[string]]::new()
    function Ensure-InstallPowerShell { $true }
    function Test-InstallCommandAvailable { $true }
    function Get-UpdateConfigDirs { ,@('') }
    function Invoke-ClosedInput {
        param($Command)
        if ($Command -notcontains 'list') { throw 'DryRun attempted a write or version command' }
        $calls.Add(($Command -join '|'))
        $file = if ($Command -contains 'marketplace') { "$($Command[0])-marketplaces.json" } else { 'claude-plugins.json' }
        $output = if ($Command -contains 'marketplace' -or $Command[0] -eq 'claude') { Get-Content (Join-Path $fixtures $file) }
            else { @("ps-ai@ps-ai-marketplace installed, enabled 0.3.0 $fixturePlugin") }
        if ($Command[0] -eq 'claude' -and $Command -notcontains 'marketplace') {
            $plugins = ($output -join "`n") | ConvertFrom-Json
            foreach ($plugin in $plugins) { $plugin | Add-Member installPath $fixturePlugin -Force }
            $output = @(ConvertTo-Json -InputObject @($plugins) -Depth 10)
        }
        if ($Command[0] -eq 'codex' -and $Command -contains 'marketplace') {
            $listing = ($output -join "`n") | ConvertFrom-Json
            $listing.marketplaces[0].root = $fixtures
            $output = @($listing | ConvertTo-Json -Depth 10)
        }
        @{ExitCode=0; Output=$output; ErrorOutput=@()}
    }
    try {
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -DryRun)
        Assert-Equal 7 $calls.Count 'Install DryRun reads registrations, checkout health and installed plugins'
        Assert-Equal 6 @($preview | Where-Object { $_ -match '^skip: .*already done' }).Count 'Install DryRun proves matching sources and enabled plugins'
        $calls.Clear()
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Update -DryRun)
        Assert-Equal 3 $calls.Count 'Update DryRun checks installed state for every tool'
        Assert-True ($preview -contains 'claude plugin update ps-ai@ps-ai-marketplace') 'Update DryRun detects captured Claude user plugin'
        function Invoke-ClosedInput { @{ExitCode=0; Output=@('[]'); ErrorOutput=@()} }
        $preview = @(Invoke-LegionInstaller -Tools claude -Catalog $catalog -Update -DryRun)
        Assert-True ($preview -contains 'claude plugin marketplace add BlackGad/ps-ai-marketplace#stable') 'Update DryRun proposes registering missing marketplace'
        Assert-True ($preview -contains 'claude plugin install ps-ai@ps-ai-marketplace') 'Update DryRun proposes installing absent plugin'
        Assert-True (-not ($preview -contains 'claude plugin update ps-ai@ps-ai-marketplace')) 'Update DryRun never proposes updating absent plugin'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe listing fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
