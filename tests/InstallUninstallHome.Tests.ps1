$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    try {
        # A home that is not the real profile never reaches the real default tool folders.
        $codexFolder = Join-Path $sandbox '.codex'
        $preview = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -DryRun) -join "`n"
        Assert-True ($preview -notmatch 'default config') 'A non-default home never plans the CLI default folder'
        Assert-True ($preview.Contains("Target: codex in $codexFolder")) 'The default folder is under the chosen home'

        $null = Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -Yes
        Assert-True ($writes.Count -gt 0) 'The uninstall ran'
        Assert-Equal 0 @($callEnvironments | Where-Object { $_ -cne "codex=$codexFolder" }).Count 'Every codex call sets CODEX_HOME to the chosen home'

        # Install, update and refresh take their folders from the same list, so none of them gets the CLI default.
        foreach ($tool in $catalog.tools) {
            Assert-Equal (Join-Path $sandbox $tool.plugin.defaultConfigDir.Substring(2)) (@(Get-UpdateConfigDirs -Tool $tool.id)[0]) "$($tool.id) default folder is inside the chosen home"
        }

        # A tool without a folder in that home is skipped, not run against the CLI default.
        $state.Plugin = $true; $state.Marketplace = $true
        $writes.Clear(); $calls.Clear()
        Remove-Item -LiteralPath $codexFolder -Recurse -Force
        $output = @(Invoke-LegionInstaller -Catalog $catalog -Tools codex -Uninstall -Yes)
        Assert-Equal 0 $calls.Count 'A missing folder in the chosen home runs no CLI'
        Assert-True ($output -contains "skip: codex plugin in $codexFolder (not installed)") 'A missing folder is reported as not installed'
    } finally { Remove-UninstallSandbox }
}
