$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    try {
        $state.Plugin=$false; $state.Marketplace=$false
        $output = @(Invoke-PsAiInstaller -Catalog $catalog -Uninstall)
        Assert-Equal 0 $state.Prompts 'Empty uninstall never asks'
        Assert-True ($output -contains 'Nothing to uninstall.') 'Empty uninstall explains no work'
        Assert-Equal 0 @($output | Where-Object { $_ -match 'plugin (uninstall|remove|marketplace remove)' }).Count 'Empty uninstall has no command plan'
        Assert-Equal 6 @($output | Where-Object { $_ -match '^skip: .* (plugin|marketplace) in ' }).Count 'Empty uninstall reports all absent steps'

        foreach ($plugin in @($false, $true)) {
            $state.Plugin=$plugin; $state.Marketplace=-not $plugin
            $preview = @(Invoke-PsAiInstaller -Catalog $catalog -Tools codex -ConfigDir selected -Uninstall -DryRun)
            $commands = @($preview | Where-Object { $_ -match 'codex plugin (remove|marketplace remove)' })
            Assert-Equal 1 $commands.Count 'Preview only lists installed steps'
            $expected = if ($plugin) { 'codex plugin remove ps-ai@ps-ai-marketplace' } else { 'codex plugin marketplace remove ps-ai-marketplace' }
            Assert-True ($commands[0].EndsWith($expected)) 'Preview selects the installed step'
            Assert-Equal 0 $writes.Count 'Preview only reads'
        }
        $state.Plugin=$true; $state.Marketplace=$true
        $declined = @(Invoke-PsAiInstaller -Catalog $catalog -Tools codex -Uninstall)
        Assert-Equal 1 $state.Prompts 'Nonempty uninstall asks once'
        Assert-True ($calls.Count -gt 0) 'Detection happens before asking'
        Assert-Equal 0 $writes.Count 'Declining preserves installed state'

        $records = Join-Path $sandbox '.agents/configuration/ps-ai-personalisation.json'
        New-Item -ItemType Directory -Path (Split-Path $records) -Force | Out-Null
        @{agents=@(@{id='codex-a';tool='codex';configDir='~/.codex';command='external-command'})} | ConvertTo-Json | Set-Content -LiteralPath $records
        $preview = @(Invoke-PsAiInstaller -Catalog $catalog -Tools codex -Uninstall -DryRun)
        Assert-Equal 1 @($preview | Where-Object { $_ -match '^Target:' }).Count 'Recorded default config is planned once'
        Assert-Equal 2 @($preview | Where-Object { $_ -match 'codex plugin (remove|marketplace remove)' }).Count 'Default alias does not duplicate commands'
        $null = Invoke-PsAiInstaller -Catalog $catalog -Tools codex -Uninstall -Yes
        Assert-Equal 2 $writes.Count 'Default alias is uninstalled once'
    } finally { Remove-UninstallSandbox }
}
