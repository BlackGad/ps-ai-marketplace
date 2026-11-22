param($Agent, [string]$HomeRoot, $Token)

. (Join-Path $PSScriptRoot '../../../bin/lib/paths.ps1')

$folder = Resolve-LegionHomePath -Path $Agent.configDir -HomeRoot $HomeRoot
$launch = @{ Set = @{}; Clear = [string[]]@(); ProvidersFile = $null; ProvidersJson = $null; Notice = $null }
if (-not $Token) { $Token = Get-FoundryToken }
$tempFolder = Get-LegionHomePath -HomeRoot $HomeRoot -Path 'temp'
$now = [DateTimeOffset]::UtcNow
$guidPattern = '[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
if (Test-Path -LiteralPath $tempFolder) {
    foreach ($file in Get-ChildItem -LiteralPath $tempFolder -File -Filter 'copilot-providers-*.json') {
        if ($file.Name -match "^copilot-providers-([0-9]+)-$guidPattern\.json$") {
            $expirySeconds = 0L
            if ([long]::TryParse($Matches[1], [ref]$expirySeconds) -and $expirySeconds -le $now.ToUnixTimeSeconds()) {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
            }
        }
    }
}
$launch.ProvidersFile = Join-Path $tempFolder ('copilot-providers-' + $Token.ExpiresOn.ToUnixTimeSeconds() + '-' + [guid]::NewGuid() + '.json')
$launch.Set = @{ COPILOT_HOME = $folder; COPILOT_PROVIDERS_CONFIG = $launch.ProvidersFile }
$launch.ProvidersJson = @{
    providers = @(@{
        name = 'legion-foundry'; type = 'anthropic'; baseUrl = $Agent.provider.endpoint + '/anthropic'
        bearerToken = $Token.Token; headers = @{ 'anthropic-version' = '2023-06-01' }
    })
    models = @($Agent.provider.deployments | ForEach-Object {
        $model = if ($_.model) { $_.model } else { $_.name }
        @{ id = $_.name; provider = 'legion-foundry'; modelId = $model; wireModel = $_.name }
    })
} | ConvertTo-Json -Depth 100
$expiry = $Token.ExpiresOn.ToLocalTime().ToString('HH:mm')
$launch.Notice = "token valid until $expiry; after that restart with: $($Agent.id) --resume"
return $launch
