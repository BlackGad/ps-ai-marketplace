. (Join-Path $PSScriptRoot 'paths.ps1')
. (Join-Path $PSScriptRoot 'tools.ps1')

# milestone 4 removes this
function Get-LegionWrapperCommand {
    param([string]$Id, [string]$HomeRoot = $HOME)
    if ($Id -cnotmatch '^[a-z][a-z0-9-]*$') { throw 'invalid account id' }
    $name = if ($IsWindows) { "$Id.cmd" } else { $Id }
    return [IO.Path]::GetFullPath((Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$name"))
}
