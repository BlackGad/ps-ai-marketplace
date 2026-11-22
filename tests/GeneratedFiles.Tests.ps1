$ErrorActionPreference = 'Stop'
if ($IsWindows) { Write-Output 'skip generated wrapper modes: Unix file modes only'; return }
$root = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path $root ('.agents/temp/generated-files-' + [guid]::NewGuid())
try {
    . (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
    # Modes are set through .NET; the chmod command must never run.
    function chmod { throw 'The chmod command was used' }
    function Sync-LegionFoundryRuntime { param($Tool,$HomeRoot,$Changes) Join-Path $tempRoot 'runtime/legion-foundry.ps1' }
    New-Item -ItemType Directory -Path (Join-Path $tempRoot '.legion/bin') -Force | Out-Null
    $changes = [Collections.Generic.List[string]]::new()
    New-FoundryWrappers -Id fixture -Tool claude -HomeRoot $tempRoot -Changes $changes
    $wrapper = Join-Path $tempRoot '.legion/bin/fixture'
    Assert-True (([IO.File]::GetUnixFileMode($wrapper) -band [IO.UnixFileMode]::UserExecute) -ne 0) 'A generated shell wrapper is executable'
    $changes.Clear()
    New-FoundryWrappers -Id fixture -Tool claude -HomeRoot $tempRoot -Changes $changes
    Assert-Equal 0 $changes.Count 'Repeated refresh changes nothing'
} finally {
    if (-not ([IO.Path]::GetFullPath($tempRoot).StartsWith([IO.Path]::GetFullPath((Join-Path $root '.agents/temp/'))))) { throw 'fixture cleanup escaped the worktree' }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
