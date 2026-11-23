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
Assert-Throws { Resolve-LegionChannel $owner main copilot } 'Unsupported tool fails'
$scratch = Join-Path $root ('.agents/temp/channel-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $scratch -Force | Out-Null
Copy-Item (Join-Path $root 'plugins/legion/skills/legion-claude') $scratch -Recurse
$skill = Join-Path $scratch 'legion-fixture-channel'
Copy-Item (Join-Path $PSScriptRoot 'fixtures/channels/legion-fixture-channel') $skill -Recurse
$descriptor = @(Get-LegionChannels $scratch)[0]
Assert-Equal '|two words|2026-11-19|semi;literal|quote''value' ($descriptor.launch.claude -join '|') 'LiteralChannelArguments'
Assert-Equal 'fixture-channel' $descriptor.id 'DiscoverSecondChannelKind'
$cleanupPath = [IO.Path]::GetFullPath($scratch)
$allowed = [IO.Path]::GetFullPath((Join-Path $root '.agents/temp/'))
if (-not $cleanupPath.StartsWith($allowed)) { throw 'Unsafe channel fixture cleanup' }
Remove-Item -LiteralPath $cleanupPath -Recurse -Force
