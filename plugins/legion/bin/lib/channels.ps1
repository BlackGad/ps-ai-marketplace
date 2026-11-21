. (Join-Path $PSScriptRoot 'tools.ps1')

function Get-LegionChannels {
    param([string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'))
    $tools = @(Get-LegionTools -SkillsRoot $SkillsRoot)
    $ids = @()
    foreach ($folder in (Get-ChildItem -LiteralPath $SkillsRoot -Directory -Filter 'legion-*' | Sort-Object Name)) {
        $path = Join-Path $folder.FullName 'channel.json'
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $data = ConvertFrom-LegionToolJson ([IO.File]::ReadAllText($path))
        $keys = @($data.PSObject.Properties.Name)
        foreach ($required in @('schemaVersion', 'id', 'launch')) {
            if ($required -cnotin $keys) { throw "invalid channel descriptor '$path'" }
        }
        foreach ($key in $keys) {
            if ($key -cnotin @('schemaVersion', 'id', 'launch', 'ready')) { throw "invalid channel descriptor '$path'" }
        }
        if ($data.schemaVersion -isnot [long] -or $data.schemaVersion -ne 1 -or $data.id -isnot [string] -or $data.id -cnotmatch '^[a-z][a-z0-9-]*$') { throw "invalid channel identity '$path'" }
        if ($folder.Name -cne "legion-$($data.id)") { throw "channel folder does not match '$($data.id)'" }
        if ($data.id -cin $ids) { throw "duplicate channel kind '$($data.id)'" }
        if (-not (Test-Path -LiteralPath (Join-Path $folder.FullName 'SKILL.md') -PathType Leaf)) { throw "missing channel skill '$($data.id)'" }
        if ($data.launch -isnot [pscustomobject]) { throw "invalid channel launch map '$($data.id)'" }
        foreach ($entry in $data.launch.PSObject.Properties) {
            if ($entry.Name -cnotin $tools.id) { throw "unknown channel tool '$($entry.Name)'" }
            if ($entry.Value -isnot [array]) { throw 'channel launch arguments must be a string array' }
            foreach ($arg in $entry.Value) { if ($arg -isnot [string]) { throw 'channel launch arguments must be strings' } }
        }
        $ids += $data.id
        $data | Add-Member SkillRoot $folder.FullName
        $data
    }
}

function Resolve-LegionChannel {
    param($Personalisation, [string]$Id, [string]$Tool, [string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'))
    $matches = @($Personalisation.channels | Where-Object id -CEQ $Id)
    if ($matches.Count -ne 1) { throw "unknown or duplicate channel '$Id'" }
    $channel = $matches[0]
    if ($channel.target -isnot [string] -or -not $channel.target -or $channel.id -cnotmatch '^[a-z][a-z0-9-]*$') { throw "invalid channel '$Id'" }
    $descriptor = @(Get-LegionChannels $SkillsRoot | Where-Object id -CEQ $channel.kind)[0]
    if (-not $descriptor) { throw "unknown channel kind '$($channel.kind)'" }
    if ($Tool -cnotin $descriptor.launch.PSObject.Properties.Name) { throw "channel '$Id' does not support tool '$Tool'" }
    if (-not @($channel.accounts).Count -or @($channel.accounts | Select-Object -Unique).Count -ne @($channel.accounts).Count) { throw "invalid channel accounts '$Id'" }
    foreach ($accountId in $channel.accounts) {
        $account = @($Personalisation.agents | Where-Object id -CEQ $accountId)
        if ($account.Count -ne 1) { throw "channel '$Id': unknown account '$accountId'" }
        if ($account[0].tool -cnotin $descriptor.launch.PSObject.Properties.Name) { throw "channel '$Id': unsupported bound tool '$($account[0].tool)'" }
    }
    [pscustomobject]@{
        Id=$channel.id; Kind=$channel.kind; Target=$channel.target; Accounts=@($channel.accounts)
        LaunchArguments=[string[]]$descriptor.launch.PSObject.Properties[$Tool].Value; SkillRoot=$descriptor.SkillRoot
    }
}
