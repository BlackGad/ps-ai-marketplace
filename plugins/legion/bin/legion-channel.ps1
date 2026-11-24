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

function Get-ChannelAccount {
    param($Data, [string]$AccountId, $Descriptor)
    $account = Get-LegionAgent -Data $Data -Id $AccountId
    if (-not $account) { throw "unknown account '$AccountId'" }
    if (-not (Test-LegionChannelLaunchesTool -Descriptor $Descriptor -Tool $account.tool)) {
        throw "account '$AccountId' uses $($account.tool), which $($Descriptor.id) does not support"
    }
    if ($account.provider) { throw "account '$AccountId' runs through Foundry: channels are not available on third-party providers" }
    return $account
}

function Add-ChannelBinding {
    param($Data, [string]$Path, [string]$Id, [string]$Kind, [string]$Target, [string[]]$Accounts)
    Assert-LegionId -Id $Id
    $descriptor = Get-LegionChannelKind $Kind
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
    $descriptor = Get-LegionChannelKind $Kind
    $supported = $descriptor.launch.PSObject.Properties.Name
    $command = $descriptor.ready.command
    if ($command) { "{0,-10} {1}" -f $command, $(if (Get-Command $command -CommandType Application -ErrorAction SilentlyContinue) { 'found' } else { 'not found' }) }
    foreach ($accountId in $Accounts) {
        $account = Get-LegionAgent -Data $data -Id $accountId
        if (-not $account) { throw "unknown account '$accountId'" }
        if (-not (Test-LegionChannelLaunchesTool -Descriptor $descriptor -Tool $account.tool)) {
            "{0,-10} not supported ({1} supports: {2})" -f $accountId, $Kind, ($supported -join ', ')
            continue
        }
        $folder = $descriptor.ready.pluginFolder.($account.tool)
        if (-not $folder) {
            "{0,-10} {1} plugin not needed" -f $accountId, $Kind
            continue
        }
        $configDir = Resolve-LegionHomePath -Path $account.configDir -HomeRoot $HomeRoot
        $found = $folder -and (Test-Path -LiteralPath (Join-Path $configDir $folder) -PathType Container)
        "{0,-10} {1} plugin {2}" -f $accountId, $Kind, $(if ($found) { 'found' } else { 'not found' })
    }
    # Each binding of this kind has its own bot folder; look only for the token file, never read it.
    foreach ($binding in @($data.channels | Where-Object { $descriptor.state -and $_.kind -ceq $Kind })) {
        $tool = @($binding.accounts | ForEach-Object { (Get-LegionAgent -Data $data -Id $_).tool } | Where-Object { $descriptor.state.PSObject.Properties[$_] })[0]
        if (-not $tool) { continue }
        $state = $descriptor.state.$tool
        $folder = Get-LegionHomePath -HomeRoot $HomeRoot -Path "$($state.folder)/$($binding.id)"
        $ready = Test-Path -LiteralPath (Join-Path $folder $state.tokenFile) -PathType Leaf
        Format-LegionBotFolderLine -Id $binding.id -Ready $ready -Setup $state.setup
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
