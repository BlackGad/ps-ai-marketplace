$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$scratch = Join-Path $root ('.agents/temp/legion-output-' + [guid]::NewGuid().ToString('N'))
$standIns = Join-Path $scratch 'bin'
New-Item -ItemType Directory -Path $standIns -Force | Out-Null
$savedExit = $global:LASTEXITCODE
try {
    . (Join-Path $root 'plugins/ps-ai/bin/legion.ps1')
    $script:LegionBin = $standIns

    # The stand-in records whether anything is piped after it, then prints and fails.
    $standInText = @'
param([string]$Repo, [switch]$NoChannel)
Set-Content -LiteralPath (Join-Path (Split-Path $PSScriptRoot -Parent) 'pipeline.txt') -Value $MyInvocation.PipelineLength
Write-Output 'first line'
throw 'script failed'
'@
    Set-Content -LiteralPath (Join-Path $standIns 'legion-overseer.ps1') -Value $standInText

    $lines = @(& { Invoke-Legion -Words @() } 6>&1 | ForEach-Object { "$_" })
    # An interactive CLI must keep the console: nothing may be piped after the script.
    Assert-Equal '1' ((Get-Content -LiteralPath (Join-Path $scratch 'pipeline.txt')).Trim()) 'legion runs the script without capturing its output'
    # Output printed before a throw is still shown.
    Assert-True ($lines -contains 'first line') 'Output before a failure is shown'
    Assert-True ($lines -contains 'script failed') 'The failure message is shown'
} finally {
    $global:LASTEXITCODE = $savedExit
    Remove-Item -LiteralPath $scratch -Recurse -Force -ErrorAction SilentlyContinue
}
