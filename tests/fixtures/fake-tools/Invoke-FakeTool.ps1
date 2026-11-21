$environment = @{}
foreach ($entry in Get-ChildItem Env:) {
    if ($entry.Name -match '^(CLAUDE_|ANTHROPIC_|COPILOT_HOME$|COPILOT_PROVIDERS_CONFIG$|CODEX_HOME$)') { $environment[$entry.Name] = $entry.Value }
}
$providersExisted = $env:COPILOT_PROVIDERS_CONFIG -and (Test-Path -LiteralPath $env:COPILOT_PROVIDERS_CONFIG)
$providersJson = if ($providersExisted) { Get-Content -LiteralPath $env:COPILOT_PROVIDERS_CONFIG -Raw } else { $null }
@{ environment = $environment; arguments = @($args); providersExisted = [bool]$providersExisted; providersJson = $providersJson } |
    ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $env:LEGION_FAKE_TOOL_LOG
if ($env:LEGION_FAKE_TOOL_EXIT) { exit ([int]$env:LEGION_FAKE_TOOL_EXIT) }
exit 0
