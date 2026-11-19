param($Agent, [string]$HomeRoot, $Token)

$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
$launch = @{ Set = @{}; Clear = [string[]]@(); ProvidersFile = $null; ProvidersJson = $null; Notice = $null }
if (-not $Token) { $Token = Get-FoundryToken }
$tempFolder = Join-Path $HomeRoot '.agents/temp'
$now = [DateTimeOffset]::UtcNow
$legacyCutoff = $now - ($Token.ExpiresOn - $now)
$guidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
if (Test-Path -LiteralPath $tempFolder) {
    foreach ($file in Get-ChildItem -LiteralPath $tempFolder -File -Filter 'copilot-providers-*.json') {
        $expired = $false
        if ($file.Name -match "^copilot-providers-([0-9]+)-$guidPattern\.json$") {
            $expirySeconds = 0L
            $expired = [long]::TryParse($Matches[1], [ref]$expirySeconds) -and $expirySeconds -le $now.ToUnixTimeSeconds()
        } elseif ($file.Name -match "^copilot-providers-$guidPattern\.json$") {
            # Older runners did not record expiry. Bound migration cleanup by this token's remaining lifetime.
            $expired = $file.LastWriteTimeUtc -lt $legacyCutoff.UtcDateTime
        }
        if ($expired) { Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop }
    }
}
$launch.ProvidersFile = Join-Path $tempFolder ('copilot-providers-' + $Token.ExpiresOn.ToUnixTimeSeconds() + '-' + [guid]::NewGuid() + '.json')
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
