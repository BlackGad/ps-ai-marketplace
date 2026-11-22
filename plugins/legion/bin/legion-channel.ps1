param(
    [ValidateSet('add', 'remove', 'check')][string]$Action,
    [string]$Id,
    [string]$Kind,
    [string]$Target,
    [string[]]$Accounts,
    [string]$HomeRoot = $HOME,
    [switch]$NoRun
)

. (Join-Path $PSScriptRoot 'lib/accounts.ps1')
. (Join-Path $PSScriptRoot 'lib/channels.ps1')

function Test-ChannelCommand {
    param([string]$Name)
    return [bool](Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue)
}

function Get-ChannelKind {
    param([string]$Kind)
    $descriptor = @(Get-LegionChannels | Where-Object id -CEQ $Kind)[0]
    if (-not $descriptor) { throw "unknown channel kind '$Kind'" }
    return $descriptor
}

function Get-ChannelAccount {
    param($Data, [string]$AccountId, $Descriptor)
    $account = @($Data.agents | Where-Object id -CEQ $AccountId)[0]
    if (-not $account) { throw "unknown account '$AccountId'" }
    if ($account.tool -cnotin $Descriptor.launch.PSObject.Properties.Name) {
        throw "account '$AccountId' uses $($account.tool), which $($Descriptor.id) does not support"
    }
    return $account
}

function Add-ChannelBinding {
    param($Data, [string]$Path, [string]$Id, [string]$Kind, [string]$Target, [string[]]$Accounts)
    Assert-LegionId -Id $Id
    $descriptor = Get-ChannelKind $Kind
    foreach ($accountId in $Accounts) { $null = Get-ChannelAccount $Data $accountId $descriptor }
    $existing = @($Data.channels | Where-Object id -CEQ $Id)[0]
    if ($existing) {
        $same = $existing.kind -ceq $Kind -and $existing.target -ceq $Target -and ($existing.accounts -join ',') -ceq ($Accounts -join ',')
        if (-not $same) { throw "channel $Id exists with other values; remove it first" }
        return "skip: channel $Id (already done)"
    }
    $Data.channels = @($Data.channels) + [pscustomobject]@{ id = $Id; kind = $Kind; target = $Target; accounts = $Accounts }
    Write-LegionPersonalisation -Data $Data -Path $Path
    return "added: channel $Id"
}

function Remove-ChannelBinding {
    param($Data, [string]$Path, [string]$Id)
    if (-not (@($Data.channels | Where-Object id -CEQ $Id).Count)) { return "skip: channel remove $Id (already done)" }
    $Data.channels = @($Data.channels | Where-Object id -CNE $Id)
    Write-LegionPersonalisation -Data $Data -Path $Path
    return "removed: channel $Id"
}

# Reads files only; no CLI is started.
function Get-ChannelCheck {
    param([string]$Kind, [string[]]$Accounts, [string]$HomeRoot)
    $data = Read-LegionJson -Path (Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings)
    $descriptor = Get-ChannelKind $Kind
    $supported = $descriptor.launch.PSObject.Properties.Name
    $command = $descriptor.ready.command
    if ($command) { "{0,-10} {1}" -f $command, $(if (Test-ChannelCommand $command) { 'found' } else { 'not found' }) }
    foreach ($accountId in $Accounts) {
        $account = @($data.agents | Where-Object id -CEQ $accountId)[0]
        if (-not $account) { throw "unknown account '$accountId'" }
        if ($account.tool -cnotin $supported) {
            "{0,-10} not supported ({1} supports: {2})" -f $accountId, $Kind, ($supported -join ', ')
            continue
        }
        $folder = $descriptor.ready.pluginFolder.($account.tool)
        $configDir = $account.configDir
        if ($configDir -like '~[/\]*') { $configDir = Join-Path $HomeRoot $configDir.Substring(2) }
        $found = $folder -and (Test-Path -LiteralPath (Join-Path $configDir $folder) -PathType Container)
        "{0,-10} {1} plugin {2}" -f $accountId, $Kind, $(if ($found) { 'found' } else { 'not found' })
    }
}

if ($NoRun) { return }

$file = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings
if ($Action -eq 'check') {
    Get-ChannelCheck -Kind $Kind -Accounts @($Accounts) -HomeRoot $HomeRoot
    return
}
$data = Read-LegionJson -Path $file
switch ($Action) {
    add { Add-ChannelBinding $data $file $Id $Kind $Target @($Accounts) }
    remove { Remove-ChannelBinding $data $file $Id }
    default { throw '-Action add, remove or check is required' }
}
