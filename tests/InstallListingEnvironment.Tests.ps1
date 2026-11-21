$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/install.ps1') -NoRun
    $script:installCatalog = Get-InstallCatalog -Source $repo
    $realProcess = ${function:Invoke-ClosedInput}
    $saved = [Environment]::GetEnvironmentVariable('CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC', 'Process')
    function Invoke-ClosedInput {
        param($Command, $Environment)
        $json = if ($Command -contains 'marketplace') { '[{"name":"ps-ai-marketplace","source":"github","repo":"BlackGad/ps-ai-marketplace"}]' }
            else { '[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]' }
        $code = 'if ($env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -eq ''1'') { [Console]::Out.Write(''' + $json + ''') } else { [Console]::Out.Write(''[]'') }'
        & $realProcess -Command @('pwsh', '-NoProfile', '-Command', $code) -Environment $Environment
    }
    try {
        $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = '0'
        $commands = Get-InstallCommands -Tool claude -Source 'BlackGad/ps-ai-marketplace'
        foreach ($command in $commands) {
            Assert-True (Test-InstallStepDone -Command $command) 'Both listings receive descriptor environment that suppresses cache-writing background traffic'
            Assert-Equal '0' $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 'Listing environment only affects child process'
        }
    } finally {
        if ($null -eq $saved) { Remove-Item Env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC -ErrorAction SilentlyContinue }
        else { $env:CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = $saved }
    }
}
