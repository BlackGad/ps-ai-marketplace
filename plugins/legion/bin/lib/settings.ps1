. (Join-Path $PSScriptRoot 'tools.ps1')
. (Join-Path $PSScriptRoot 'channels.ps1')


function Read-LegionJson {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
    return ($raw.TrimStart([char]0xFEFF) | ConvertFrom-Json -Depth 100 -ErrorAction Stop)
}

function Get-LegionAgent {
    param($Data, [string]$Id)
    return @($Data.agents | Where-Object { $_.id -ceq $Id })[0]
}

function Get-LegionReferenceIssues {
    param($Data)
    $tools = @(Get-LegionTools)
    $ids = @()
    foreach ($agent in $Data.agents) {
        if ($agent.id -cin $ids) { "agents: duplicate id '$($agent.id)'" }
        if ($agent.tool -cnotin $tools.id) { "agents: unknown tool '$($agent.tool)'" }
        $ids += $agent.id
    }
    $channelIds = @()
    foreach ($channel in $Data.channels) {
        if ($channel.id -cin $channelIds) { "channels: duplicate id '$($channel.id)'" }
        $channelIds += $channel.id
        foreach ($id in $channel.accounts) {
            if ($id -cnotin $ids) { "channel '$($channel.id)': unknown account '$id'" }
        }
        try {
            $descriptor = Get-LegionChannelKind -Kind $channel.kind
            foreach ($id in $channel.accounts) {
                $agent = Get-LegionAgent -Data $Data -Id $id
                if ($agent -and -not (Test-LegionChannelLaunchesTool $descriptor $agent.tool)) {
                    "channel '$($channel.id)': unsupported tool '$($agent.tool)'"
                }
            }
        } catch { $_.Exception.Message }
    }
}

function Get-LegionProviderIssues {
    param($Data)
    $tools = @(Get-LegionTools)
    for ($i = 0; $i -lt @($Data.agents).Count; $i++) {
        $agent = $Data.agents[$i]
        $provider = $agent.provider
        if ($null -eq $provider) { continue }
        $prefix = "agents[$i].provider:"
        if ($provider.kind -cne 'foundry') { "$prefix unsupported provider '$($provider.kind)'"; continue }
        $tool = $tools | Where-Object { $_.id -ceq $agent.tool }
        if (-not $tool) { "$prefix unknown tool '$($agent.tool)'"; continue }
        if ($null -eq $tool.foundry) { "$prefix tool '$($agent.tool)' does not support Foundry"; continue }
        $names = @()
        $aliases = @()
        foreach ($deployment in $provider.deployments) {
            if ($deployment.name -cin $names) { "$prefix duplicate deployment '$($deployment.name)'" }
            $names += $deployment.name
            if ($deployment.alias) {
                if ($deployment.alias -cin $aliases) { "$prefix alias '$($deployment.alias)' used twice" }
                $aliases += $deployment.alias
                if ($deployment.alias -cnotin @($tool.foundry.aliases)) {
                    "$prefix alias '$($deployment.alias)' is not supported by tool '$($agent.tool)'"
                }
            }
        }
        if ($provider.default -cnotin $names) { "$prefix default '$($provider.default)' is not a deployment" }
    }
}

function Invoke-LegionValidation {
    param([string]$Kind, [string]$Path)
    try {
        $json = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path)).TrimStart([char]0xFEFF)
        $data = $json | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        $schema = Join-Path $PSScriptRoot "../../schemas/$Kind.schema.json"
        $schemaErrors = @()
        $valid = Test-Json -Json $json -SchemaFile $schema -ErrorVariable schemaErrors -ErrorAction SilentlyContinue
        if (-not $valid) {
            if ($schemaErrors.Count -eq 0) { '$: schema validation failed' }
            foreach ($issue in $schemaErrors) {
                $message = ($issue.ToString() -replace '\s+', ' ').Trim()
                "`$: $message; run legion setup to update your settings"
            }
            return
        }
        if ($Kind -eq 'personalisation') {
            Get-LegionReferenceIssues -Data $data
            Get-LegionProviderIssues -Data $data
        }
    } catch {
        $message = ($_.Exception.Message -replace '\s+', ' ').Trim()
        "`$: $message; run legion setup to update your settings"
    }
}
