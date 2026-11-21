$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $sandbox = Join-Path $repo ('.agents/temp/update-json-' + [guid]::NewGuid().ToString('N'))
    . (Join-Path $PSScriptRoot 'fixtures/install/InstallerSandbox.ps1') -InstallFixtureHome $sandbox
    $fixturePlugin = New-InstallFixturePlugin -Path (Join-Path $sandbox 'installed')
    $catalog = Get-InstallCatalog -Source $repo
    $lines = @'
[
  {
    "id": "legion@ps-legion-marketplace",
    "version": "0.3.0",
    "scope": "user",
    "enabled": true
  }
]
'@ -split "`r?`n"
    $plugins = ($lines -join "`n") | ConvertFrom-Json
    $plugins[0] | Add-Member installPath $fixturePlugin
    $lines = ConvertTo-Json -InputObject @($plugins) -Depth 10
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
    Assert-True (Test-InstallStepDone -Command @('claude','plugin','install','legion@ps-legion-marketplace')) 'Install detects exact multiline Claude JSON'
    $calls.Clear()
    try {
        $output = @(Invoke-LegionInstaller -Tools claude -ConfigDir selected -Source $repo -Catalog $catalog -Update -Yes)
        Assert-Equal 4 $calls.Count 'Update detects multiline Claude JSON before and after both refresh commands'
        Assert-True ($calls -contains 'claude|plugin|update|legion@ps-legion-marketplace') 'Installed Claude plugin updates'
        Assert-True (-not (($output -join "`n").Contains('(not installed)'))) 'Installed Claude plugin is never reported missing'

        # The shared listing parser must retain disabled plugins and config scoping.
        $realDetection = ${function:Test-InstallListing}
        $checks = [Collections.Generic.List[string]]::new()
        function Test-InstallListing {
            param($Kind, $Tool, $Lines, [switch]$IncludeDisabled)
            $checks.Add("$env:CLAUDE_CONFIG_DIR|$IncludeDisabled")
            & $realDetection -Kind $Kind -Tool $Tool -Lines $Lines -IncludeDisabled:$IncludeDisabled
        }
        $null = Invoke-LegionInstaller -Tools claude -ConfigDir selected -Source $repo -Catalog $catalog -Update -Yes
        Assert-Equal 'selected|True,selected|True' ($checks -join ',') 'Both version lookups use the shared parser and selected config, including disabled copies'
    } finally {
        $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
        if (-not [IO.Path]::GetFullPath($sandbox).StartsWith($allowed)) { throw 'Unsafe JSON fixture cleanup' }
        Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
