$repo = Split-Path $PSScriptRoot -Parent
$versions = @(
    foreach ($manifest in @('plugin.json','.claude-plugin/plugin.json','.codex-plugin/plugin.json')) {
        (Get-Content -LiteralPath (Join-Path $repo "plugins/ps-ai/$manifest") -Raw | ConvertFrom-Json).version
    }
)
Assert-Equal 1 @($versions | Select-Object -Unique).Count 'All three plugin manifest versions match'
Assert-Equal '0.3.0' $versions[0] 'Plugin release version is bumped'
