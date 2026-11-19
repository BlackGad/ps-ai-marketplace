$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/hooks/detect-mode.ps1'
$tempRoot = Join-Path $root ('.agents/temp/restructure/hook-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    # Child hooks use a private cache and a replaced downloader, never the network.
    $hookPlugin = Join-Path $tempRoot 'hook-plugin'
    New-Item -ItemType Directory -Path (Join-Path $hookPlugin 'hooks'), (Join-Path $hookPlugin 'bin') -Force | Out-Null
    foreach ($file in @('hooks/detect-mode.ps1','bin/PsAi.Common.ps1','bin/PsAi.Tools.ps1','bin/ps-ai-update.ps1','plugin.json')) {
        Copy-Item (Join-Path $root "plugins/ps-ai/$file") (Join-Path $hookPlugin $file)
    }
    @'
function Get-PsAiUpdateHome { Join-Path $PSScriptRoot '../../home' }
function Get-PsAiUpdateText { throw 'offline fixture' }
'@ | Add-Content (Join-Path $hookPlugin 'bin/ps-ai-update.ps1')
    $script = Join-Path $hookPlugin 'hooks/detect-mode.ps1'
    $fixtureRepo = Join-Path $tempRoot 'repo'
    $state = Join-Path $fixtureRepo '.agents/state'
    $temp = Join-Path $fixtureRepo '.agents/temp'
    New-Item -ItemType Directory -Path $state, $temp -Force | Out-Null
    $handoff = Join-Path $state 'handoff.md'
    $lease = Join-Path $temp 'overseer.lock'
    $content = "## Branch`nfeat/x`n## Milestone`nM1`n## State`nTasks`n## Current task`ntask 2 of 4`n"
    $content += "## Legion running`nnone`n## Next action`nreview`n## Open decisions`nnone`n"
    $content += "## Postponed`nnone`n## Recent evidence`nnone`n"
    Set-Content -Path $handoff -Value $content -Encoding utf8
    . $script -NoRun
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{ PS_AI_ROLE = 'legion'; PS_AI_TASK = 'x.md' }
    Assert-Equal 'legion' $mode.Mode 'Legion mode takes precedence'
    Assert-True ($mode.Text -match 'x.md' -and $mode.Text -match 'cannot summon') 'Legion context'
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{ PS_AI_ROLE = 'legion' }
    Assert-Equal 'none' $mode.Mode 'Missing task disables legion'
    Assert-Equal 'ps-ai: PS_AI_ROLE=legion without PS_AI_TASK; ignored.' $mode.Text 'Missing task warning'
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{}
    Assert-Equal 'orchestrated' $mode.Mode 'Handoff enables hint'
    Assert-Equal 'free' $mode.Lease 'No lease is free'
    Assert-True ($mode.Text -match 'M1; task 2 of 4') 'Handoff milestone and task'
    $subFolder = Join-Path $fixtureRepo 'src/deep'
    New-Item -ItemType Directory -Path $subFolder -Force | Out-Null
    $mode = Get-PsAiMode -Repo $subFolder -Environment @{}
    Assert-Equal 'orchestrated' $mode.Mode 'Session started in a subfolder finds the repo root'
    Assert-Equal $fixtureRepo (Get-PsAiHookCwd -InputText ('{"cwd":' + ($fixtureRepo | ConvertTo-Json) + '}')) 'Hook stdin cwd'
    Assert-Equal $null (Get-PsAiHookCwd -InputText 'not json') 'Hook stdin that is not JSON is ignored'
    $hookOutput = '{"cwd":' + ($fixtureRepo | ConvertTo-Json) + '}' | pwsh -NoProfile -File $script -Format context-json
    Assert-True ($hookOutput -match 'M1; task 2 of 4') 'Hook run from another folder uses the stdin cwd'
    $hostName = [System.Net.Dns]::GetHostName()
    @{tool='codex'; account='codex-a'; pid=$PID; processStartedAt=(Get-Process -Id $PID).StartTime.ToUniversalTime().ToString('o'); host=$hostName; startedAt='2026-11-18T10:00:00Z'} |
        ConvertTo-Json | Set-Content -Path $lease
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{}
    Assert-Equal 'held' $mode.Lease 'Live local lease is held'
    Assert-True ($mode.Text -match 'Another overseer is active') 'Held lease warning'
    @{tool='codex'; account='codex-a'; pid=99999999; host=$hostName; startedAt='2026-11-18T10:00:00Z'} |
        ConvertTo-Json | Set-Content -Path $lease
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{}
    Assert-Equal 'stale' $mode.Lease 'Dead local lease is stale'
    Assert-True ($mode.Text -notmatch 'Another overseer') 'Stale lease omits held warning'
    # Agents often write $env:COMPUTERNAME (upper case) while DNS returns mixed case; both name this machine.
    @{tool='codex'; account='codex-a'; pid=99999999; host=$hostName.ToUpperInvariant(); startedAt='2026-11-18T10:00:00Z'} |
        ConvertTo-Json | Set-Content -Path $lease
    Assert-Equal 'stale' (Get-PsAiMode -Repo $fixtureRepo -Environment @{}).Lease 'Host name case does not make a local lease foreign'
    @{tool='claude'; account='claude'; pid=$PID; host='another-host'; startedAt='2026-11-18T10:00:00Z'} |
        ConvertTo-Json | Set-Content -Path $lease
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{}
    Assert-Equal 'foreign' $mode.Lease 'Foreign lease is unknown'
    Assert-True ($mode.Text -match 'ask the owner before taking over') 'Foreign lease warning'
    [System.IO.File]::WriteAllText($handoff, [char]0xFEFF + ($content -replace "`n", "`r`n"))
    Remove-Item $lease
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{}
    Assert-True ($mode.Text -match 'M1; task 2 of 4') 'BOM CRLF handoff'
    Set-Content -Path $lease -Value '{bad json'
    [System.IO.File]::SetLastWriteTimeUtc($lease, [DateTime]::UtcNow.AddMinutes(-5))
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{}
    Assert-Equal 'stale' $mode.Lease 'Old corrupt lease is stale'
    $json = & pwsh -NoProfile -File $script -Repo $fixtureRepo -Format context-json | ConvertFrom-Json
    Assert-Equal 0 $LASTEXITCODE 'Corrupt lease never fails hook'
    Assert-Equal $mode.Text $json.additionalContext 'Neutral context equals text'
    $copy = Join-Path $tempRoot 'plugin'
    New-Item -ItemType Directory (Join-Path $copy 'hooks'), (Join-Path $copy 'bin') -Force | Out-Null
    Copy-Item -LiteralPath $script -Destination (Join-Path $copy 'hooks/detect-mode.ps1')
    Copy-Item -LiteralPath (Join-Path $hookPlugin 'bin/ps-ai-update.ps1') -Destination (Join-Path $copy 'bin/ps-ai-update.ps1')
    'function Get-PsAiLease { throw "fixture lease read failure" }' | Set-Content (Join-Path $copy 'bin/PsAi.Common.ps1')
    $failedHook = Join-Path $copy 'hooks/detect-mode.ps1'
    $warning = 'ps-ai: mode detection failed; continuing without mode context.'
    Assert-Equal $warning (& pwsh -NoProfile -File $failedHook -Repo $fixtureRepo -Format text) 'Text hook fails open'
    Assert-Equal 0 $LASTEXITCODE 'Text hook failure exits zero'
    $failedJson = & pwsh -NoProfile -File $failedHook -Repo $fixtureRepo -Format context-json | ConvertFrom-Json
    Assert-Equal $warning $failedJson.additionalContext 'JSON hook fails open with same warning'
    Assert-Equal 0 $LASTEXITCODE 'JSON hook failure exits zero'
    Remove-Item $handoff
    $mode = Get-PsAiMode -Repo $fixtureRepo -Environment @{}
    Assert-Equal 'none' $mode.Mode 'No handoff is none'
    Assert-Equal '' $mode.Text 'No handoff has empty text'
    $json = & pwsh -NoProfile -File $script -Repo $fixtureRepo -Format context-json
    Assert-Equal '{}' $json 'Neutral none emits empty object'
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp/restructure')) + [IO.Path]::DirectorySeparatorChar
    if (-not ([IO.Path]::GetFullPath($tempRoot)).StartsWith($allowed)) { throw 'unsafe hook fixture cleanup' }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}

