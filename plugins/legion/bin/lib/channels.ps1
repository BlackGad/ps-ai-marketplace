. (Join-Path $PSScriptRoot 'tools.ps1')
. (Join-Path $PSScriptRoot 'paths.ps1')

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

# The one channel lookup: the binding in the owner's settings, exactly one.
function Get-LegionChannelBinding {
    param($Personalisation, [string]$Id)
    $bindings = @($Personalisation.channels | Where-Object id -CEQ $Id)
    if ($bindings.Count -ne 1) { throw "unknown or duplicate channel '$Id'" }
    return $bindings[0]
}

# The channel kind descriptor (its launch map), or an error for an unknown kind.
function Get-LegionChannelKind {
    param([string]$Kind, [string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'))
    $descriptor = @(Get-LegionChannels $SkillsRoot | Where-Object id -CEQ $Kind)[0]
    if (-not $descriptor) { throw "unknown channel kind '$Kind'" }
    return $descriptor
}

function Test-LegionChannelLaunchesTool {
    param($Descriptor, [string]$Tool)
    return $Tool -cin $Descriptor.launch.PSObject.Properties.Name
}

function Resolve-LegionChannel {
    param($Personalisation, [string]$Id, [string]$Tool, [string]$SkillsRoot = (Join-Path $PSScriptRoot '../../skills'), [string]$HomeRoot = $HOME)
    $channel = Get-LegionChannelBinding -Personalisation $Personalisation -Id $Id
    if ($channel.target -isnot [string] -or -not $channel.target -or $channel.id -cnotmatch '^[a-z][a-z0-9-]*$') { throw "invalid channel '$Id'" }
    $descriptor = Get-LegionChannelKind -Kind $channel.kind -SkillsRoot $SkillsRoot
    if (-not (Test-LegionChannelLaunchesTool $descriptor $Tool)) { throw "channel '$Id' does not support tool '$Tool'" }
    if (-not @($channel.accounts).Count -or @($channel.accounts | Select-Object -Unique).Count -ne @($channel.accounts).Count) { throw "invalid channel accounts '$Id'" }
    foreach ($accountId in $channel.accounts) {
        $account = @($Personalisation.agents | Where-Object id -CEQ $accountId)
        if ($account.Count -ne 1) { throw "channel '$Id': unknown account '$accountId'" }
        if (-not (Test-LegionChannelLaunchesTool $descriptor $account[0].tool)) { throw "channel '$Id': unsupported bound tool '$($account[0].tool)'" }
    }
    # Per-tool state: a bot folder for this binding, set through an environment variable at launch.
    $state = $null
    $entry = if ($descriptor.state) { $descriptor.state.PSObject.Properties[$Tool] }
    if ($entry) {
        $folder = Get-LegionHomePath -HomeRoot $HomeRoot -Path "$($entry.Value.folder)/$($channel.id)"
        $state = [pscustomobject]@{ Variable=$entry.Value.variable; Folder=$folder; Remove=@($entry.Value.remove); TokenFile=$entry.Value.tokenFile; Setup=$entry.Value.setup }
    }
    [pscustomobject]@{
        Id=$channel.id; Kind=$channel.kind; Target=$channel.target; Accounts=@($channel.accounts); State=$state
        LaunchArguments=[string[]]$descriptor.launch.PSObject.Properties[$Tool].Value; SkillRoot=$descriptor.SkillRoot
    }
}
