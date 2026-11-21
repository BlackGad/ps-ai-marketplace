$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$refresh = Join-Path $root 'plugins/ps-ai/bin/ps-ai-refresh.ps1'
$setup = Join-Path $root 'plugins/ps-ai/bin/ps-ai-setup.ps1'
$tempRoot = Join-Path $root ('.agents/temp/retired-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    . (Join-Path $root 'plugins/ps-ai/bin/lib/commands.ps1')
    $retired = @('ps-ai-setup', 'ps-ai-status', 'ps-ai-overseer')

    function New-RetiredHome {
        param([string]$Name)
        $home1 = Join-Path $tempRoot $Name
        $bin = Join-Path $home1 '.legion/bin'
        New-Item -ItemType Directory -Path $bin -Force | Out-Null
        foreach ($command in $retired) {
            $runner = Join-Path $root "plugins/ps-ai/bin/$command.ps1"
            [IO.File]::WriteAllText((Join-Path $bin $command), (Get-LegionShimText -Script $runner -HomeRoot $home1))
            [IO.File]::WriteAllText((Join-Path $bin "$command.cmd"), (Get-LegionShimText -Script $runner -Windows -HomeRoot $home1))
        }
        return $home1
    }

    # Refresh removes generated copies (sh and .cmd), keeps edited ones and names them, then skips.
    $refreshHome = New-RetiredHome 'refresh home'
    $refreshBin = Join-Path $refreshHome '.legion/bin'
    $edited = Join-Path $refreshBin 'ps-ai-status'
    [IO.File]::WriteAllText($edited, "#!/bin/sh`necho mine`n")
    $flagged = Join-Path $refreshBin 'ps-ai-overseer'
    [IO.File]::WriteAllText($flagged, (Get-LegionShimText -Script (Join-Path $root 'plugins/ps-ai/bin/ps-ai-overseer.ps1') -HomeRoot $refreshHome).Replace(' "$@"', ' -Account mine "$@"'))
    $first = @(& $refresh -HomeRoot $refreshHome)
    foreach ($name in @('ps-ai-setup', 'ps-ai-setup.cmd', 'ps-ai-status.cmd', 'ps-ai-overseer.cmd')) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $refreshBin $name))) "Refresh removes generated $name"
        Assert-True ([bool]($first -like "removed: old command $name *")) "Refresh reports removing $name"
    }
    Assert-Equal "#!/bin/sh`necho mine`n" ([IO.File]::ReadAllText($edited)) 'Refresh keeps an edited old command'
    Assert-True ([bool]($first -like "manual step: delete $edited *")) 'Refresh names the edited old command as a manual step'
    Assert-True (Test-Path -LiteralPath $flagged) 'Refresh keeps an old command that carries owner flags'
    Assert-True ([bool]($first -like "manual step: delete $flagged *")) 'Refresh names the flagged old command as a manual step'
    Assert-True (-not [bool](@($first) -like 'removed: old command ps-ai-status *')) 'Refresh never reports the edited command as removed'
    $names = @(Get-ChildItem -LiteralPath $refreshBin -File | ForEach-Object Name | Sort-Object)
    Assert-True ($names -contains 'legion') 'Refresh writes legion'
    Assert-Equal @() @($names | Where-Object { $_ -match '^ps-ai-' -and $_ -notin @('ps-ai-status', 'ps-ai-overseer') }) 'Refresh leaves only the kept old commands'

    # A clean home: refresh writes only legion and a second run skips.
    $cleanHome = New-RetiredHome 'clean home'
    Remove-Item -Path (Join-Path $cleanHome '.legion/bin/*') -Force
    & $refresh -HomeRoot $cleanHome | Out-Null
    $cleanNames = @(Get-ChildItem -LiteralPath (Join-Path $cleanHome '.legion/bin') -File | ForEach-Object Name)
    $expected = if ($IsWindows) { @('legion', 'legion.cmd') } else { @('legion') }
    Assert-Equal ($expected -join '|') (($cleanNames | Sort-Object) -join '|') 'Refresh writes only legion (and .cmd on Windows)'
    $second = @(& $refresh -HomeRoot $cleanHome)
    Assert-True ([bool]($second -match '^skip: .*\(already done\)$')) 'A second refresh prints skip'

    # Setup -Yes removes the same way and prints skip: on the second run (machine seams are inert).
    $setupHome = New-RetiredHome 'setup home'
    $homeBin = Join-Path $setupHome '.legion/bin'
    & {
        . $setup -NoRun
        function Get-SetupUserPath { return 'fixture-path' }
        function Set-SetupUserPath { param($Value) }
        $plan = @(Invoke-Setup -HomeRoot $setupHome)
        Assert-True ((($plan -join "`n")).Contains('remove   old commands ps-ai-setup')) 'Setup plan names the old commands it will remove'
        Assert-True (Test-Path -LiteralPath (Join-Path $homeBin "ps-ai-setup")) 'The plan alone removes nothing'
        $applied = @(Invoke-Setup -HomeRoot $setupHome -Yes)
        foreach ($command in $retired) {
            Assert-True (-not (Test-Path -LiteralPath (Join-Path $homeBin $command))) "Setup removes generated $command"
            Assert-True ([bool]($applied -like "removed: old command $command *")) "Setup reports removing $command"
        }
        Assert-True (Test-Path -LiteralPath (Join-Path $homeBin 'legion')) 'Setup writes legion'
        $again = @(Invoke-Setup -HomeRoot $setupHome -Yes)
        Assert-True ($again -contains 'skip: old commands (already done)') 'A second setup prints skip for the old commands'
    }} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
