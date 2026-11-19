param([string]$Installer, [string]$Catalog)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'MarketplaceListing.ps1')
$catalogText = Get-Content -LiteralPath $Catalog -Raw
$fixtureHome = Join-Path (Split-Path $Catalog) 'home'
. ([scriptblock]::Create((Get-Content -LiteralPath $Installer -Raw))) -NoRun
. (Join-Path $PSScriptRoot 'InstallerSandbox.ps1') -InstallFixtureHome ($fixtureHome)
function Get-InstallSourceText { $catalogText }
function Ensure-InstallPowerShell { throw 'Uninstall tried to install prerequisites' }
function Read-Host { throw 'Yes or DryRun must never prompt' }
$state = @{ Plugin=$true; Marketplace=$true; Writes=0; Calls=0 }
function Invoke-ClosedInput {
    param($Command)
    $state.Calls++
    $line = $Command -join '|'
    if ($Command[2] -eq 'list') {
        $output = if ($Command[0] -eq 'claude') {
            if ($state.Plugin) { '[{"id":"ps-ai@ps-ai-marketplace","enabled":false}]' } else { '[]' }
        } elseif ($state.Plugin) { 'ps-ai@ps-ai-marketplace installed, disabled' }
        else { 'ps-ai@ps-ai-marketplace not installed' }
        return @{ExitCode=0;Output=@($output)}
    }
    if ($Command[3] -eq 'list') {
        $source = if ($state.Marketplace) { 'example/marketplace' } else { '' }
        return @{ExitCode=0;Output=@(Get-FixtureMarketplaceListing -Tool $Command[0] -Source $source)}
    }
    if ($line -ne 'codex|plugin|remove|ps-ai@ps-ai-marketplace' -and
        $line -ne 'codex|plugin|marketplace|remove|ps-ai-marketplace') { throw "Unexpected fake mutation: $line" }
    if ($Command[2] -eq 'remove') { $state.Plugin=$false }
    else { $state.Marketplace=$false }
    $state.Writes++
    return @{ExitCode=0;Output=@()}
}
$bin = Join-Path $fixtureHome '.legion/bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
'#!/bin/sh
exec pwsh -NoProfile -File ''/plugin/bin/ps-ai-overseer.ps1'' "$@"' | Set-Content (Join-Path $bin 'ps-ai-overseer')
'owner file' | Set-Content (Join-Path $bin 'unrelated')
$cache = Join-Path $fixtureHome '.codex/plugins/cache/ps-ai-marketplace'
$other = Join-Path $fixtureHome '.codex/plugins/cache/other-marketplace'
New-Item -ItemType Directory -Path (Join-Path $cache 'ps-ai/0.1.0'), (Join-Path $cache 'ps-ai/0.4.0'), $other -Force | Out-Null
'owner cache' | Set-Content (Join-Path $other 'keep.txt')
# Exercise the downloaded script-block entry point, including top-level parameter forwarding.
$overrides = ''
foreach ($name in @('Get-InstallHome','Get-InstallSourceText','Ensure-InstallPowerShell','Test-InstallCommandAvailable','Read-Host','Invoke-ClosedInput')) {
    $overrides += "function $name {" + (Get-Command $name -CommandType Function).Definition + "}`n"
}
$scriptText = (Get-Content -LiteralPath $Installer -Raw).Replace('if (-not $NoRun) {', $overrides + 'if (-not $NoRun) {')
$preview = @(& ([scriptblock]::Create($scriptText)) -Uninstall -DryRun -Tools codex)
if ($state.Writes -ne 0 -or -not (Test-Path (Join-Path $bin 'ps-ai-overseer')) -or -not (Test-Path $cache)) { throw 'Dry run changed state' }
& ([scriptblock]::Create($scriptText)) -Uninstall -Yes -Tools codex
if ($state.Writes -ne 2 -or (Test-Path (Join-Path $bin 'ps-ai-overseer'))) { throw 'Uninstall did not remove plugin, marketplace and launcher' }
if (-not (Test-Path (Join-Path $bin 'unrelated'))) { throw 'Uninstall removed owner file' }
if ((Test-Path $cache) -or -not (Test-Path (Join-Path $other 'keep.txt'))) { throw 'Cache cleanup was not scoped to the marketplace' }
$repeat = @(& ([scriptblock]::Create($scriptText)) -Uninstall -Tools codex)
if ($state.Writes -ne 2 -or ($repeat -join "`n") -notmatch 'skip: .*\(not installed\)') { throw 'Repeat uninstall was not safe' }
if ($repeat -notcontains 'Nothing to uninstall.' -or ($repeat -join "`n") -match 'codex plugin (remove|marketplace remove)') { throw 'Repeat uninstall printed a removal plan' }
foreach ($line in $repeat) {
    if ($line -match '^Kept .*: (.+)$' -and -not (Test-Path -LiteralPath $Matches[1])) { throw 'Kept summary contains missing path' }
}
'standalone uninstall passed'
