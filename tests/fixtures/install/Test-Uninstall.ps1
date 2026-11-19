param([string]$Installer, [string]$Catalog)
$ErrorActionPreference = 'Stop'
$catalogText = Get-Content -LiteralPath $Catalog -Raw
$fixtureHome = Join-Path (Split-Path $Catalog) 'home'
. ([scriptblock]::Create((Get-Content -LiteralPath $Installer -Raw))) -NoRun
function Get-InstallHome { $fixtureHome }
function Get-InstallSourceText { $catalogText }
function Ensure-InstallPowerShell { throw 'Uninstall tried to install prerequisites' }
function Test-InstallCommandAvailable { $true }
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
        return @{ExitCode=0;Output=@($(if ($state.Marketplace) { 'ps-ai-marketplace example/marketplace' }))}
    }
    if ($line -ne 'codex|plugin|remove|ps-ai@ps-ai-marketplace' -and
        $line -ne 'codex|plugin|marketplace|remove|ps-ai-marketplace') { throw "Unexpected fake mutation: $line" }
    if ($Command[2] -eq 'remove') { $state.Plugin=$false }
    else { $state.Marketplace=$false }
    $state.Writes++
    return @{ExitCode=0;Output=@()}
}
$bin = Join-Path $fixtureHome '.agents/bin'
New-Item -ItemType Directory -Path $bin -Force | Out-Null
'#!/bin/sh
exec pwsh -NoProfile -File ''/plugin/bin/ps-ai-overseer.ps1'' "$@"' | Set-Content (Join-Path $bin 'ps-ai-overseer')
'owner file' | Set-Content (Join-Path $bin 'unrelated')
# Exercise the downloaded script-block entry point, including top-level parameter forwarding.
$overrides = ''
foreach ($name in @('Get-InstallHome','Get-InstallSourceText','Ensure-InstallPowerShell','Test-InstallCommandAvailable','Read-Host','Invoke-ClosedInput')) {
    $overrides += "function $name {" + (Get-Command $name -CommandType Function).Definition + "}`n"
}
$scriptText = (Get-Content -LiteralPath $Installer -Raw).Replace('if (-not $NoRun) {', $overrides + 'if (-not $NoRun) {')
$preview = @(& ([scriptblock]::Create($scriptText)) -Uninstall -DryRun -Tools codex)
if ($state.Calls -ne 0 -or -not (Test-Path (Join-Path $bin 'ps-ai-overseer'))) { throw 'Dry run changed state' }
& ([scriptblock]::Create($scriptText)) -Uninstall -Yes -Tools codex
if ($state.Writes -ne 2 -or (Test-Path (Join-Path $bin 'ps-ai-overseer'))) { throw 'Uninstall did not remove plugin, marketplace and launcher' }
if (-not (Test-Path (Join-Path $bin 'unrelated'))) { throw 'Uninstall removed owner file' }
$repeat = @(& ([scriptblock]::Create($scriptText)) -Uninstall -Yes -Tools codex)
if ($state.Writes -ne 2 -or ($repeat -join "`n") -notmatch 'skip: .*\(not installed\)') { throw 'Repeat uninstall was not safe' }
'standalone uninstall passed'
