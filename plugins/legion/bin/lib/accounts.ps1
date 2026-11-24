. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'settings.ps1')

# milestone 4 removes this
function Assert-LegionId {
    param([string]$Id)
    if ($Id -cnotmatch '^[a-z][a-z0-9-]*$') { throw "id '$Id' must match ^[a-z][a-z0-9-]*$" }
}

# milestone 4 removes this
function Assert-LegionNewId {
    param([string]$Id, $Data)
    Assert-LegionId -Id $Id
    if ($Id -ceq 'legion') { throw "'$Id' is reserved for an owner command" }
    if (Get-LegionAgent -Data $Data -Id $Id) { throw "account '$Id' already exists" }
    if (Get-Command $Id -CommandType Application -ErrorAction SilentlyContinue) { throw "'$Id' is already a command" }
}

# milestone 4 removes this
function Test-LegionLauncherMissing {
    param([string]$Id, [string]$HomeRoot)
    $suffixes = if ($IsWindows) { @('', '.cmd') } else { @('') }
    return @($suffixes | Where-Object {
        -not (Test-LegionLauncherExecutable -Path (Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$Id$_"))
    }).Count -gt 0
}

# milestone 4 removes this
function Get-LegionNewAccountDir {
    param([string]$Id, [string]$HomeRoot)
    return Get-LegionHomePath -HomeRoot $HomeRoot -Path "agents/$Id"
}
