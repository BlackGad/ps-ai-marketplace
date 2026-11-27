$testBase = Split-Path $PSScriptRoot -Parent
$root = Split-Path $testBase -Parent
$claudeMarket = Get-Content -Raw (Join-Path $root '.claude-plugin/marketplace.json') | ConvertFrom-Json
$codexMarket = Get-Content -Raw (Join-Path $root '.agents/plugins/marketplace.json') | ConvertFrom-Json
$claudePlugin = Get-Content -Raw (Join-Path $root 'plugins/legion/.claude-plugin/plugin.json') | ConvertFrom-Json
$codexPlugin = Get-Content -Raw (Join-Path $root 'plugins/legion/.codex-plugin/plugin.json') | ConvertFrom-Json
$copilotPlugin = Get-Content -Raw (Join-Path $root 'plugins/legion/plugin.json') | ConvertFrom-Json
Assert-Equal 'ps-legion-marketplace' $claudeMarket.name 'Claude marketplace name'
Assert-True ([bool]$claudeMarket.owner.name) 'Claude marketplace owner'
Assert-Equal 1 @($claudeMarket.plugins).Count 'Claude marketplace plugin count'
Assert-Equal 'legion' $claudeMarket.plugins[0].name 'Claude plugin entry'
Assert-Equal './plugins/legion' $claudeMarket.plugins[0].source 'Claude plugin source'
Assert-Equal 'local' $codexMarket.plugins[0].source.source 'Codex source kind'
Assert-Equal './plugins/legion' $codexMarket.plugins[0].source.path 'Codex source path'
Assert-Equal 'AVAILABLE' $codexMarket.plugins[0].policy.installation 'Codex installation policy'
Assert-True ([bool]$codexMarket.plugins[0].category) 'Codex category'
foreach ($manifest in @($claudePlugin, $codexPlugin, $copilotPlugin)) {
    Assert-Equal 'legion' $manifest.name 'Plugin manifest name'
}
Assert-Equal './skills/' $codexPlugin.skills 'Codex skills path'
Assert-Equal './hooks/hooks.json' $codexPlugin.hooks 'Codex hooks path'
Assert-Equal 'skills/' $copilotPlugin.skills 'Copilot skills path'
Assert-Equal 'hooks/copilot-hooks.json' $copilotPlugin.hooks 'Copilot hooks path'
Get-ChildItem (Join-Path $root 'plugins/legion/skills') -Directory | ForEach-Object {
    Assert-True ($_.Name.StartsWith('legion-') -and $_.Name -cmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$' -and $_.Name.Length -le 64) "Skill folder $($_.Name) is a valid legion skill name"
    $content = Get-Content -Raw (Join-Path $_.FullName 'SKILL.md')
    Assert-True ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') "Frontmatter in $($_.Name)"
    $frontmatter = $Matches[1]
    Assert-True ($frontmatter -match "(?m)^name:\s*$([regex]::Escape($_.Name))\s*$") "Skill name $($_.Name)"
    Assert-True ($frontmatter -match '(?m)^description:\s*Use when') "Skill description $($_.Name)"
}

# NeutralHookFormatAndManifestPaths: both native invocations retain their required root.
$neutralHooks = Get-Content -Raw (Join-Path $root 'plugins/legion/hooks/copilot-hooks.json') | ConvertFrom-Json
$sessionHook = $neutralHooks.hooks.sessionStart[0]
# The literal strings are run in their shells by tests/python/legion/test_hook_commands.py.
$uv = 'uv run --no-project --no-python-downloads --offline --quiet --python ">=3.12" '
$fallback = 'legion: uv or Python 3.12 is missing, so mode detection did not run; run the legion installer. If LEGION_ROLE=member is set, load the legion-member skill.'
$fallbackJson = '{"additionalContext":"' + $fallback + '"}'
Assert-Equal ($uv + '"$env:COPILOT_PLUGIN_ROOT\hooks\session_start.py" --format context-json; if (-not $?) { ''' + $fallbackJson + ''' }') $sessionHook.powershell 'PowerShell hook uses neutral context format'
Assert-Equal ($uv + '"$COPILOT_PLUGIN_ROOT/hooks/session_start.py" --format context-json || echo ''' + $fallbackJson + '''') $sessionHook.bash 'Bash hook uses neutral context format'
$sharedHooks = Get-Content -Raw (Join-Path $root 'plugins/legion/hooks/hooks.json') | ConvertFrom-Json
Assert-True ([bool]$sharedHooks.hooks.SessionStart) 'Shared hook stays at required path'
$sharedHook = $sharedHooks.hooks.SessionStart[0].hooks[0]
Assert-Equal ($uv + '"${CLAUDE_PLUGIN_ROOT}/hooks/session_start.py" --format text || echo "' + $fallback + '"') $sharedHook.command 'Shared hook runs the Python hook through uv'
Assert-Equal ($uv + '"$env:CLAUDE_PLUGIN_ROOT\hooks\session_start.py" --format text; if (-not $?) { ''' + $fallback + ''' }') $sharedHook.commandWindows 'Codex on Windows runs the Python hook through PowerShell'
