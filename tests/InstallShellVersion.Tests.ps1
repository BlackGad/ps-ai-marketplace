$root = Split-Path $PSScriptRoot -Parent
$shell = [IO.File]::ReadAllText((Join-Path $root 'install.sh'))
$probe = [regex]::Match($shell, '-Command ''([^'']+)''').Groups[1].Value
Assert-True ([bool]$probe) 'Shell launcher has a PowerShell version probe'
foreach ($case in @(
    @{ Version='7.0.0'; Exit=1 }, @{ Version='7.3.9'; Exit=1 },
    @{ Version='7.4.0'; Exit=0 }, @{ Version='7.9.0'; Exit=0 }, @{ Version='8.0.0'; Exit=0 }
)) {
    $expression = $probe.Replace('$PSVersionTable.PSVersion', "([version]'$($case.Version)')")
    & pwsh -NoProfile -Command $expression
    Assert-Equal $case.Exit $LASTEXITCODE "Shell version probe accepts 7.4 or newer: $($case.Version)"
}
