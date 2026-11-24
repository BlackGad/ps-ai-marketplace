param([string]$HomeRoot = $HOME)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'lib/commands.ps1')
if (-not (Get-LegionUv)) {
    'uv is missing. Ask the owner before installing it.'
    exit 0
}
Publish-LegionApp -HomeRoot $HomeRoot
$result = Invoke-LegionPython -Arguments @('refresh') -HomeRoot $HomeRoot
if ($result.Output) { $result.Output.TrimEnd("`r", "`n") }
if ($result.Error) { [Console]::Error.WriteLine($result.Error.TrimEnd("`r", "`n")) }
exit $result.ExitCode
