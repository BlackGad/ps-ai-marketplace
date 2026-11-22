$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $realProcess = ${function:Invoke-ClosedInput}
    $saved = [Environment]::GetEnvironmentVariable('CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC', 'Process')
    $savedConfig = $env:CLAUDE_CONFIG_DIR
    $folder = Join-Path $env:HOME 'listing account'
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    function Invoke-ClosedInput {
        param($Command, $Environment)
        $json = if ($Command -contains 'marketplace') { '[{"name":"ps-legion-marketplace","source":"github","repo":"BlackGad/ps-legion-marketplace"}]' }
            else { '[{"id":"legion@ps-legion-marketplace","enabled":true}]' }
        Assert-Equal $savedConfig $env:CLAUDE_CONFIG_DIR 'Listing leaves parent config unchanged while the child runs'
        $configCheck = if ($Environment.CLAUDE_CONFIG_DIR) { '$env:CLAUDE_CONFIG_DIR -ceq ''' + $folder.Replace("'", "''") + "'" }
            else { '-not (Test-Path Env:CLAUDE_CONFIG_DIR)' }
        $code = 'if ($env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -eq ''1'' -and (' + $configCheck + ')) { [Console]::Out.Write(''' + $json + ''') } else { [Console]::Out.Write(''[]'') }'
        & $realProcess -Command @('pwsh', '-NoProfile', '-Command', $code) -Environment $Environment
    }
    try {
        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '0'
        $commands = Get-InstallCommands -Tool claude -Source 'BlackGad/ps-legion-marketplace'
        foreach ($target in @('', $folder)) {
            for ($index = 0; $index -lt $commands.Count; $index++) {
                $kind = if ($index -eq 0) { 'marketplace' } else { 'plugin' }
                Assert-True (Test-InstallStepDone -Command $commands[$index] -Kind $kind -ConfigDir $target) 'Both listings merge config and descriptor environment in the child'
                Assert-Equal '0' $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 'Listing environment only affects child process'
            }
        }
        Assert-True (-not $script:installCatalog.tools[0].plugin.listingEnv.PSObject.Properties['CLAUDE_CONFIG_DIR']) 'Merging never changes the catalog environment'
    } finally {
        if ($null -eq $saved) { Remove-Item Env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = $saved }
    }
}
