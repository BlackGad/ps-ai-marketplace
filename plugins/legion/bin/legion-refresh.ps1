param([string]$HomeRoot = $HOME)

$ErrorActionPreference = 'Stop'
# The update contract with installers 0.15 and older, which call this script by path: forward to `legion refresh`.
. (Join-Path $PSScriptRoot 'lib/python.ps1')
if (-not (Get-LegionUv)) {
    'uv is missing. Ask the owner before installing it.'
    exit 0
}
$result = Invoke-LegionPython -Arguments @('refresh') -HomeRoot $HomeRoot
if ($result.Output) { $result.Output.TrimEnd("`r", "`n") }
if ($result.Error) { [Console]::Error.WriteLine($result.Error.TrimEnd("`r", "`n")) }
exit $result.ExitCode
