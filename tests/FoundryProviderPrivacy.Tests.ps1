$root = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $root 'plugins/ps-ai/bin/ps-ai-foundry.ps1'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
. (Join-Path $PSScriptRoot 'FakeAz.ps1')
$saved = @{}
foreach ($name in @('PATH', 'PS_AI_FAKE_AZ', 'PS_AI_FAKE_AZ_LOG', 'PS_AI_PRIVACY_LOG')) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
$fakeRoot = $null
try {
    $config = Join-Path $tempRoot '.agents/configuration'
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    @{ agents = @(@{ id = 'copilot-dev'; tool = 'copilot'; configDir = '~/copilot'; provider = @{
        kind = 'foundry'; endpoint = 'https://res-a.cognitiveservices.azure.com'; default = 'claude-opus-x'; deployments = @(@{ name = 'claude-opus-x' })
    } }) } | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $config 'ps-ai-personalisation.json')
    $fakeTools = Join-Path $tempRoot 'fake-tools'
    New-Item -ItemType Directory -Path $fakeTools -Force | Out-Null
    @'
$file = $env:COPILOT_PROVIDERS_CONFIG
if ($IsWindows) {
    $acl = Get-Acl -LiteralPath $file
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    $private = $acl.AreAccessRulesProtected -and $rules.Count -eq 1 -and $rules[0].IdentityReference.Value -eq $sid -and $rules[0].AccessControlType -eq 'Allow'
} else {
    $private = [IO.File]::GetUnixFileMode($file) -eq ([IO.UnixFileMode]::UserRead -bor [IO.UnixFileMode]::UserWrite)
}
@{ Private = $private; HasToken = ([IO.File]::ReadAllText($file).Contains('FAKE-NONCREDENTIAL')); File = $file } | ConvertTo-Json | Set-Content $env:PS_AI_PRIVACY_LOG
exit 0
'@ | Set-Content (Join-Path $fakeTools 'copilot.ps1')
    $expiresOn = [DateTimeOffset]::UtcNow.AddMinutes(37)
    Use-FakeAz -Answers @{ 'account get-access-token --resource https://cognitiveservices.azure.com' = @{
        exit = 0; stdout = (@{ accessToken = 'FAKE-NONCREDENTIAL'; expires_on = $expiresOn.ToUnixTimeSeconds() } | ConvertTo-Json -Compress)
    } }
    $fakeRoot = Split-Path $env:PS_AI_FAKE_AZ -Parent
    $env:PATH = @($fakeTools, (Join-Path $PSScriptRoot 'fixtures/fake-az'), $PSHOME) -join [IO.Path]::PathSeparator
    $env:PS_AI_PRIVACY_LOG = Join-Path $tempRoot 'privacy.json'
    $pwshPath = (Get-Process -Id $PID).Path
    $output = @(& $pwshPath -NoProfile -File $runner -Agent copilot-dev -HomeRoot $tempRoot 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Copilot privacy fake succeeds'
    $observation = Get-Content $env:PS_AI_PRIVACY_LOG -Raw | ConvertFrom-Json
    Assert-True $observation.HasToken 'Provider file contains the fake token during launch'
    Assert-True $observation.Private 'Provider file grants access only to current owner'
    Assert-True (-not (Test-Path -LiteralPath $observation.File)) 'Private provider file is removed after launch'
    Assert-True (-not (($output -join "`n").Contains('FAKE-NONCREDENTIAL'))) 'Runner output does not expose fake token'
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    if ($fakeRoot -and (Test-Path -LiteralPath $fakeRoot)) { Remove-Item -LiteralPath $fakeRoot -Recurse -Force }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
