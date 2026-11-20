$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$library = Join-Path $root 'plugins/ps-ai/bin/lib/commands.ps1'
Assert-True (Test-Path -LiteralPath $library) 'Owner-command library exists'
. $library
$commands = Get-PsAiOwnerCommands
Assert-Equal 'ps-ai-setup|ps-ai-status|ps-ai-overseer|legion' ($commands.Keys -join '|') 'Four command names in order'
Assert-Equal 'ps-ai-setup.ps1|ps-ai-status.ps1|ps-ai-overseer.ps1|legion.ps1' ($commands.Values -join '|') 'Command targets'

$scratch = Join-Path $root ('.agents/temp/commands-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratch -Force | Out-Null
$target = Join-Path $scratch "owner's plugin/bin/legion.ps1"
$unix = Get-PsAiShimText -Script $target
. (Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1') -NoRun
$expected = "#!/bin/sh`n" + 'exec pwsh -NoProfile -File ' + (ConvertTo-PsAiShellLiteral $target) + ' "$@"' + "`n"
Assert-Equal $expected $unix 'Unix shim quotes spaces and apostrophes with the shared shell literal'
$windows = Get-PsAiShimText -Script 'C:\plugin folder\bin\legion.ps1' -Windows
Assert-Equal "@pwsh -NoProfile -File `"C:\plugin folder\bin\legion.ps1`" %*`r`n" $windows 'Windows shim quotes the target'

$path = Join-Path $scratch 'legion'
Assert-Equal $false (Test-PsAiOwnerCommandFile -Path $path -Script legion.ps1) 'Missing command is not owned'
foreach ($text in @($unix, $windows, $unix.Replace(' "$@"', ' --extra "$@"'), $windows.Replace(' %*', ' --extra %*'))) {
    [IO.File]::WriteAllText($path, $text)
    Assert-True (Test-PsAiOwnerCommandFile -Path $path -Script legion.ps1) 'Generated and owner-extended shims are recognized'
    Assert-Equal $false (Test-PsAiOwnerCommandFile -Path $path -Script ps-ai-status.ps1) 'Another owner command target does not match'
}
foreach ($text in @('unrelated command', 'pwsh -NoProfile -File "/plugin/legion.ps1"', 'echo "/plugin/bin/legion.ps1"', 'python -File "/plugin/bin/legion.ps1"')) {
    [IO.File]::WriteAllText($path, $text)
    Assert-Equal $false (Test-PsAiOwnerCommandFile -Path $path -Script legion.ps1) 'Unrelated files are not owned'
}
Assert-Equal $false (Test-PsAiOwnerCommandFile -Path $scratch -Script legion.ps1) 'A directory is not an owner command'
