$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    # Launch only an inert PowerShell fixture; never a real coding CLI.
    $result = Invoke-ClosedInput -Command @('pwsh', '-NoProfile', '-Command', '[Console]::Out.Write(''[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]''); [Console]::Error.WriteLine(''fixture warning'')')
    Assert-Equal '[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]' ($result.Output -join "`n") 'Listing stdout excludes stderr warning'
    Assert-Equal 'fixture warning' ($result.ErrorOutput -join "`n") 'CLI stderr is retained separately'
    Assert-True (Test-InstallListing -Kind plugin -Tool claude -Lines $result.Output) 'Valid JSON remains installed with a stderr warning'
    function Invoke-ClosedInput { @{ExitCode=7; Output=@()} }
    Assert-Throws { Test-InstallStepDone -Command @('claude','plugin','install','ps-ai@ps-ai-marketplace') } 'Initial install listing failure is distinct from absence'
    Assert-Throws { Test-InstallListing -Kind plugin -Tool claude -Lines @('invalid JSON') } 'Malformed successful listing is a failure, not absent plugin'
    Assert-True (-not (Test-InstallListing -Kind plugin -Tool claude -Lines @('[]'))) 'Valid empty JSON is absent plugin'
}
