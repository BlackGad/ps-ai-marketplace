$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path $root ('.agents/temp/generated-files-' + [guid]::NewGuid())
$originalWindows = $IsWindows
try {
    . (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
    Set-Variable IsWindows -Value $false -Force
    $script:chmodCalls = 0
    $executableFiles = [Collections.Generic.HashSet[string]]::new()
    function Test-LegionLauncherExecutable { param($Path) return $executableFiles.Contains($Path) }
    function chmod { $script:chmodCalls++; [void]$executableFiles.Add($args[-1]); $global:LASTEXITCODE = 0 }
    function Sync-LegionFoundryRuntime { param($Tool,$HomeRoot,$Changes) Join-Path $tempRoot 'runtime/legion-foundry.ps1' }
    New-Item -ItemType Directory -Path (Join-Path $tempRoot '.legion/bin') -Force | Out-Null
    New-FoundryWrappers -Id fixture -Tool claude -HomeRoot $tempRoot
    Assert-Equal 1 $script:chmodCalls 'A generated shell wrapper is executable'
    New-FoundryWrappers -Id fixture -Tool claude -HomeRoot $tempRoot
    Assert-Equal 1 $script:chmodCalls 'Repeated refresh does not chmod unchanged files'
} finally {
    Set-Variable IsWindows -Value $originalWindows -Force
    if (-not ([IO.Path]::GetFullPath($tempRoot).StartsWith([IO.Path]::GetFullPath((Join-Path $root '.agents/temp/'))))) { throw 'fixture cleanup escaped the worktree' }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
