$repo = Split-Path $PSScriptRoot -Parent
& {
    . (Join-Path $repo 'install.ps1') -NoRun
    . (Join-Path $repo 'plugins/ps-ai/bin/ps-ai-install-tool.ps1') -NoRun
    $ProgressPreference = 'Continue'
    function Invoke-WebRequest {
        param($Uri, $OutFile, [switch]$UseBasicParsing, $ErrorAction)
        Assert-Equal 'SilentlyContinue' $ProgressPreference 'Downloads suppress progress inside their function scope'
        @{Content='fixture catalog'}
    }
    Assert-Equal 'fixture catalog' (Get-InstallSourceText -Url 'https://fixture.test/catalog') 'Source download still returns content'
    $null = Invoke-InstallDownload -Url 'https://fixture.test/bootstrap' -OutFile unused
    $null = Invoke-ToolDownload -Url 'https://fixture.test/tool' -OutFile unused
    Assert-Equal 'Continue' $ProgressPreference 'Downloads preserve caller progress preference'
}
