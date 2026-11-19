$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    function Ensure-InstallPowerShell { $true }
    function Get-InstallSourceText { throw 'No network in tests' }
    function copilot { 'fixture-version' }
    function Invoke-ClosedInput {
        param($Command)
        Assert-Equal 'copilot' $Command[0] 'Only fake Copilot commands run'
        return @{ExitCode=0; Output=@()}
    }
    $catalog = Get-InstallCatalog -Source $repo
    $table = Invoke-PsAiInstaller -Tools copilot -Source $repo -Catalog $catalog -Yes | Out-String
    Assert-True ($table.Contains('loaded with plugin')) 'Copilot summary explains hook loading from tool data'
    Assert-True (-not $table.Contains('unknown')) 'Successful Copilot install never reports unknown hooks'
    Assert-Equal 'loaded with plugin' ($catalog.tools | Where-Object id -EQ copilot).hooks.status 'Hook status lives in descriptor data'
}
