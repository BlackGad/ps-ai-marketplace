$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-update.ps1') -NoRun
    function Get-PsAiUpdateSource { 'example/fork' }
    function Get-PsAiUpdateHome { Join-Path $repo '.agents/temp/unused' }
    function Get-Content { '{"name":"ps-ai","version":"1.0.0"}' }
    function Get-PsAiUpdateText { '{"name":"ps-ai","version":"1.1.0"}' }
    function New-Item { }
    function Set-Content { }
    $result = Get-PsAiUpdate -Force
    Assert-True ($result.Command.Contains('example/fork/main/install.ps1')) 'Fork installer URL is retained'
    Assert-True ($result.Command.Contains("-Source 'example/fork'")) 'Fork source reaches the downloaded installer catalog'
}
