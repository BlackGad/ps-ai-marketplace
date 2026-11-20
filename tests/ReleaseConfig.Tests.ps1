$root = Split-Path $PSScriptRoot -Parent
$configPath = Join-Path $root 'release-please-config.json'
$manifestPath = Join-Path $root '.release-please-manifest.json'
Assert-True (Test-Path -LiteralPath $configPath) 'release-please-config.json exists'
Assert-True (Test-Path -LiteralPath $manifestPath) '.release-please-manifest.json exists'
$config = Get-Content -Raw $configPath | ConvertFrom-Json
$manifest = Get-Content -Raw $manifestPath | ConvertFrom-Json
$package = $config.packages.'.'
Assert-Equal 'simple' $package.'release-type' 'Release type'
Assert-Equal $false $package.'include-component-in-tag' 'Tag has no component'

$expectedPaths = @(
    'plugins/ps-ai/.claude-plugin/plugin.json'
    'plugins/ps-ai/.codex-plugin/plugin.json'
    'plugins/ps-ai/plugin.json'
)
$extraFiles = @($package.'extra-files')
Assert-Equal 3 $extraFiles.Count 'Extra file count'
Assert-Equal ($expectedPaths -join ',') (($extraFiles.path | Sort-Object) -join ',') 'Extra file paths'
foreach ($file in $extraFiles) {
    Assert-Equal 'json' $file.type "Extra file type $($file.path)"
    Assert-Equal '$.version' $file.jsonpath "Extra file jsonpath $($file.path)"
    $plugin = Get-Content -Raw (Join-Path $root $file.path) | ConvertFrom-Json
    Assert-Equal $plugin.version $manifest.'.' "Manifest version matches $($file.path)"
}
