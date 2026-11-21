param([string]$InstallFixtureHome)
function Get-InstallHome { $InstallFixtureHome }
function Get-InstallSourceText { throw 'No network in tests' }
function Ensure-InstallPowerShell { $true }
function Test-InstallCommandAvailable { $true }
function claude { 'fixture-version' }
function codex { 'fixture-version' }
function copilot { 'fixture-version' }
function New-InstallFixturePlugin {
    param([string]$Path, [string]$Version = '0.3.0')
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    @{name='ps-ai';version=$Version} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $Path 'plugin.json')
    return $Path
}
