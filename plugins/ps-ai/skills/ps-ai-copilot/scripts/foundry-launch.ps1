param($Agent, [string]$HomeRoot, $Token)

$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
$launch = @{ Set = @{}; Clear = [string[]]@(); ProvidersFile = $null; ProvidersJson = $null; Notice = $null }
if (-not $Token) { $Token = Get-FoundryToken }
$launch.ProvidersFile = Join-Path $HomeRoot ('.agents/temp/copilot-providers-' + [guid]::NewGuid() + '.json')
$launch.Set = @{ COPILOT_HOME = $folder; COPILOT_PROVIDERS_CONFIG = $launch.ProvidersFile }
$launch.ProvidersJson = @{
    providers = @(@{
        name = 'ps-ai-foundry'; type = 'anthropic'; baseUrl = $Agent.provider.endpoint + '/anthropic'
        bearerToken = $Token.Token; headers = @{ 'anthropic-version' = '2023-06-01' }
    })
    models = @($Agent.provider.deployments | ForEach-Object {
        $model = if ($_.model) { $_.model } else { $_.name }
        @{ id = $_.name; provider = 'ps-ai-foundry'; modelId = $model; wireModel = $_.name }
    })
} | ConvertTo-Json -Depth 100
$expiry = $Token.ExpiresOn.ToLocalTime().ToString('HH:mm')
$launch.Notice = "token valid until $expiry; after that restart with: $($Agent.id) --resume"
return $launch
