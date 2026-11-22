$root = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $root 'plugins/legion/bin/legion-foundry.ps1'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('legion-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
. (Join-Path $PSScriptRoot 'FakeAz.ps1')
$saved = @{}
foreach ($name in @('PATH', 'LEGION_FAKE_AZ', 'LEGION_FAKE_AZ_LOG', 'LEGION_PRIVACY_LOG')) { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
$fakeRoot = $null
try {
    $config = Join-Path $tempRoot '.legion/configuration'
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    @{ agents = @(@{ id = 'copilot-dev'; tool = 'copilot'; configDir = '~/copilot'; provider = @{
        kind = 'foundry'; endpoint = 'https://res-a.cognitiveservices.azure.com'; default = 'claude-opus-x'; deployments = @(@{ name = 'claude-opus-x' })
    } }) } | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $config 'personalisation.json')
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
    $mode = if ($IsLinux) { & /usr/bin/stat -c '%a' -- $file } else { & /usr/bin/stat -f '%Lp' $file }
    $private = $LASTEXITCODE -eq 0 -and $mode -eq '600'
}
@{ Private = $private; HasToken = ([IO.File]::ReadAllText($file).Contains('FAKE-NONCREDENTIAL')); File = $file } | ConvertTo-Json | Set-Content $env:LEGION_PRIVACY_LOG
exit 0
'@ | Set-Content (Join-Path $fakeTools 'copilot.ps1')
    $expiresOn = [DateTimeOffset]::UtcNow.AddMinutes(37)
    Use-FakeAz -Answers @{ 'account get-access-token --resource https://cognitiveservices.azure.com' = @{
        exit = 0; stdout = (@{ accessToken = 'FAKE-NONCREDENTIAL'; expires_on = $expiresOn.ToUnixTimeSeconds() } | ConvertTo-Json -Compress)
    } }
    $fakeRoot = Split-Path $env:LEGION_FAKE_AZ -Parent
    $env:PATH = @($fakeTools, (Join-Path $PSScriptRoot 'fixtures/fake-az'), $PSHOME, $(if ($IsWindows) { $null } else { "/bin:/usr/bin" })) -join [IO.Path]::PathSeparator
    $env:LEGION_PRIVACY_LOG = Join-Path $tempRoot 'privacy.json'
    $pwshPath = (Get-Process -Id $PID).Path
    $output = @(& $pwshPath -NoProfile -File $runner -Agent copilot-dev -HomeRoot $tempRoot 2>&1)
    Assert-Equal 0 $LASTEXITCODE 'Copilot privacy fake succeeds'
    $observation = Get-Content $env:LEGION_PRIVACY_LOG -Raw | ConvertFrom-Json
    Assert-True $observation.HasToken 'Provider file contains the fake token during launch'
    Assert-True $observation.Private 'Provider file grants access only to current owner'
    Assert-True (-not (Test-Path -LiteralPath $observation.File)) 'Private provider file is removed after launch'
    Assert-True (-not (($output -join "`n").Contains('FAKE-NONCREDENTIAL'))) 'Runner output does not expose fake token'

    # Unix: the file is created owner read/write only, and the chmod command never runs.
    if (-not $IsWindows) {
        . $runner -NoRun
        function chmod { throw 'The chmod command was used' }
        $modeFile = Join-Path $tempRoot 'mode.json'
        Write-FoundryProviderFile -Path $modeFile -Json 'FAKE-NONCREDENTIAL'
        Assert-Equal ([IO.UnixFileMode]'UserRead, UserWrite') ([IO.File]::GetUnixFileMode($modeFile)) 'Provider file is owner read and write only'
        Assert-Equal 'FAKE-NONCREDENTIAL' ([IO.File]::ReadAllText($modeFile)) 'Provider file holds the written bytes'
        Assert-Throws { Write-FoundryProviderFile -Path $modeFile -Json 'FAKE-OTHER' } 'An existing provider file is never overwritten'
    }
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
    if ($fakeRoot -and (Test-Path -LiteralPath $fakeRoot)) { Remove-Item -LiteralPath $fakeRoot -Recurse -Force }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
