$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-update.ps1') -NoRun
    function Get-PsAiUpdateHome { Join-Path $repo '.agents/temp/unused' }
    function Get-Content { '{"name":"ps-ai","version":"1.0.0"}' }
    function Get-PsAiUpdateText { '{"name":"ps-ai","version":"1.1.0"}' }
    function New-Item { }
    function Set-Content { }
    $result = Get-PsAiUpdate -Force
    Assert-Equal 'legion update' $result.Command 'UpdateCommandIsLegion'
}
