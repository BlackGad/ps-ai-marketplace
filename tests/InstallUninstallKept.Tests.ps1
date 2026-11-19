$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $PSScriptRoot 'fixtures/install/UninstallSandbox.ps1')
    try {
        $state.Plugin=$false; $state.Marketplace=$false
        $output = @(Invoke-PsAiInstaller -Catalog $catalog -ConfigDir (Join-Path $sandbox 'missing') -Uninstall -Yes)
        Assert-Equal 0 @($output | Where-Object { $_ -match '^Kept .*: ' }).Count 'No nonexistent paths in kept summary'
        $configuration = Join-Path $sandbox '.agents/configuration'
        $account = Join-Path $sandbox 'custom account'
        New-Item -ItemType Directory -Path $configuration, $account -Force | Out-Null
        $output = @(Invoke-PsAiInstaller -Catalog $catalog -ConfigDir $account -Uninstall -Yes)
        Assert-True ($output -contains "Kept settings and notes: $configuration") 'Existing settings directory is listed'
        Assert-True ($output -contains "Kept config folder and login: $account") 'Existing explicit config is listed'
        Assert-Equal 2 @($output | Where-Object { $_ -match '^Kept .*: ' }).Count 'Only existing paths are listed'
    } finally { Remove-UninstallSandbox }
}
