param(
    [ValidateSet('add', 'rename', 'remove', 'register', 'models')][string]$Action,
    [string]$Id,
    [string]$Tool,
    [string]$NewId,
    [string]$Command,
    [string]$ConfigDir,
    [ValidateSet('foundry')][string]$Provider,
    [string]$Endpoint,
    [string[]]$Deployments,
    [string]$Default,
    [string[]]$Aliases,
    [switch]$Standard,
    [switch]$List,
    [string]$HomeRoot = $HOME
)

. (Join-Path $PSScriptRoot 'lib/accounts.ps1')

if ($Standard -and ($PSBoundParameters.ContainsKey('Aliases') -or $PSBoundParameters.ContainsKey('Default'))) {
    throw '-Standard cannot be combined with -Aliases or -Default'
}
if ($Standard -and $Action -ne 'models' -and -not ($Action -eq 'add' -and $Provider -eq 'foundry')) {
    throw '-Standard is only for Foundry add or models'
}

$file = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings
if (-not (Test-Path -LiteralPath $file)) {
    # A fresh machine has no settings; the first agent added creates them.
    if ($Action -notin @('add', 'register')) { throw 'No legion settings yet; add an agent first.' }
    $data = '{"schemaVersion":1,"agents":[],"channels":[]}' | ConvertFrom-Json
} else { $data = Read-LegionJson -Path $file }
switch ($Action) {
    add {
        $descriptor = Get-LegionTool -Tool $Tool
        $existing = Get-LegionAgent -Data $data -Id $Id
        if ($Provider -eq 'foundry') {
            if ($ConfigDir) { throw '-ConfigDir is for existing subscription accounts; omit it for Foundry.' }
            if ($null -eq $descriptor.foundry) { throw "tool '$Tool' does not support Foundry" }
            Assert-LegionId -Id $Id

            $Endpoint = ConvertTo-FoundryEndpoint -Url $Endpoint
            if (-not $List -and $existing -and $existing.tool -ceq $Tool -and $existing.provider.kind -ceq $Provider -and $existing.provider.endpoint -ceq $Endpoint) {
                "skip: account $Id (already done)"
                break
            }
            $discovery = Get-LegionFoundryDiscovery -Endpoint $Endpoint -Tool $Tool
            if ($List) { Write-LegionFoundryList -Discovery $discovery -Existing @(); break }
            Assert-LegionNewId -Id $Id -Data $data
            $providerBlock = New-LegionFoundryProvider -Endpoint $Endpoint -Tool $Tool -Deployments $Deployments -Default $Default -Aliases $Aliases -Standard:$Standard -Discovery $discovery
            $entry = [pscustomobject]@{
                id = $Id; tool = $Tool; configDir = (Get-LegionNewAccountDir -Id $Id -HomeRoot $HomeRoot); provider = $providerBlock
            }
            foreach ($suffix in @('', '.cmd')) { Assert-LegionWrapperPath (Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$Id$suffix") $Id }
            $null = Write-FoundryToolConfig -Agent $entry -HomeRoot $HomeRoot
            $data.agents = @($data.agents) + @($entry)
            Write-LegionPersonalisation -Data $data -Path $file
            New-FoundryWrappers -Id $Id -HomeRoot $HomeRoot -Tool $Tool
            "Run '$Id' in a terminal; it signs in to Azure through az when needed."
            break
        }
        Add-LegionSubscriptionAccount -Id $Id -Tool $Tool -Command $Command -ConfigDir $ConfigDir -HomeRoot $HomeRoot -Data $data -Path $file
    }
    models {
        $agent = Get-LegionAgent -Data $data -Id $Id
        if (-not $agent) { throw "unknown account '$Id'" }
        if ($agent.provider.kind -cne 'foundry') { throw "account '$Id' is not a Foundry agent" }
        $discovery = Get-LegionFoundryDiscovery -Endpoint $agent.provider.endpoint -Tool $agent.tool
        if ($List) { Write-LegionFoundryList -Discovery $discovery -Existing $agent.provider.deployments; break }
        $providerBlock = New-LegionFoundryProvider -Endpoint $agent.provider.endpoint -Tool $agent.tool -Deployments $Deployments -Default $Default -Aliases $Aliases -Standard:$Standard -Discovery $discovery -Existing $agent.provider.deployments
        if (($providerBlock | ConvertTo-Json -Depth 100 -Compress) -ceq ($agent.provider | ConvertTo-Json -Depth 100 -Compress)) {
            "skip: models $Id (no changes)"
            break
        }
        $agent.provider = $providerBlock
        $null = Write-FoundryToolConfig -Agent $agent -HomeRoot $HomeRoot
        Write-LegionPersonalisation -Data $data -Path $file
        New-FoundryWrappers -Id $Id -HomeRoot $HomeRoot -Tool $agent.tool
    }
    register {
        if (-not $Command -or -not $ConfigDir) { throw 'register requires -Command and -ConfigDir' }
        $target = $Command
        $target = Resolve-LegionHomePath -Path $target -HomeRoot $HomeRoot
        $target = (Get-Command $target -ErrorAction Stop).Source
        if (-not $target) { throw 'register target must be an executable file' }
        if ($target -eq (Get-LegionWrapperCommand $Id $HomeRoot)) { throw 'wrapper target would recurse' }
        & $PSCommandPath -Action add -Id $Id -Tool $Tool -Command $target -ConfigDir $ConfigDir -HomeRoot $HomeRoot
    }
    rename {
        $old = Get-LegionAgent -Data $data -Id $Id
        $new = Get-LegionAgent -Data $data -Id $NewId
        if ($null -eq $old -and $null -ne $new) {
            "skip: account rename $Id to $NewId (already done)"
            break
        }
        Assert-LegionNewId -Id $NewId -Data $data
        if ($null -eq $old) { throw "unknown account '$Id'" }
        $agent = $old
        foreach ($suffix in @('', '.cmd')) {
            $destination = Get-LegionHomePath -HomeRoot $HomeRoot -Path "bin/$NewId$suffix"
            if (Test-Path -LiteralPath $destination) { throw "wrapper collision '$destination'" }
        }
        Update-LegionChannelAccounts -Data $data -OldId $Id -NewId $NewId
        $agent.id = $NewId
        Write-LegionPersonalisation -Data $data -Path $file
        Move-LegionWrappers -OldId $Id -NewId $NewId -HomeRoot $HomeRoot
        "Config folder kept at $($agent.configDir); rename it yourself only if you want to."
    }
    remove {
        $agent = Get-LegionAgent -Data $data -Id $Id
        if ($null -eq $agent) { "skip: account remove $Id (already done)"; break }
        Update-LegionChannelAccounts -Data $data -OldId $Id -NewId ''
        $data.agents = @($data.agents | Where-Object { $_.id -cne $Id })
        Write-LegionPersonalisation -Data $data -Path $file
        Remove-LegionWrappers -Id $Id -HomeRoot $HomeRoot
        "Config folder kept at $($agent.configDir)."
    }
}
