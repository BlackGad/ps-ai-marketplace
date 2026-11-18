param([switch]$Check, [switch]$NoRun)

. (Join-Path $PSScriptRoot '../plugins/ps-ai/bin/PsAi.Tools.ps1')

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
    $index = [ordered]@{ schemaVersion = 1; bootstrap = $Bootstrap; tools = $entries }
    return ($index | ConvertTo-Json -Depth 100).Replace("`r`n", "`n") + "`n"
}

if ($NoRun) { return }

$tools = @(Get-PsAiTools)
$recipes = Get-PsAiInstallRecipes
$content = Get-ToolsIndexContent -Tools $tools -Bootstrap $recipes.pwsh
$bytes = [Text.UTF8Encoding]::new($false).GetBytes($content)
$path = Join-Path $PSScriptRoot '../tools.json'
if ((Test-Path -LiteralPath $path) -and
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($path)) -ceq [Convert]::ToBase64String($bytes)) {
    'skip: tools index (already done)'
    return
}
if ($Check) { throw 'tools index is missing or out of date; run tools/update-tools-index.ps1' }
[IO.File]::WriteAllBytes($path, $bytes)
'updated: tools index'
