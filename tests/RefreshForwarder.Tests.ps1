$repo = Split-Path $PSScriptRoot -Parent
$refresh = Join-Path $repo 'plugins/legion/bin/legion-refresh.ps1'
$pwsh = (Get-Command pwsh -CommandType Application).Source
$savedPath = $env:PATH
$homeRoot = Join-Path $HOME 'refresh-no-uv'
try {
    $env:PATH = Split-Path $pwsh -Parent
    $output = @(& $pwsh -NoProfile -File $refresh -HomeRoot $homeRoot 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Refresh without uv exits successfully'
    Assert-Equal 'uv is missing. Ask the owner before installing it.' ($output -join "`n") 'Refresh without uv prints one warning'
} finally {
    $env:PATH = $savedPath
}
