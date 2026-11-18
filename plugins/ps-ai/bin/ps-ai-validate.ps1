param(
    [ValidateSet('personalisation', 'project')][string]$Kind,
    [string]$Path,
    [switch]$NoRun
)

function Read-PsAiJson {
    param([string]$Path)
    $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path))
    return ($raw.TrimStart([char]0xFEFF) | ConvertFrom-Json -Depth 100 -ErrorAction Stop)
}

function Get-PsAiRoutingIssues {
    param($Routing, [string]$Prefix, [string[]]$Ids)
    if ($null -eq $Routing) { return }
    foreach ($name in @('implement', 'review', 'mechanical')) {
        $values = $Routing.$name
        if ($null -eq $values) { continue }
        for ($i = 0; $i -lt @($values).Count; $i++) {
            if ($values[$i] -cnotin $Ids) {
                "$Prefix.$name`[$i`]: unknown agent '$($values[$i])'"
            }
        }
    }
}

function Get-PsAiReferenceIssues {
    param($Data)
    $ids = @()
    for ($i = 0; $i -lt @($Data.agents).Count; $i++) {
        $id = [string]$Data.agents[$i].id
        if ($id -cnotmatch '^[a-z][a-z0-9-]*$') { "agents[$i].id: must match ^[a-z][a-z0-9-]*$" }
        if ($id -cin $ids) { "agents[$i].id: duplicate id '$id'" }
        $ids += $id
    }
    Get-PsAiRoutingIssues -Routing $Data.routing -Prefix 'routing' -Ids $ids
    $channels = @($Data.communication.channels.PSObject.Properties.Name)
    foreach ($project in $Data.projects.PSObject.Properties) {
        Get-PsAiRoutingIssues -Routing $project.Value.routing -Prefix "projects.$($project.Name).routing" -Ids $ids
        for ($i = 0; $i -lt @($project.Value.notify).Count; $i++) {
            $channel = $project.Value.notify[$i]
            if ($channel -cnotin $channels) { "projects.$($project.Name).notify[$i]: unknown channel '$channel'" }
        }
    }
    for ($i = 0; $i -lt @($Data.default.notify).Count; $i++) {
        $channel = $Data.default.notify[$i]
        if ($channel -cnotin $channels) { "default.notify[$i]: unknown channel '$channel'" }
    }
}

function Get-PsAiProviderIssues {
    param($Data)
    for ($i = 0; $i -lt @($Data.agents).Count; $i++) {
        $agent = $Data.agents[$i]
        $provider = $agent.provider
        if ($null -eq $provider) { continue }
        $prefix = "agents[$i].provider:"
        $names = @()
        $aliases = @()
        foreach ($deployment in $provider.deployments) {
            if ($deployment.name -cin $names) { "$prefix duplicate deployment '$($deployment.name)'" }
            $names += $deployment.name
            if ($deployment.alias) {
                if ($deployment.alias -cin $aliases) { "$prefix alias '$($deployment.alias)' used twice" }
                $aliases += $deployment.alias
            }
        }
        if ($provider.default -cnotin $names) { "$prefix default '$($provider.default)' is not a deployment" }
        if ($aliases.Count -and $agent.tool -cne 'claude') { "$prefix aliases are for claude agents only" }
    }
}

function Invoke-PsAiValidation {
    param([string]$Kind, [string]$Path)
    try {
        $json = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path)).TrimStart([char]0xFEFF)
        $data = $json | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        $schema = Join-Path $PSScriptRoot "../schemas/$Kind.schema.json"
        $schemaErrors = @()
        $valid = Test-Json -Json $json -SchemaFile $schema -ErrorVariable schemaErrors -ErrorAction SilentlyContinue
        if (-not $valid) {
            if ($schemaErrors.Count -eq 0) { '$: schema validation failed' }
            foreach ($issue in $schemaErrors) {
                $message = ($issue.ToString() -replace '\s+', ' ').Trim()
                "`$: $message"
            }
            return
        }
        if ($Kind -eq 'personalisation') {
            Get-PsAiReferenceIssues -Data $data
            Get-PsAiProviderIssues -Data $data
        }
    } catch {
        $message = ($_.Exception.Message -replace '\s+', ' ').Trim()
        "`$: $message"
    }
}

if (-not $NoRun) {
    $issues = @(Invoke-PsAiValidation -Kind $Kind -Path $Path)
    if ($issues.Count -gt 0) {
        $issues | Write-Output
        exit 1
    }
}
