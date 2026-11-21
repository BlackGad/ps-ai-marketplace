$root = Split-Path $PSScriptRoot -Parent
$library = Join-Path $root 'plugins/legion/bin/lib/channels.ps1'
Assert-True (Test-Path $library) 'Channel discovery exists'
. $library
$channels = @(Get-LegionChannels)
Assert-Equal 'telegram' ($channels.id -join '|') 'Telegram discovered'
$owner = @{agents=@(@{id='claude-a';tool='claude'});channels=@(
    @{id='main';kind='telegram';target='123';accounts=@('claude-a')},
    @{id='alerts';kind='telegram';target='456';accounts=@('claude-a')}
)}
Assert-Equal '123' (Resolve-LegionChannel $owner main claude).Target 'Main destination'
Assert-Equal '456' (Resolve-LegionChannel $owner alerts claude).Target 'Separate same-kind destination'
Assert-Throws { Resolve-LegionChannel $owner unknown claude } 'Unknown destination fails'
Assert-Throws { Resolve-LegionChannel $owner main codex } 'Unsupported tool fails'
$scratch = Join-Path $root ('.agents/temp/channel-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $scratch -Force | Out-Null
Copy-Item (Join-Path $root 'plugins/legion/skills/legion-claude') $scratch -Recurse
$skill = Join-Path $scratch 'legion-fixture-channel'
Copy-Item (Join-Path $PSScriptRoot 'fixtures/channels/legion-fixture-channel') $skill -Recurse
$descriptor = @(Get-LegionChannels $scratch)[0]
Assert-Equal '|two words|2026-11-19|semi;literal|quote''value' ($descriptor.launch.claude -join '|') 'LiteralChannelArguments'
Assert-Equal 'fixture-channel' $descriptor.id 'DiscoverSecondChannelKind'
foreach ($bad in @(
    '{"schemaVersion":2,"id":"fixture-channel","launch":{"claude":[]}}',
    '{"schemaVersion":1,"id":"wrong","launch":{"claude":[]}}',
    '{"schemaVersion":1,"id":"fixture-channel","launch":{"unknown":[]}}',
    '{"schemaVersion":1,"id":"fixture-channel","launch":{"claude":[1]}}'
)) {
    $bad | Set-Content (Join-Path $skill 'channel.json')
    Assert-Throws { Get-LegionChannels $scratch } 'Malformed descriptor fails'
}
# ready is an accepted fourth key; any other extra key is rejected
Remove-Item -LiteralPath $skill -Recurse -Force
$telegram = Join-Path $scratch 'legion-telegram'
New-Item -ItemType Directory $telegram -Force | Out-Null
Copy-Item (Join-Path $root 'plugins/legion/skills/legion-telegram/SKILL.md') $telegram
$ready = '"ready":{"command":"bun","pluginFolder":{"claude":"plugins/cache/claude-plugins-official/telegram"}}'
$base = '"schemaVersion":1,"id":"telegram","launch":{"claude":[]}'
"{$base,$ready}" | Set-Content (Join-Path $telegram 'channel.json')
Assert-Equal 'bun' (@(Get-LegionChannels $scratch | Where-Object id -CEQ telegram)[0].ready.command) 'Ready accepted'
"{$base,$ready,`"extra`":1}" | Set-Content (Join-Path $telegram 'channel.json')
Assert-Throws { Get-LegionChannels $scratch } 'Unknown fifth key rejected'
"{$base,`"extra`":1}" | Set-Content (Join-Path $telegram 'channel.json')
Assert-Throws { Get-LegionChannels $scratch } 'Unknown key without ready rejected'
