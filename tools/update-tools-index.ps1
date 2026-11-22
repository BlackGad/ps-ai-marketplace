param([switch]$Check, [switch]$NoRun)

. (Join-Path $PSScriptRoot '../plugins/legion/bin/lib/channels.ps1')

function Assert-LegionRegex {
    param([string]$Pattern, [string]$Field)

    try { $null = [regex]::new($Pattern) }
    catch { throw "invalid regex in $Field" }
}

function Assert-LegionInstallPatterns {
    param($Install)

    foreach ($method in @('msi', 'zip')) {
        $download = $Install.windows.download.$method
        if ($null -ne $download.assetPattern) { Assert-LegionRegex -Pattern $download.assetPattern -Field "install.windows.download.$method.assetPattern" }
    }
}

# Needs are one level: each need is a known helper, and a helper needs nothing itself.
function Assert-LegionInstallNeeds {
    param([string]$Tool, [string]$Platform, [hashtable]$Recipes, [string[]]$HelperIds)

    foreach ($need in $Recipes[$Tool].$Platform.needs) {
        if ($need -cnotin $HelperIds) { throw "unknown helper prerequisite '$need' for '$Tool'" }
        if (@($Recipes[$need].$Platform.needs).Count) { throw "helper '$need' cannot have prerequisites" }
    }
}

function Get-ToolsIndexTools {
    param([string]$SkillsRoot = (Join-Path $PSScriptRoot '../plugins/legion/skills'))

    $schemaPath = Join-Path $PSScriptRoot '../plugins/legion/schemas/tool.schema.json'
    $tools = [System.Collections.Generic.List[object]]::new()
    foreach ($tool in @(Get-LegionTools -SkillsRoot $SkillsRoot)) { $tools.Add($tool) }
    $tools.Sort([Comparison[object]]{ param($left, $right) [StringComparer]::Ordinal.Compare($left.SkillRoot, $right.SkillRoot) })
    foreach ($tool in $tools) {
        $path = Join-Path $tool.SkillRoot 'tool.json'
        $json = [IO.File]::ReadAllText($path)
        if ($tool.schemaVersion -ne 1) { throw "invalid tool descriptor '$path': unsupported schemaVersion" }
        if (-not (Test-Json -Json $json -SchemaFile $schemaPath -ErrorAction SilentlyContinue)) {
            throw "invalid tool descriptor '$path': schema validation failed"
        }
        if ($tool.plugin.listing.format -eq 'lines') {
            Assert-LegionRegex -Pattern $tool.plugin.listing.rejectPattern -Field 'plugin.listing.rejectPattern'
        }
        Assert-LegionInstallPatterns -Install $tool.install
    }

    # Check duplicate ids first, so a mismatched folder cannot hide the collision.
    $ids = @()
    foreach ($tool in $tools) {
        if ($tool.id -cin $ids) { throw "duplicate tool id '$($tool.id)'" }
        $ids += $tool.id
    }
    foreach ($tool in $tools) {
        if ((Split-Path $tool.SkillRoot -Leaf) -cne "legion-$($tool.id)") {
            throw "tool id '$($tool.id)' does not match its skill directory"
        }
        if (-not (Test-Path -LiteralPath (Join-Path $tool.SkillRoot 'SKILL.md') -PathType Leaf)) {
            throw "tool '$($tool.id)' requires SKILL.md"
        }
        if ($null -ne $tool.foundry) { $null = Get-LegionToolScript -Tool $tool -Name foundry-launch }
    }
    $tools.Sort([Comparison[object]]{ param($left, $right) [StringComparer]::Ordinal.Compare($left.id, $right.id) })
    $tools
}

