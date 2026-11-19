$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $script:installCatalog.tools += Get-Content (Join-Path $PSScriptRoot 'fixtures/tools/ps-ai-fourth/tool.json') -Raw | ConvertFrom-Json
    function Invoke-ClosedInput { @{ExitCode=0; Output=@('ps-ai-marketplace https://github.com/example/old-source')} }
    $command = @('fourth-cli','plugin','marketplace','add','example/requested-source')
    Assert-Throws { Test-InstallStepDone -Command $command } 'Existing marketplace with different source is a conflict'
    $command[-1] = 'example/old-source'
    Assert-True (Test-InstallStepDone -Command $command) 'Same GitHub source counts as already registered'
    function Invoke-ClosedInput { @{ExitCode=0; Output=@('  ❯ ps-ai-marketplace', '    Source: GitHub (example/old-source)')} }
    Assert-True (Test-InstallStepDone -Command $command) 'Multiline GitHub source is compared'
    Assert-True (Test-InstallListing -Kind marketplace -Lines @('ps-ai-marketplace C:\fixture\local source') -Source 'C:/fixture/local source') 'Local source with spaces is compared as one path'
    function Invoke-ClosedInput { @{ExitCode=0; Output=@('ps-ai-marketplace')} }
    Assert-Throws { Test-InstallStepDone -Command $command } 'Unknown registered source cannot silently count as requested source'
    function Invoke-ClosedInput { @{ExitCode=0; Output=@('other-marketplace https://github.com/example/other')} }
    Assert-True (-not (Test-InstallStepDone -Command $command)) 'Absent marketplace can be installed'
}
