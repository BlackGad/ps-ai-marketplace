$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-update.ps1') -NoRun
    function Get-PsAiUpdateHome { Join-Path $repo '.agents/temp/unused' }
    function Get-Content { '{"name":"ps-ai","version":"1.0.0"}' }
    function Get-PsAiUpdateText { '{"name":"ps-ai","version":"1.1.0"}' }
    function New-Item { }
    function Set-Content { }
    $result = Get-PsAiUpdate -Force
    Assert-True ($result.Command.Contains('BlackGad/ps-ai-marketplace/main/install.ps1')) 'Upstream installer URL is used'
    Assert-True ($result.Command.Contains("-Source 'BlackGad/ps-ai-marketplace'")) 'Upstream source reaches the downloaded installer catalog'
}
