param([switch]$Check, [switch]$NoRun)

. (Join-Path $PSScriptRoot '../plugins/ps-ai/bin/lib/tools.ps1')

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
    # The standalone installer only consumes this Windows bootstrap subset.
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

$tools = @(Get-LegionTools)
# Only the standalone installer consumes this bootstrap recipe.
$bootstrapJson = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'bootstrap.json') -Raw
$schema = Get-Content -LiteralPath (Join-Path $PSScriptRoot '../plugins/ps-ai/schemas/tool.schema.json') -Raw | ConvertFrom-Json -AsHashtable
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
$path = Join-Path $PSScriptRoot '../plugins/ps-ai/tools.json'
if ((Test-Path -LiteralPath $path) -and
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ceq [Convert]::ToBase64String($bytes)) {
    'skip: tools index (already done)'
    return
}
if ($Check) { throw 'tools index is missing or out of date; run tools/update-tools-index.ps1' }
[IO.File]::WriteAllBytes($path, $bytes)
'updated: tools index'
