. (Join-Path $PSScriptRoot 'tools.ps1')

# Build-time descriptor discovery still serves tools/update-tools-index.ps1.
function Get-LegionChannels {
    param([string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'))
    foreach ($folder in (Get-ChildItem -LiteralPath $SkillsRoot -Directory -Filter 'legion-*' | Sort-Object Name)) {
        $path = Join-Path $folder.FullName 'channel.json'
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $data = ConvertFrom-LegionToolJson ([IO.File]::ReadAllText($path))
        $data | Add-Member SkillRoot $folder.FullName
        $data
    }
}
