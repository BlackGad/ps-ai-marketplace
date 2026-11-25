. (Join-Path $PSScriptRoot 'tools.ps1')


function Read-LegionJson {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
    return ($raw.TrimStart([char]0xFEFF) | ConvertFrom-Json -Depth 100 -ErrorAction Stop)
}

function Get-LegionAgent {
    param($Data, [string]$Id)
    return @($Data.agents | Where-Object { $_.id -ceq $Id })[0]
}
