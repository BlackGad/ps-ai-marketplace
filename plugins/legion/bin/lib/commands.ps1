param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'python.ps1')

# milestone 4 removes this
function Get-LegionOwnerCommandState {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return 'missing' }
    if (-not (Test-LegionOwnerCommandFile -Path $Path)) { return 'blocked' }
    return 'owned'
}

# milestone 4 removes this
function Get-LegionCommandState {
    param([string]$Bin, [string]$HomeRoot)
    $suffixes = if ($IsWindows) { @('', '.cmd') } else { @('') }
    foreach ($suffix in $suffixes) {
        $path = Join-Path $Bin "legion$suffix"
        $state = Get-LegionOwnerCommandState -Path $path
        if ($state -eq 'owned' -and -not (Test-LegionLauncherExecutable -Path $path)) { $state = 'permission' }
        [pscustomobject]@{ Name = 'legion'; Script = 'legion.ps1'; Path = $path; Windows = ($suffix -eq '.cmd'); State = $state }
    }
}
