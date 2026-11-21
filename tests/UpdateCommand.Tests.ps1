$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/legion/bin/legion-update.ps1') -NoRun
    function Get-LegionUpdateHome { Join-Path $repo '.agents/temp/unused' }
    function Get-Content { '{"name":"legion","version":"1.0.0"}' }
    function Get-LegionUpdateText { '{"name":"legion","version":"1.1.0"}' }
    function New-Item { }
    function Set-Content { }
    $result = Get-LegionUpdate -Force
    Assert-Equal 'legion update' $result.Command 'UpdateCommandIsLegion'
}
