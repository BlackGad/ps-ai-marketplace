param([string]$Installer, [ValidateSet('missing','error','blocked','ok')][string]$Winget, [switch]$Preview, [string]$Tool = 'az', [string]$Method)
$fixtureTool = $Tool
$fixtureMethod = $Method
. $Installer -NoRun
function Get-ToolInstallRoot { param($Tool) Join-Path $PSScriptRoot "absent-tools/$Tool" }
function Test-ToolInstalled { param($Tool) @{ Installed=$false; Version='' } }
function Test-ToolCommandAvailable { param($Name) $Name -eq 'winget' -and $Winget -ne 'missing' }
function Invoke-ToolCommand { param($Command) if ($Winget -eq 'blocked') { throw 'launch denied' }; if ($Winget -eq 'error') { 5 } else { 0 } }
function Invoke-ToolDownload { throw 'fallback must not download without an explicit method' }
$parameters = @{ Tool=$fixtureTool; Platform='windows'; Yes=(-not $Preview) }
if ($fixtureMethod) { $parameters.Method = $fixtureMethod }
Invoke-ToolInstall @parameters
exit $LASTEXITCODE
