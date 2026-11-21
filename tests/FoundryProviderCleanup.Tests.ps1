$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'plugins/ps-ai/bin/legion-foundry.ps1') -NoRun
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('ps-ai-tests/' + [guid]::NewGuid())
$folder = Join-Path $tempRoot '.legion/temp'
New-Item -ItemType Directory -Path $folder -Force | Out-Null
try {
    $now = [DateTimeOffset]::UtcNow
    $expired = Join-Path $folder ('copilot-providers-' + $now.AddMinutes(-2).ToUnixTimeSeconds() + '-' + [guid]::NewGuid() + '.json')
    $fresh = Join-Path $folder ('copilot-providers-' + $now.AddMinutes(20).ToUnixTimeSeconds() + '-' + [guid]::NewGuid() + '.json')
    $unrelated = Join-Path $folder 'owner-providers.json'
    $similar = Join-Path $folder 'copilot-providers-owner.json'
    foreach ($file in @($expired, $fresh, $unrelated, $similar)) { [IO.File]::WriteAllText($file, 'fixture without credential') }
    foreach ($file in @($fresh, $unrelated, $similar)) { [IO.File]::SetLastWriteTimeUtc($file, $now.AddHours(-2).UtcDateTime) }
    $copilotAgent = @{ id = 'copilot-dev'; tool = 'copilot'; configDir = '~/copilot'; provider = @{
        endpoint = 'https://res-a.cognitiveservices.azure.com'; deployments = @(@{ name = 'claude-opus-x' })
    } }
    $token = @{ Token = 'FAKE-NONCREDENTIAL'; ExpiresOn = $now.AddMinutes(37) }
    $launch = Get-FoundryLaunch -Agent $copilotAgent -HomeRoot $tempRoot -Token $token
    Assert-True (-not (Test-Path -LiteralPath $expired)) 'Each launch removes expired provider leftovers regardless of file age'
    foreach ($file in @($fresh, $unrelated, $similar)) { Assert-True (Test-Path -LiteralPath $file) 'Fresh and unrelated files remain untouched' }
    Assert-True ((Split-Path $launch.ProvidersFile -Leaf).StartsWith('copilot-providers-' + $token.ExpiresOn.ToUnixTimeSeconds() + '-')) 'Provider filename records exact token expiry'
    Assert-True (-not (Test-Path -LiteralPath $launch.ProvidersFile)) 'Launch adapter does not write the credential file'
    $null = Get-FoundryLaunch -Agent $copilotAgent -HomeRoot $tempRoot -Token $token
    foreach ($file in @($fresh, $unrelated, $similar)) { Assert-True (Test-Path -LiteralPath $file) 'Repeat cleanup preserves fresh and unrelated files' }
} finally { Remove-Item -LiteralPath $tempRoot -Recurse -Force }
