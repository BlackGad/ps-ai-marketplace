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
    Assert-Equal $copilotPlugin.version $manifest.version 'Plugin manifest versions match'
    Assert-True ($manifest.version -match '^\d+\.\d+\.\d+$') 'Plugin version uses semantic version syntax'
}
Assert-Equal './skills/' $codexPlugin.skills 'Codex skills path'
Assert-Equal './hooks/hooks.json' $codexPlugin.hooks 'Codex hooks path'
Assert-Equal 'skills/' $copilotPlugin.skills 'Copilot skills path'
Assert-Equal 'hooks/copilot-hooks.json' $copilotPlugin.hooks 'Copilot hooks path'
Get-ChildItem (Join-Path $root 'plugins/legion/skills') -Directory | ForEach-Object {
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
$sharedHooks = Get-Content -Raw (Join-Path $root 'plugins/legion/hooks/hooks.json') | ConvertFrom-Json
Assert-True ([bool]$sharedHooks.hooks.SessionStart) 'Shared hook stays at required path'
$sharedHook = $sharedHooks.hooks.SessionStart[0].hooks[0]
Assert-True (Test-Path -LiteralPath (Join-Path $root 'plugins/legion/hooks/session_start.sh') -PathType Leaf) 'Shell bootstrap ships with the hook'
Assert-True ($sharedHook.command.Contains('"${CLAUDE_PLUGIN_ROOT:-}/hooks/session_start.sh" 2>/dev/null && legion_session_start "${CLAUDE_PLUGIN_ROOT:-}/hooks/session_start.py" text')) 'Shared shell hook uses the plugin root and text'
Assert-True ($sessionHook.bash.Contains('"${COPILOT_PLUGIN_ROOT:-}/hooks/session_start.sh" 2>/dev/null && legion_session_start "${COPILOT_PLUGIN_ROOT:-}/hooks/session_start.py" context-json')) 'Copilot shell hook uses the plugin root and JSON'
Assert-True ($sharedHook.commandWindows.Contains('$root = $env:CLAUDE_PLUGIN_ROOT')) 'Shared Windows hook uses the plugin root'
Assert-True ($sessionHook.powershell.Contains('$root = $env:COPILOT_PLUGIN_ROOT;')) 'Copilot Windows hook uses the plugin root'
Assert-True ($sharedHook.commandWindows.Contains('-I -B -S "$root/hooks/session_start.py" --home $legionHome --format $format')) 'Windows bootstrap runs isolated Python'
Assert-True ($sharedHook.commandWindows.Contains('$format = ''text''')) 'Shared Windows hook defaults to text'
Assert-True ($sessionHook.powershell.Contains('/hooks/hooks.json') -and $sessionHook.powershell.Contains('& ([scriptblock]::Create($hook)) $root context-json')) 'Copilot reuses the Windows bootstrap in JSON mode'
foreach ($command in @($sharedHook.command, $sharedHook.commandWindows, $sessionHook.bash, $sessionHook.powershell)) {
    Assert-True (-not $command.Contains('uv run')) 'Session-start hook needs no uv invocation'
    Assert-True ($command.Contains('If LEGION_ROLE=member is set, load the legion-member skill.')) 'Session-start diagnostic retains member guidance'
}
