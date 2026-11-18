$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1'
$validator = Join-Path $root 'plugins/ps-ai/bin/ps-ai-validate.ps1'
$ownerFile = Join-Path $PSScriptRoot 'fixtures/personalisation/valid-owner.json'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $homeRoot = Join-Path $tempRoot 'owner'
    $config = Join-Path $homeRoot '.agents/configuration'
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    $file = Join-Path $config 'ps-ai-personalisation.json'
    Copy-Item $ownerFile $file
    $output = & $script -Action add -Id codex3 -Tool codex -HomeRoot $homeRoot
    Assert-True ($output -contains "Run 'codex3' in a terminal and log in once.") 'Add prints login instruction'
    $repeat = & pwsh -NoProfile -File $script -Action add -Id codex3 -Tool codex -HomeRoot $homeRoot
    Assert-Equal 0 $LASTEXITCODE 'Second add succeeds'
    Assert-True (@($repeat) -match '^skip: .*\(already done\)$') 'Second add reports skip'
    Assert-True (Test-Path (Join-Path $homeRoot '.agents/bin/codex3')) 'Add creates sh wrapper'
    Assert-Equal '#!/bin/sh' (Get-Content (Join-Path $homeRoot '.agents/bin/codex3') -TotalCount 1) 'Unix wrapper starts with shebang'
    if ($IsWindows) { Assert-True (Test-Path (Join-Path $homeRoot '.agents/bin/codex3.cmd')) 'Add creates cmd wrapper' }
    $owner = Get-Content -Raw $file | ConvertFrom-Json
    $added = @($owner.agents | Where-Object id -eq codex3)[0]
    Assert-Equal '~/.agents/bin/codex3' $added.command 'Add wrapper command'
    Assert-Equal '~/.agents/accounts/codex3' $added.configDir 'Add config folder'
    & pwsh -NoProfile -File $validator -Kind personalisation -Path $file | Out-Null
    Assert-Equal 0 $LASTEXITCODE 'Added account validates'
    try {
        & $script -Action add -Id git -Tool codex -HomeRoot $homeRoot | Out-Null
        throw 'Expected command collision'
    } catch { Assert-Equal "'git' is already a command" $_.Exception.Message 'Command collision error' }
    try {
        & $script -Action add -Id Codex_3 -Tool codex -HomeRoot $homeRoot | Out-Null
        throw 'Expected pattern failure'
    } catch { Assert-True ($_.Exception.Message -match '\^\[a-z\]') 'Invalid id pattern error' }
    $before = Get-Content -Raw $file | ConvertFrom-Json
    $bin = Join-Path $homeRoot '.agents/bin'
    Set-Content -Path (Join-Path $bin 'codex-a') -Value '# wrapper'
    if ($IsWindows) { Set-Content -Path (Join-Path $bin 'codex-a.cmd') -Value '@echo off' }
    $before.projects.'my-project'.routing | Add-Member -NotePropertyName review -NotePropertyValue @('codex-a')
    $before | ConvertTo-Json -Depth 30 | Set-Content -Path $file -Encoding utf8
    $renameOutput = & $script -Action rename -Id codex-a -NewId codex-work -HomeRoot $homeRoot
    $repeat = & pwsh -NoProfile -File $script -Action rename -Id codex-a -NewId codex-work -HomeRoot $homeRoot
    Assert-Equal 0 $LASTEXITCODE 'Second rename succeeds'
    Assert-True (@($repeat) -match '^skip: .*\(already done\)$') 'Second rename reports skip'
    $after = Get-Content -Raw $file | ConvertFrom-Json
    Assert-Equal '~/bin/codex-a' (@($after.agents | Where-Object id -eq codex-work)[0].command) 'Rename preserves external command'
    Assert-True (@($renameOutput) -match 'command kept at ~/bin/codex-a; rename the wrapper yourself if you want to') 'Rename explains external wrapper'
    Assert-True ($after.routing.implement -contains 'codex-work') 'Rename updates implement routing'
    Assert-True ($after.routing.review -contains 'codex-work') 'Rename updates review routing'
    Assert-True ($after.projects.'my-project'.routing.review -contains 'codex-work') 'Rename updates project routing'
    Assert-True (Test-Path (Join-Path $bin 'codex-work')) 'Rename moves sh wrapper'
    if ($IsWindows) { Assert-True (Test-Path (Join-Path $bin 'codex-work.cmd')) 'Rename moves cmd wrapper' }
    Assert-Equal '~/.codex' (@($after.agents | Where-Object id -eq codex-work)[0].configDir) 'Rename keeps config folder'
    $after.agents[2].id = 'codex-a'
    $after.agents[2].command = '~/bin/codex-a'
    $after.routing.implement[0] = 'codex-a'
    $after.routing.review[0] = 'codex-a'
    $after.projects.'my-project'.routing.review[0] = 'codex-a'
    Assert-Equal ($before | ConvertTo-Json -Depth 30 -Compress) ($after | ConvertTo-Json -Depth 30 -Compress) 'Rename changes nothing else'
    $keep = Join-Path $homeRoot '.agents/accounts/codex-b'
    New-Item -ItemType Directory -Path $keep -Force | Out-Null
    Set-Content -Path (Join-Path $keep 'keep.txt') -Value 'kept'
    Set-Content -Path (Join-Path $bin 'codex-b') -Value '# wrapper'
    & $script -Action remove -Id codex-b -HomeRoot $homeRoot | Out-Null
    $repeat = & pwsh -NoProfile -File $script -Action remove -Id codex-b -HomeRoot $homeRoot
    Assert-Equal 0 $LASTEXITCODE 'Second remove succeeds'
    Assert-True (@($repeat) -match '^skip: .*\(already done\)$') 'Second remove reports skip'
    $after = Get-Content -Raw $file | ConvertFrom-Json
    Assert-True (@($after.agents.id) -notcontains 'codex-b') 'Remove deletes entry'
    Assert-True ($after.routing.implement -notcontains 'codex-b') 'Remove clears routing'
    Assert-True (Test-Path (Join-Path $keep 'keep.txt')) 'Remove preserves config folder'
    $registerHome = Join-Path $tempRoot 'register'
    $registerConfig = Join-Path $registerHome '.agents/configuration'
    New-Item -ItemType Directory -Path $registerConfig -Force | Out-Null
    $registerFile = Join-Path $registerConfig 'ps-ai-personalisation.json'
    $fresh = [pscustomobject]@{
        schemaVersion = 1; communication = @{ channels = @{} }; agents = @()
        routing = @{}; knowledge = @{ backend = 'none' }; projects = @{}; default = @{ notify = @() }
    }
    $fresh | ConvertTo-Json -Depth 30 | Set-Content -Path $registerFile -Encoding utf8
    & $script -Action register -Id claude-b -Tool claude -Command '~/bin/claude-b' -ConfigDir '~/.claude-b' -HomeRoot $registerHome | Out-Null
    $repeat = & pwsh -NoProfile -File $script -Action register -Id claude-b -Tool claude -Command '~/bin/claude-b' -ConfigDir '~/.claude-b' -HomeRoot $registerHome
    Assert-Equal 0 $LASTEXITCODE 'Second register succeeds'
    Assert-True (@($repeat) -match '^skip: .*\(already done\)$') 'Second register reports skip'
    $registered = Get-Content -Raw $registerFile | ConvertFrom-Json
    Assert-Equal '~/bin/claude-b' $registered.agents[0].command 'Register keeps existing wrapper path'
    Assert-True (-not (Test-Path (Join-Path $registerHome '.agents/bin'))) 'Register creates no wrapper files'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
