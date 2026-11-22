$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $listing = Read-InstallPluginListing -Entry (Get-InstallTool claude) -Lines @('[{"id":"legion@ps-legion-marketplace","enabled":false,"installPath":"/absent/plugin","version":"0.8.0"}]')
    Assert-True $listing.Listed 'One parse finds the disabled installed plugin'
    Assert-True (-not $listing.Enabled) 'One parse retains disabled state'
    Assert-Equal '/absent/plugin' $listing.Path 'Listing parser returns a path without touching disk'
    Assert-Equal '0.8.0' $listing.Version 'One parse retains the listed version'
    $listing = Read-InstallPluginListing -Entry (Get-InstallTool copilot) -Lines @('legion@ps-legion-marketplace (v0.8.0) (disabled)', '    from /absent/marketplace')
    Assert-True $listing.Listed 'Text listing finds disabled plugins'
    Assert-True (-not $listing.Enabled) 'Text listing retains disabled state'
    Assert-Equal '/absent/marketplace' $listing.MarketplacePath 'Live marketplace path stays unresolved until needed'
    Assert-Equal '0.8.0' $listing.Version 'Text version is parsed with the plugin'
    # Launch only an inert PowerShell fixture; never a real coding CLI.
    $result = Invoke-ClosedInput -Command @('pwsh', '-NoProfile', '-Command', '[Console]::Out.Write(''[{"id":"legion@ps-legion-marketplace","enabled":true}]''); [Console]::Error.WriteLine(''fixture warning'')')
    Assert-Equal '[{"id":"legion@ps-legion-marketplace","enabled":true}]' ($result.Output -join "`n") 'Listing stdout excludes stderr warning'
    Assert-Equal 'fixture warning' ($result.ErrorOutput -join "`n") 'CLI stderr is retained separately'
    Assert-True (Test-InstallListing -Kind plugin -Tool claude -Lines $result.Output) 'Valid JSON remains installed with a stderr warning'
    function Invoke-ClosedInput { @{ExitCode=7; Output=@()} }
    Assert-Throws { Test-InstallStepDone -Command @('claude','plugin','install','legion@ps-legion-marketplace') } 'Initial install listing failure is distinct from absence'
    function Invoke-ClosedInput { @{ExitCode=7; Output=@('  fixture stdout  '); ErrorOutput=@('  fixture stderr  ')} }
    $message = ''
    try { Test-InstallStepDone -Command @('claude','plugin','install','legion@ps-legion-marketplace') }
    catch { $message = $_.Exception.Message }
    Assert-Equal "claude listing exited 7`nfixture stderr`nfixture stdout" $message 'Listing failure includes trimmed stderr and stdout'
    Assert-Throws { Test-InstallListing -Kind plugin -Tool claude -Lines @('invalid JSON') } 'Malformed successful listing is a failure, not absent plugin'
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @('[]'))) 'Valid empty JSON is absent plugin'
}
