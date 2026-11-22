. (Join-Path $PSScriptRoot 'lib/paths.ps1')
$ErrorActionPreference = 'Stop'
if ($IsWindows) { Write-Output 'skip generated wrapper modes: Unix file modes only'; return }
$root = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path $root ('.agents/temp/generated-files-' + [guid]::NewGuid())
try {
    . (Join-Path $root 'plugins/legion/bin/lib/accounts.ps1')
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
    Remove-TestFolder -Path $tempRoot -AllowedParent (Join-Path $root '.agents/temp')
}