function Get-ToolsIndexChannels {
    param([string]$SkillsRoot = (Join-Path $PSScriptRoot '../plugins/legion/skills'))
    $tools = @(Get-ToolsIndexTools -SkillsRoot $SkillsRoot)
    $ids = @()
    foreach ($data in @(Get-LegionChannels -SkillsRoot $SkillsRoot)) {
        $path = Join-Path $data.SkillRoot 'channel.json'
        $folder = Get-Item -LiteralPath $data.SkillRoot
        # SkillRoot is runtime metadata, not part of the descriptor contract.
        $data = ConvertFrom-LegionToolJson ([IO.File]::ReadAllText($path))
        $keys = @($data.PSObject.Properties.Name)
        foreach ($required in @('schemaVersion', 'id', 'launch')) {
            if ($required -cnotin $keys) { throw "invalid channel descriptor '$path'" }
        }
        foreach ($key in $keys) {
            if ($key -cnotin @('schemaVersion', 'id', 'launch', 'ready', 'state')) { throw "invalid channel descriptor '$path'" }
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

function Get-ToolsIndexRecipes {
    param(
        [string]$SkillsRoot = (Join-Path $PSScriptRoot '../plugins/legion/skills'),
        [string]$HelpersPath = (Join-Path $PSScriptRoot '../plugins/legion/bin/install-tool/helpers.json')
    )

    $tools = @(Get-ToolsIndexTools -SkillsRoot $SkillsRoot)
    # Helpers are read only for installation; the private launch runtime omits them.
    $resolvedHelpersPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($HelpersPath)
    $json = [IO.File]::ReadAllText($resolvedHelpersPath)
    $schema = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../plugins/legion/schemas/tool.schema.json') -Raw | ConvertFrom-Json -AsHashtable
    $helpersSchema = @{
        '$schema' = $schema.'$schema'
        '$defs' = $schema.'$defs'
        type = 'object'
        propertyNames = @{ pattern = '^[a-z][a-z0-9-]*$' }
        additionalProperties = @{ '$ref' = '#/$defs/install' }
    } | ConvertTo-Json -Depth 100
    if (-not (Test-Json -Json $json -Schema $helpersSchema -ErrorAction SilentlyContinue)) {
        throw "invalid helper recipes '$HelpersPath': schema validation failed"
    }
    $helpers = ConvertFrom-LegionToolJson -Json $json
    $recipes = @{}
    foreach ($helper in $helpers.PSObject.Properties) {
        Assert-LegionInstallPatterns -Install $helper.Value
        $recipes[$helper.Name] = $helper.Value
    }
    foreach ($tool in $tools) {
        if ($recipes.ContainsKey($tool.id)) { throw "helper/tool id collision '$($tool.id)'" }
        $recipes[$tool.id] = $tool.install
    }
    $helperIds = [string[]]@($helpers.PSObject.Properties.Name)
    foreach ($id in $recipes.Keys) {
        foreach ($platform in @('macos', 'linux')) {
            Assert-LegionInstallNeeds -Tool $id -Platform $platform -Recipes $recipes -HelperIds $helperIds
        }
    }
    return $recipes
}

function Get-ToolsIndexContent {
    param([object[]]$Tools, $Bootstrap)

    $sorted = [System.Collections.Generic.List[object]]::new()
    foreach ($tool in $Tools) { $sorted.Add($tool) }
    $sorted.Sort([Comparison[object]]{ param($left, $right) [StringComparer]::Ordinal.Compare($left.id, $right.id) })
    $entries = @(
        foreach ($tool in $sorted) {
            [ordered]@{
                id = $tool.id
                command = $tool.command
                configEnv = $tool.configEnv
                plugin = $tool.plugin
                hooks = $tool.hooks
                installHint = $tool.install.hint
            }
        }
    )
    # Bootstrap entry points consume only these PowerShell download recipes.
    $bootstrapEntry = [ordered]@{
        windows = [ordered]@{
            wingetId = $Bootstrap.windows.wingetId
            portableCommand = $Bootstrap.windows.portableCommand
            download = [ordered]@{ zip = $Bootstrap.windows.download.zip }
        }
    }
    $index = [ordered]@{ schemaVersion = 1; bootstrap = $bootstrapEntry; tools = $entries }
    return ($index | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"
}

if ($NoRun) { return }

$tools = @(Get-ToolsIndexTools)
$null = Get-ToolsIndexChannels
$null = Get-ToolsIndexRecipes
# Only the standalone installer consumes this bootstrap recipe.
$bootstrapJson = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bootstrap.json') -Raw
$schema = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../plugins/legion/schemas/tool.schema.json') -Raw | ConvertFrom-Json -AsHashtable
$windows = $schema.'$defs'.install.properties.windows
$windows.type = 'object'
$windows.properties.download.required = @('zip')
$windows.properties.download.properties.Remove('msi')
$bootstrapSchema = @{
    '$defs' = $schema.'$defs'; type = 'object'; required = @('windows'); additionalProperties = $false
    properties = @{windows = $windows}
} | ConvertTo-Json -Depth 100
if (-not (Test-Json -Json $bootstrapJson -Schema $bootstrapSchema -ErrorAction SilentlyContinue)) { throw 'invalid PowerShell bootstrap recipe' }
$bootstrap = ConvertFrom-LegionToolJson -Json $bootstrapJson
Assert-LegionInstallPatterns -Install $bootstrap
$content = Get-ToolsIndexContent -Tools $tools -Bootstrap $bootstrap
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($content)
$path = Join-Path $PSScriptRoot '../plugins/legion/tools.json'
if ((Test-Path -LiteralPath $path) -and
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ceq [Convert]::ToBase64String($bytes)) {
    'skip: tools index (already done)'
    return
}
if ($Check) { throw 'tools index is missing or out of date; run tools/update-tools-index.ps1' }
[IO.File]::WriteAllBytes($path, $bytes)
'updated: tools index'
