$root = Split-Path $PSScriptRoot -Parent
$accountScript = Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1'
$homeRoot = Join-Path $root ('.agents/temp/fresh-home-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $homeRoot -Force | Out-Null
try {
    $fake = Join-Path $homeRoot 'external.ps1'
    'exit 0' | Set-Content $fake
    $file = Join-Path $homeRoot '.legion/configuration/ps-ai-personalisation.json'
    # A fresh machine has no settings yet; the first add creates them.
    & $accountScript -Action add -Id codex-a -Tool codex -Command $fake -HomeRoot $homeRoot | Out-Null
    Assert-True (Test-Path -LiteralPath $file) 'First add creates settings'
    $data = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
    Assert-Equal 1 $data.schemaVersion 'Created settings use format 1'
    Assert-Equal 'codex-a' (@($data.agents)[0].id) 'First add records the agent'
    Assert-Equal 0 @($data.channels).Count 'Created settings have no channels'
    $other = Join-Path $root ('.agents/temp/fresh-home-' + [guid]::NewGuid().ToString('N'))
    try {
        $message = ''
        try { & $accountScript -Action remove -Id codex-a -HomeRoot $other | Out-Null } catch { $message = $_.Exception.Message }
        Assert-True ($message -like '*No ps-ai settings yet*') "Other actions explain missing settings ($message)"
    } finally {
        if (Test-Path -LiteralPath $other) { Remove-Item -LiteralPath $other -Recurse -Force }
    }
} finally {
    Remove-Item -LiteralPath $homeRoot -Recurse -Force
}
