param(
    [ValidateSet('add', 'models')][string]$Action,
    [string]$Id,
    [string]$Tool,
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
if ($Action -eq 'add') {
    if (-not $Provider) { throw 'subscription accounts are added with: legion account add --id <id> --tool <tool>' }
    Assert-LegionId -Id $Id
    $null = Get-LegionTool -Tool $Tool
} elseif (-not (Test-Path -LiteralPath $file)) {
    throw 'No legion settings yet; add an agent first.'
}
$settingsLock = if ($List) { $null } else {
    Wait-LegionLockFile -Path (Get-LegionSettingsLockPath -Path $file) -Seconds 30
}
if (-not $settingsLock -and -not $List) { throw 'legion settings are busy; another legion command is still running' }
try {
if (-not (Test-Path -LiteralPath $file)) {
    # A fresh machine has no settings; the first agent added creates them.
    if ($Action -ne 'add') { throw 'No legion settings yet; add an agent first.' }
    $data = '{"schemaVersion":1,"agents":[],"channels":[]}' | ConvertFrom-Json
} else { $data = Read-LegionJson -Path $file }
switch ($Action) {
    add {
        $null = Get-LegionTool -Tool $Tool
        $existing = Get-LegionAgent -Data $data -Id $Id
        if ($Provider -eq 'foundry') {
            if ($ConfigDir) { throw '-ConfigDir is for existing subscription accounts; omit it for Foundry.' }
            $null = Get-LegionFoundryTool -Tool $Tool
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
}
} finally { if ($settingsLock) { $settingsLock.Dispose() } }
