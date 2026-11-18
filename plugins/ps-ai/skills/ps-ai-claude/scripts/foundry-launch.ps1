param($Agent, [string]$HomeRoot, $Token)

$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
$launch = @{ Set = @{}; Clear = [string[]]@(); ProvidersFile = $null; ProvidersJson = $null; Notice = $null }
$launch.Set = @{
    CLAUDE_CONFIG_DIR = $folder
    CLAUDE_CODE_USE_FOUNDRY = '1'
    ANTHROPIC_FOUNDRY_BASE_URL = $Agent.provider.endpoint + '/anthropic'
    ANTHROPIC_MODEL = $Agent.provider.default
}
foreach ($deployment in $Agent.provider.deployments) {
    if ($deployment.alias) { $launch.Set['ANTHROPIC_DEFAULT_' + $deployment.alias.ToUpperInvariant() + '_MODEL'] = $deployment.name }
}
$launch.Clear = [string[]]@(
    'ANTHROPIC_FOUNDRY_RESOURCE', 'ANTHROPIC_FOUNDRY_API_KEY', 'ANTHROPIC_FOUNDRY_AUTH_TOKEN', 'ANTHROPIC_SMALL_FAST_MODEL',
    'CLAUDE_CODE_USE_BEDROCK', 'CLAUDE_CODE_USE_VERTEX', 'CLAUDE_CODE_USE_ANTHROPIC_AWS',
    'CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD', 'CLAUDE_CODE_USE_MANTLE', 'CLAUDE_CODE_USE_GATEWAY'
)
return $launch
