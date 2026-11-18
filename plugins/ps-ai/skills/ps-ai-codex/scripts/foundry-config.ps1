param($Agent, [string]$HomeRoot)

function Get-FoundryTomlMultilineState {
    # Scan strings and comments so table-like prompt text is never treated as TOML syntax.
    param([string]$Line, [string]$Delimiter, [ref]$ArrayDepth)
    for ($i = 0; $i -lt $Line.Length;) {
        if ($Delimiter) {
            if ($Delimiter -ceq '"""' -and $Line[$i] -ceq '\') { $i += 2; continue }
            if ($i + 2 -lt $Line.Length -and $Line.Substring($i, 3) -ceq $Delimiter) { $Delimiter = ''; $i += 3; continue }
            $i++
            continue
        }
        if ($Line[$i] -ceq '#') { break }
        if ($Line[$i] -cin @('"', "'")) {
            $quote = [string]$Line[$i]
            if ($i + 2 -lt $Line.Length -and $Line.Substring($i, 3) -ceq ($quote * 3)) {
                $Delimiter = $quote * 3
                $i += 3
                continue
            }
            $i++
            while ($i -lt $Line.Length) {
                if ($quote -ceq '"' -and $Line[$i] -ceq '\') { $i += 2; continue }
                if ($Line[$i] -ceq $quote) { $i++; break }
                $i++
            }
        } else {
            if ($Line[$i] -ceq '[') { $ArrayDepth.Value++ }
            if ($Line[$i] -ceq ']') { $ArrayDepth.Value-- }
            $i++
        }
    }
    return $Delimiter
}

$folder = [string]$Agent.configDir
if ($folder.StartsWith('~/')) { $folder = Join-Path $HomeRoot $folder.Substring(2) }
$path = Join-Path $folder 'config.toml'
$az = Get-Command az -CommandType Application,ExternalScript -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $az) { throw 'az is not installed; run ps-ai-install-tool.ps1 -Tool az' }
$kept = [System.Collections.Generic.List[string]]::new()
$rootTable = $true
$skipTable = $false
$skipValue = $false
$multiline = ''
$arrayDepth = 0
$tableKey = '(?:model_providers|"model_providers"|''model_providers'')'
$providerKey = '(?:ps-ai-foundry|"ps-ai-foundry"|''ps-ai-foundry'')'
$authKey = '(?:auth|"auth"|''auth'')'
$providerTable = '^\s*\[\s*' + $tableKey + '\s*\.\s*' + $providerKey + '(?:\s*\.\s*' + $authKey + ')?\s*\]\s*(?:#.*)?$'
if (Test-Path -LiteralPath $path) {
    foreach ($line in [IO.File]::ReadAllLines($path)) {
        $outsideValue = -not $multiline -and $arrayDepth -eq 0
        if ($outsideValue -and $line -match '^\s*\[') {
            $rootTable = $false
            $skipTable = $line -cmatch $providerTable
        }
        $replaceKey = $outsideValue -and $rootTable -and $line -cmatch '^\s*(?:model|model_provider|"model"|"model_provider"|''model''|''model_provider'')\s*='
        $skipLine = $skipTable -or $skipValue -or $replaceKey
        $multiline = Get-FoundryTomlMultilineState -Line $line -Delimiter $multiline -ArrayDepth ([ref]$arrayDepth)
        if ($replaceKey -or $skipValue) { $skipValue = [bool]$multiline -or $arrayDepth -gt 0 }
        if ($skipLine) { continue }
        $kept.Add($line)
    }
}
$model = $Agent.provider.default | ConvertTo-Json -Compress
$baseUrl = ($Agent.provider.endpoint + '/openai/v1') | ConvertTo-Json -Compress
$azPath = $az.Source | ConvertTo-Json -Compress
$content = "model = $model`nmodel_provider = `"ps-ai-foundry`"`n" + ($kept -join "`n") + "`n" + @"
[model_providers.ps-ai-foundry]
base_url = $baseUrl
wire_api = "responses"
[model_providers.ps-ai-foundry.auth]
command = $azPath
args = ["account","get-access-token","--resource","https://cognitiveservices.azure.com","--query","accessToken","-o","tsv"]
refresh_interval_ms = 1800000
"@ + "`n"
if ((Test-Path -LiteralPath $path) -and [IO.File]::ReadAllText($path) -ceq $content) {
    return @{ Changed = $false; Path = $path }
}
New-Item -ItemType Directory -Path $folder -Force | Out-Null
[IO.File]::WriteAllText($path, $content, [Text.UTF8Encoding]::new($false))
return @{ Changed = $true; Path = $path }
