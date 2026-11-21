$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome (Join-Path $repo ('.agents/temp/unused-installer-' + [guid]::NewGuid().ToString('N')))
    $catalog = Get-InstallCatalog -Source $repo
    $lines = @'
[
  {
    "id": "ps-ai@ps-ai-marketplace",
    "version": "0.3.0",
    "scope": "user",
    "enabled": true
  }
]
'@ -split "`r?`n"
    $calls = [Collections.Generic.List[string]]::new()
    function Test-InstallCommandAvailable { param($Name) $Name -eq 'claude' }
    function Invoke-InstallRefresh { }
    function Invoke-ClosedInput {
        param($Command)
        $calls.Add(($Command -join '|'))
        if ($Command[2] -eq 'list') { return @{ExitCode=0; Output=$lines} }
        return @{ExitCode=0; Output=@()}
    }
    $script:installCatalog = $catalog
    Assert-True (Test-InstallStepDone -Command @('claude','plugin','install','ps-ai@ps-ai-marketplace')) 'Install detects exact multiline Claude JSON'
    $calls.Clear()
    $output = @(Invoke-PsAiInstaller -Tools claude -ConfigDir selected -Source $repo -Catalog $catalog -Update)
    Assert-Equal 3 $calls.Count 'Update detects exact multiline Claude JSON and runs both refresh commands'
    Assert-True ($calls -contains 'claude|plugin|update|ps-ai@ps-ai-marketplace') 'Installed Claude plugin updates'
    Assert-True (-not (($output -join "`n").Contains('(not installed)'))) 'Installed Claude plugin is never reported missing'

    # Both flows must use the same detection boundary, including config scoping.
    $realDetection = ${function:Test-InstallStepDone}
    $checks = [Collections.Generic.List[string]]::new()
    function Test-InstallStepDone {
        param($Command, $ConfigEnv, $ConfigDir, [switch]$IncludeDisabled)
        $checks.Add("$ConfigEnv|$ConfigDir|$IncludeDisabled")
        & $realDetection -Command $Command -ConfigEnv $ConfigEnv -ConfigDir $ConfigDir
    }
    $null = Invoke-PsAiInstaller -Tools claude -ConfigDir selected -Source $repo -Catalog $catalog -Update
    Assert-Equal 'CLAUDE_CONFIG_DIR|selected|True' ($checks -join '') 'Update uses install detection for multiline JSON, including disabled installed copies'
}
