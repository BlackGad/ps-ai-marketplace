param([string]$InstallFixtureHome)
$env:HOME = $InstallFixtureHome
$env:USERPROFILE = $InstallFixtureHome
$fixtureCatalog = Get-Content (Join-Path $PSScriptRoot '../../../plugins/legion/tools.json') -Raw | ConvertFrom-Json
foreach ($fixtureTool in $fixtureCatalog.tools) {
    $fixtureConfig = Join-Path $InstallFixtureHome $fixtureTool.plugin.defaultConfigDir.Substring(2)
    New-Item -ItemType Directory -Path $fixtureConfig -Force | Out-Null
    [Environment]::SetEnvironmentVariable($fixtureTool.configEnv, $fixtureConfig, 'Process')
}
function Get-InstallHome { $InstallFixtureHome }
function Get-InstallSourceText { throw 'No network in tests' }
function Ensure-InstallPowerShell { $true }
function Get-LegionUserPath { Get-InstallLegionPath 'bin' }
function Add-LegionUserPath { }
function Test-InstallCommandAvailable { $true }
function claude { 'fixture-version' }
function codex { 'fixture-version' }
function copilot { 'fixture-version' }
function New-InstallFixturePlugin {
    param([string]$Path, [string]$Version = '0.3.0')
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    @{name='legion';version=$Version} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Path 'plugin.json')
    return $Path
}
