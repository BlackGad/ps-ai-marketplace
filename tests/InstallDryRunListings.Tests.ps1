$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $catalog = Get-InstallCatalog -Source $repo
    $fixtures = Join-Path $PSScriptRoot 'fixtures/install/listings'
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
            else { @('ps-ai@ps-ai-marketplace installed, enabled 0.3.1') }
        @{ExitCode=0; Output=$output; ErrorOutput=@()}
    }
    $preview = @(Invoke-PsAiInstaller -Catalog $catalog -DryRun)
    Assert-Equal 6 $calls.Count 'Install DryRun reads marketplaces and installed plugins for all three tools'
    Assert-Equal 6 @($preview | Where-Object { $_ -match '^skip: .*already done' }).Count 'Install DryRun proves matching sources and enabled plugins'
    $calls.Clear()
    $preview = @(Invoke-PsAiInstaller -Catalog $catalog -Update -DryRun)
    Assert-Equal 3 $calls.Count 'Update DryRun checks installed state for every tool'
    Assert-True ($preview -contains 'claude plugin update ps-ai@ps-ai-marketplace') 'Update DryRun detects captured Claude user plugin'
    function Invoke-ClosedInput { @{ExitCode=0; Output=@('[]'); ErrorOutput=@()} }
    $preview = @(Invoke-PsAiInstaller -Tools claude -Catalog $catalog -Update -DryRun)
    Assert-True (($preview -join "`n").Contains('(not installed)')) 'Update DryRun reports absent plugins accurately'
    Assert-True (-not ($preview -contains 'claude plugin update ps-ai@ps-ai-marketplace')) 'Update DryRun never proposes updating absent plugin'
}
