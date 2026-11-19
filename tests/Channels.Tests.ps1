$root = Split-Path $PSScriptRoot -Parent
$library = Join-Path $root 'plugins/ps-ai/bin/lib/channels.ps1'
Assert-True (Test-Path $library) 'Channel discovery exists'
. $library
$channels = @(Get-PsAiChannels)
Assert-Equal 'telegram' ($channels.id -join '|') 'Telegram discovered'
$owner = @{agents=@(@{id='claude-a';tool='claude'});channels=@(
    @{id='main';kind='telegram';target='123';accounts=@('claude-a')},
    @{id='alerts';kind='telegram';target='456';accounts=@('claude-a')}
)}
Assert-Equal '123' (Resolve-PsAiChannel $owner main claude).Target 'Main destination'
Assert-Equal '456' (Resolve-PsAiChannel $owner alerts claude).Target 'Separate same-kind destination'
Assert-Throws { Resolve-PsAiChannel $owner unknown claude } 'Unknown destination fails'
Assert-Throws { Resolve-PsAiChannel $owner main codex } 'Unsupported tool fails'
$scratch = Join-Path $root ('.agents/temp/channel-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $scratch -Force | Out-Null
Copy-Item (Join-Path $root 'plugins/ps-ai/skills/ps-ai-claude') $scratch -Recurse
$skill = Join-Path $scratch 'ps-ai-fixture-channel'
Copy-Item (Join-Path $PSScriptRoot 'fixtures/channels/ps-ai-fixture-channel') $skill -Recurse
$descriptor = @(Get-PsAiChannels $scratch)[0]
Assert-Equal '|two words|2026-11-19|semi;literal|quote''value' ($descriptor.launch.claude -join '|') 'LiteralChannelArguments'
Assert-Equal 'fixture-channel' $descriptor.id 'DiscoverSecondChannelKind'
foreach ($bad in @(
    '{"schemaVersion":2,"id":"fixture-channel","launch":{"claude":[]}}',
    '{"schemaVersion":1,"id":"wrong","launch":{"claude":[]}}',
    '{"schemaVersion":1,"id":"fixture-channel","launch":{"unknown":[]}}',
    '{"schemaVersion":1,"id":"fixture-channel","launch":{"claude":[1]}}'
)) {
    $bad | Set-Content (Join-Path $skill 'channel.json')
    Assert-Throws { Get-PsAiChannels $scratch } 'Malformed descriptor fails'
}
