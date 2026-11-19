$repo = Split-Path $PSScriptRoot -Parent
$versions = @(
    foreach ($manifest in @('plugin.json','.claude-plugin/plugin.json','.codex-plugin/plugin.json')) {
        (Get-Content -LiteralPath (Join-Path $repo "plugins/ps-ai/$manifest") -Raw | ConvertFrom-Json).version
    }
)
Assert-Equal 1 @($versions | Select-Object -Unique).Count 'All three plugin manifest versions match'
Assert-True ($versions[0] -match '^\d+\.\d+\.\d+$') 'Plugin version uses semantic version syntax'
