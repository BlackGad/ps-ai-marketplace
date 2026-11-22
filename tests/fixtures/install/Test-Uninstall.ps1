param([string]$Installer, [string]$Catalog)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MarketplaceListing.ps1')
$catalogText = Get-Content -LiteralPath $Catalog -Raw
$fixtureHome = Join-Path (Split-Path $Catalog) 'home'
. $Installer -NoRun
. (Join-Path $PSScriptRoot 'InstallerSandbox.ps1') -InstallFixtureHome ($fixtureHome)
function Get-InstallSourceText { $catalogText }
function Ensure-InstallPowerShell { throw 'Uninstall tried to install prerequisites' }
function Read-Host { throw 'Yes or DryRun must never prompt' }
$state = @{ Plugin=$true; Marketplace=$true; Writes=0; Calls=0 }
function Invoke-ClosedInput {
    param($Command, $Environment)
    $state.Calls++
    $line = $Command -join '|'
    if ($Command[2] -eq 'list') {
        # Only codex has legion here; the other CLIs must not look like surviving installs.
        $output = if ($Command[0] -ne 'codex') { '[]' }
        elseif ($state.Plugin) { 'legion@ps-legion-marketplace installed, disabled' }
        else { 'legion@ps-legion-marketplace not installed' }
        return @{ExitCode=0;Output=@($output)}
    }
    if ($Command[3] -eq 'list') {
        $source = if ($state.Marketplace) { 'example/marketplace' } else { '' }
        return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool $Command[0] -Source $source)}
    }
    if ($line -ne 'codex|plugin|remove|legion@ps-legion-marketplace' -and
        $line -ne 'codex|plugin|marketplace|remove|ps-legion-marketplace') { throw "Unexpected fake mutation: $line" }
    if ($Command[2] -eq 'remove') { $state.Plugin=$false }
    else { $state.Marketplace=$false }
    $state.Writes++
    return @{ExitCode=0;Output=@()}
}
$bin = Join-Path $fixtureHome '.legion/bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
'#!/bin/sh
exec pwsh -NoProfile -File ''/plugin/bin/legion.ps1'' "$@"' | Set-Content (Join-Path $bin 'legion')
'owner file' | Set-Content (Join-Path $bin 'unrelated')
$cache = Join-Path $fixtureHome '.codex/plugins/cache/ps-legion-marketplace'
$other = Join-Path $fixtureHome '.codex/plugins/cache/other-marketplace'
New-Item -ItemType Directory -Path (Join-Path $cache 'legion/0.1.0'), (Join-Path $cache 'legion/0.4.0'), $other -Force | Out-Null
'owner cache' | Set-Content (Join-Path $other 'keep.txt')
# Exercise the expanded archive entry point, including top-level parameter forwarding.
$overrides = ''
foreach ($name in @('Get-InstallHome','Get-InstallSourceText','Ensure-InstallPowerShell','Test-InstallCommandAvailable','Read-Host','Invoke-ClosedInput')) {
    $overrides += "function $name {" + (Get-Command $name -CommandType Function).Definition + "}`n"
}
$scriptText = (Get-Content -LiteralPath $Installer -Raw).Replace('if (-not $NoRun) {', $overrides + 'if (-not $NoRun) {')
$entryFolder = Join-Path $fixtureHome 'entry'
New-Item -ItemType Directory -Path (Join-Path $entryFolder 'bin/lib') -Force | Out-Null
Copy-Item (Join-Path (Split-Path $Installer) 'bin/lib/paths.ps1') (Join-Path $entryFolder 'bin/lib/paths.ps1')
Copy-Item $Catalog (Join-Path $entryFolder 'tools.json')
$entryInstaller = Join-Path $entryFolder 'install.ps1'
[IO.File]::WriteAllText($entryInstaller, $scriptText)
$preview = @(& $entryInstaller -Uninstall -DryRun -Tools codex)
if ($state.Writes -ne 0 -or -not (Test-Path (Join-Path $bin 'legion')) -or -not (Test-Path $cache)) { throw 'Dry run changed state' }
& $entryInstaller -Uninstall -Yes -Tools codex
if ($state.Writes -ne 2 -or (Test-Path (Join-Path $bin 'legion'))) { throw 'Uninstall did not remove plugin, marketplace and launcher' }
if (-not (Test-Path (Join-Path $bin 'unrelated'))) { throw 'Uninstall removed owner file' }
if ((Test-Path $cache) -or -not (Test-Path (Join-Path $other 'keep.txt'))) { throw 'Cache cleanup was not scoped to the marketplace' }
$repeat = @(& $entryInstaller -Uninstall -Tools codex)
if ($state.Writes -ne 2 -or ($repeat -join "`n") -notmatch 'skip: .*\(not installed\)') { throw 'Repeat uninstall was not safe' }
if ($repeat -notcontains 'Nothing to uninstall.' -or ($repeat -join "`n") -match 'codex plugin (remove|marketplace remove)') { throw 'Repeat uninstall printed a removal plan' }
foreach ($line in $repeat) {
    if ($line -match '^Kept .*: (.+)$' -and -not (Test-Path -LiteralPath $Matches[1])) { throw 'Kept summary contains missing path' }
}
'standalone uninstall passed'
