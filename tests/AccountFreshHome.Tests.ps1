$root = Split-Path $PSScriptRoot -Parent
$accountScript = Join-Path $root 'plugins/ps-ai/bin/legion-account.ps1'
$homeRoot = Join-Path $root ('.agents/temp/fresh-home-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $homeRoot -Force | Out-Null
try {
    $fake = Join-Path $homeRoot 'external.ps1'
    'throw "Account setup must not run the tool"' | Set-Content $fake
    $file = Join-Path $homeRoot '.legion/configuration/personalisation.json'
    # Invalid first adds must not create empty settings or settings folders.
    foreach ($action in @('add', 'register')) {
        foreach ($invalid in @(@{Id='Bad id';Tool='codex'}, @{Id='codex-a';Tool='unknown-tool'})) {
            $failedHome = Join-Path $homeRoot ("failed-$action-" + $invalid.Tool)
            $parameters = @{Action=$action;Command=$fake;HomeRoot=$failedHome}
            if ($action -eq 'register') { $parameters.ConfigDir = $homeRoot }
            Assert-Throws { & $accountScript @parameters @invalid | Out-Null } "$action rejects invalid first agent"
            Assert-True (-not (Test-Path (Join-Path $failedHome '.legion'))) "Failed $action creates no settings folder"
        }
    }

    # Replace discovery in a plugin copy: no Azure tool, real home, PATH change, or network.
    $plugin = Join-Path $homeRoot 'plugin'
    Copy-Item (Join-Path $root 'plugins/ps-ai') $plugin -Recurse
    @'
function Test-FoundryToken {
    param([switch]$Login)
    return @{Ok=$true;Error=''}
}
function Get-FoundryDeployments {
    param($Endpoint, $Tool)
    return @{Source='management';Error='';Deployments=@(@{name='gpt-fixture';model='gpt-fixture'})}
}
'@ | Add-Content (Join-Path $plugin 'bin/lib/foundry.ps1')
    $listHome = Join-Path $homeRoot 'list-only'
    $listed = & (Join-Path $plugin 'bin/legion-account.ps1') -Action add -Id codex-a -Tool codex -Provider foundry -Endpoint 'https://example.invalid' -List -HomeRoot $listHome | ConvertFrom-Json
    Assert-Equal 'gpt-fixture' $listed.deployments[0].name 'Fresh-home Foundry list uses fake discovery'
    Assert-True (-not (Test-Path (Join-Path $listHome '.legion'))) 'Fresh-home Foundry list writes no settings or folders'

    # A fresh machine has no settings yet; the first add creates them.
    & $accountScript -Action add -Id codex-a -Tool codex -Command $fake -HomeRoot $homeRoot | Out-Null
    Assert-True (Test-Path -LiteralPath $file) 'First add creates settings'
    $data = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    Assert-Equal 1 $data.schemaVersion 'Created settings use format 1'
    Assert-Equal 'codex-a' (@($data.agents)[0].id) 'First add records the agent'
    Assert-Equal 0 @($data.channels).Count 'Created settings have no channels'
    $registerHome = Join-Path $homeRoot 'registered'
    & $accountScript -Action register -Id codex-registered -Tool codex -Command $fake -ConfigDir $homeRoot -HomeRoot $registerHome | Out-Null
    $registered = Get-Content (Join-Path $registerHome '.legion/configuration/personalisation.json') -Raw | ConvertFrom-Json
    Assert-Equal 'codex-registered' $registered.agents[0].id 'First register saves the agent'
    Assert-Equal $homeRoot $registered.agents[0].configDir 'First register keeps the existing tool folder'
    Assert-Equal 1 $registered.schemaVersion 'First register uses format 1'
    Assert-Equal 0 @($registered.channels).Count 'First register starts with no channels'
    $other = Join-Path $root ('.agents/temp/fresh-home-' + [guid]::NewGuid().ToString('N'))
    try {
        foreach ($action in @('remove', 'rename', 'models')) {
            $message = ''
            try { & $accountScript -Action $action -Id codex-a -HomeRoot $other | Out-Null } catch { $message = $_.Exception.Message }
            Assert-Equal 'No ps-ai settings yet; add an agent first.' $message "$action explains missing settings"
            Assert-True (-not (Test-Path -LiteralPath $other)) "$action creates no settings or folders"
        }
    } finally {
        if (Test-Path -LiteralPath $other) {
            $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
            if (-not [IO.Path]::GetFullPath($other).StartsWith($allowed)) { throw 'Unsafe fresh-home fixture cleanup' }
            Remove-Item -LiteralPath $other -Recurse -Force
        }
    }
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp')) + [IO.Path]::DirectorySeparatorChar
    if (-not [IO.Path]::GetFullPath($homeRoot).StartsWith($allowed)) { throw 'Unsafe fresh-home fixture cleanup' }
    Remove-Item -LiteralPath $homeRoot -Recurse -Force
}
