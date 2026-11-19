$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
$originalWindows = $IsWindows
try {
    . (Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1') -NoRun -HomeRoot $tempRoot
    Set-Variable IsWindows -Value $false -Force
    $script:chmodCalls = 0
    function chmod { $script:chmodCalls++; $global:LASTEXITCODE = 0 }
    function Sync-PsAiFoundryRuntime { param($Tool,$HomeRoot,$Changes) Join-Path $tempRoot 'runtime/ps-ai-foundry.ps1' }
    New-Item -ItemType Directory -Path (Join-Path $tempRoot '.agents/bin') -Force | Out-Null
    New-FoundryWrappers -Id fixture -Tool claude -HomeRoot $tempRoot
    Assert-Equal 1 $script:chmodCalls 'A generated shell wrapper is executable'
    New-FoundryWrappers -Id fixture -Tool claude -HomeRoot $tempRoot
    Assert-Equal 1 $script:chmodCalls 'Repeated refresh does not chmod unchanged files'
} finally {
    Set-Variable IsWindows -Value $originalWindows -Force
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
