$root = Split-Path $PSScriptRoot -Parent
$accountScript = Join-Path $root 'plugins/ps-ai/bin/ps-ai-account.ps1'
$homeRoot = Join-Path $root ('.agents/temp/lean-accounts-' + [guid]::NewGuid().ToString('N'))
$file = Join-Path $homeRoot '.legion/configuration/ps-ai-personalisation.json'
New-Item -ItemType Directory (Split-Path $file), (Join-Path $homeRoot 'existing') -Force | Out-Null
'{"schemaVersion":1,"agents":[],"channels":[]}' | Set-Content $file
$fake = Join-Path $homeRoot 'external.ps1'
'exit 37' | Set-Content $fake
$notes = Join-Path (Split-Path $file) 'ps-ai-notes.md'
'Keep the owner answers.' | Set-Content $notes
& $accountScript -Action register -Id claude-a -Tool claude -Command $fake -ConfigDir '~/existing' -HomeRoot $homeRoot | Out-Null
. $accountScript -NoRun -HomeRoot $homeRoot
# DerivedWrapperWithoutSavedCommand / AdoptedShortcutSurvivesLifecycle
$data = Read-PsAiJson $file
Assert-True (-not $data.agents[0].PSObject.Properties['command']) 'No saved command'
$wrapper = Get-PsAiWrapperCommand -Id claude-a -HomeRoot $homeRoot
Assert-True (Test-Path -LiteralPath $wrapper) 'Register creates canonical wrapper'
Assert-True (Test-PsAiOwnedWrapper $wrapper claude-a) 'Canonical wrapper has ownership header'
$bytes = [IO.File]::ReadAllText($wrapper)
$ticks = (Get-Item $wrapper).LastWriteTimeUtc.Ticks
$repeat = & $accountScript -Action register -Id claude-a -Tool claude -Command $fake -ConfigDir '~/existing' -HomeRoot $homeRoot
Assert-True ($repeat -match '^skip: .*\(already done\)$') 'Canonical repeat skips'
Assert-Equal $ticks (Get-Item $wrapper).LastWriteTimeUtc.Ticks 'Repeat preserves mtime'
# LastBindingRemovalRollsBack
$data.channels = @(@{id='main';kind='telegram';target='123';accounts=@('claude-a')})
$data | ConvertTo-Json -Depth 100 | Set-Content $file
$before = [IO.File]::ReadAllText($file)
try { & $accountScript -Action remove -Id claude-a -HomeRoot $homeRoot; throw 'Expected binding failure' }
catch { Assert-Equal "channel 'main' would have no accounts; rebind or remove it first" $_.Exception.Message 'Exact last binding error' }
Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Failed removal preserves JSON'
Assert-Equal $bytes ([IO.File]::ReadAllText($wrapper)) 'Failed removal preserves wrapper'
Assert-Equal 'Keep the owner answers.' (Get-Content $notes) 'Notes stay untouched'
# CanonicalCollisionAndRepeat
'unrelated' | Set-Content (Join-Path $homeRoot '.legion/bin/blocked')
Assert-Throws { New-PsAiWrappers blocked claude $homeRoot $fake (Join-Path $homeRoot 'existing') } 'Unrelated canonical file collision'
Assert-Equal 'unrelated' (Get-Content (Join-Path $homeRoot '.legion/bin/blocked')) 'Collision preserves bytes'
$before = [IO.File]::ReadAllText($file)
Assert-Throws { & $accountScript -Action add -Id recursion -Tool claude -Command (Get-PsAiWrapperCommand recursion $homeRoot) -HomeRoot $homeRoot } 'Canonical target recursion rejected'
Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Recursion rejected before JSON write'
$externalBytes = [IO.File]::ReadAllText($fake)
& $accountScript -Action register -Id claude-b -Tool claude -Command $fake -ConfigDir '~/existing' -HomeRoot $homeRoot | Out-Null
$data = Read-PsAiJson $file
$data.channels[0].accounts = @('claude-a','claude-b')
$data | ConvertTo-Json -Depth 100 | Set-Content $file
& $accountScript -Action rename -Id claude-a -NewId claude-renamed -HomeRoot $homeRoot | Out-Null
$data = Read-PsAiJson $file
Assert-Equal 'claude-renamed|claude-b' ($data.channels[0].accounts -join '|') 'Rename updates exact channel references'
Assert-True (Test-PsAiOwnedWrapper (Get-PsAiWrapperCommand claude-renamed $homeRoot) claude-renamed) 'Rename changes canonical header'
& $accountScript -Action remove -Id claude-renamed -HomeRoot $homeRoot | Out-Null
Assert-Equal 'claude-b' ((Read-PsAiJson $file).channels[0].accounts -join '|') 'Remove prunes binding with another account'
Assert-True (-not (Test-Path (Get-PsAiWrapperCommand claude-renamed $homeRoot))) 'Remove deletes owned wrapper'
Assert-Equal $externalBytes ([IO.File]::ReadAllText($fake)) 'Adopted external shortcut survives lifecycle'
$before = [IO.File]::ReadAllText($file)
$mismatch = Join-Path $homeRoot 'different.ps1'
'exit 0' | Set-Content $mismatch
Assert-Throws { & $accountScript -Action register -Id claude-b -Tool claude -Command $mismatch -ConfigDir '~/existing' -HomeRoot $homeRoot } 'Mismatched registration repeat fails'
Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Mismatched repeat preserves JSON'
'owner file' | Set-Content (Join-Path $homeRoot '.legion/bin/destination')
Assert-Throws { & $accountScript -Action rename -Id claude-b -NewId destination -HomeRoot $homeRoot } 'Rename destination collision fails'
Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Rename collision preserves JSON'
Assert-Equal 'owner file' (Get-Content (Join-Path $homeRoot '.legion/bin/destination')) 'Rename preserves unrelated file'
$output = & $accountScript -Action add -Id codex-new -Tool codex -Command $fake -HomeRoot $homeRoot
Assert-Equal "Run 'codex-new' in a terminal and log in once." $output 'New account requests owner login'
$accountDir = Join-Path $homeRoot '.legion/agents/codex-new'
Assert-Equal $accountDir ((Read-PsAiJson $file).agents | Where-Object id -EQ codex-new).configDir 'New account records the legion folder'
Assert-True (Test-Path -LiteralPath $accountDir -PathType Container) 'New account creates the legion folder'
Assert-True ((Get-Content (Join-Path $homeRoot '.legion/bin/codex-new') -Raw).Contains($accountDir)) 'Shortcut keeps the account id and selects the legion folder'
$repeat = & $accountScript -Action add -Id codex-new -Tool codex -Command $fake -HomeRoot $homeRoot
Assert-Equal 'skip: account codex-new (already done)' $repeat 'Added account repeat skips'
Assert-Throws { & $accountScript -Action add -Id Invalid_id -Tool codex -Command $fake -HomeRoot $homeRoot } 'Invalid ID rejected'
# An application name still blocks a new id.
$before = [IO.File]::ReadAllText($file)
try {
    & $accountScript -Action add -Id git -Tool codex -Command $fake -HomeRoot $homeRoot
    throw 'Expected application name collision'
} catch {
    Assert-Equal "'git' is already a command" $_.Exception.Message 'An application name still blocks a new id'
}
Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Application collision preserves settings'
# A function name does not block a new id.
function codex9 {}
try {
    & $accountScript -Action add -Id codex9 -Tool codex -Command $fake -HomeRoot $homeRoot | Out-Null
    Assert-Equal 'codex9' ((Read-PsAiJson $file).agents | Where-Object id -EQ codex9).id 'A function name does not block a new id'
    Assert-True (Test-Path -LiteralPath (Get-PsAiWrapperCommand codex9 $homeRoot)) 'Function-named account has a wrapper'
} finally {
    Remove-Item Function:codex9
}
$before = [IO.File]::ReadAllText($file)
"#!/bin/sh`n# Generated by ps-ai: account orphan`nexit 9" | Set-Content (Join-Path $homeRoot '.legion/bin/orphan')
Assert-Throws { & $accountScript -Action add -Id orphan -Tool claude -Command $fake -HomeRoot $homeRoot } 'Orphan owned wrapper mismatch rejected'
Assert-Equal $before ([IO.File]::ReadAllText($file)) 'Owned content collision rejected before JSON publication'
