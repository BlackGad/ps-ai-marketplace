$repo = Split-Path $PSScriptRoot -Parent
$refresh = Join-Path $repo 'plugins/legion/bin/legion-refresh.ps1'
$pwsh = (Get-Process -Id $PID).Path
$savedPath = $env:PATH
$homeRoot = Join-Path $HOME 'refresh-no-uv'
$emptyPath = Join-Path ([IO.Path]::GetTempPath()) ('refresh-no-uv-path-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $emptyPath | Out-Null
try {
    # An empty folder: a uv that sits beside pwsh (Homebrew, /usr/bin) must never be found.
    $env:PATH = $emptyPath
    $output = @(& $pwsh -NoProfile -File $refresh -HomeRoot $homeRoot 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Refresh without uv exits successfully'
    Assert-Equal 'uv is missing. Ask the owner before installing it.' ($output -join "`n") 'Refresh without uv prints one warning'
} finally {
    $env:PATH = $savedPath
    Remove-Item -LiteralPath $emptyPath -Force
}
