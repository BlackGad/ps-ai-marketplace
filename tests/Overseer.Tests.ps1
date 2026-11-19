$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-overseer.ps1'
$tempRoot = Join-Path $root ('.agents/temp/overseer-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tempRoot -Force | Out-Null
$lines = @(& pwsh -NoProfile -File $script -HomeRoot $tempRoot)
Assert-Equal 0 $LASTEXITCODE 'BareLauncherOnlyPrintsUsage without configuration'
Assert-True ($lines -match 'Usage:') 'Bare launcher usage'
. $script -NoRun -HomeRoot $tempRoot
$owner = [pscustomobject]@{schemaVersion=1;agents=@(
    @{id='claude-a';tool='claude';configDir='~/a'},
    @{id='claude-b';tool='claude';configDir='~/b'},
    @{id='codex-a';tool='codex';configDir='~/c'},
    @{id='copilot-a';tool='copilot';configDir='~/d'}
);channels=@(
    @{id='main';kind='telegram';target='123';accounts=@('claude-a','claude-b')},
    @{id='alerts';kind='telegram';target='456';accounts=@('claude-a')}
)}
Assert-Throws { Select-OverseerAccount $owner } 'Explicit account required'
Assert-Throws { Select-OverseerAccount $owner claude-a codex } 'Tool mismatch'
foreach ($tool in @('claude','codex','copilot')) {
    $launch = Get-OverseerLaunch -Personalisation $owner -AccountId "$tool-a" -Arguments @('--model','chosen','two words','','2026-11-19','semi;literal',"apostrophe'value") -HomeRoot $tempRoot
    Assert-Equal (Get-PsAiWrapperCommand "$tool-a" $tempRoot) $launch.Command 'Derived canonical wrapper'
    $expected = '--model|chosen|two words||2026-11-19|semi;literal|apostrophe''value|'
    if ($tool -eq 'copilot') { $expected += '-i|' }
    $expected += 'continue as the overseer'
    Assert-Equal $expected ($launch.Args -join '|') 'ExplicitAccountAndModel preserve argv'
}
$launch = Get-OverseerLaunch -Personalisation $owner -AccountId claude-a -Channel @('main','alerts','main')
Assert-Equal '--channels|plugin:telegram@claude-plugins-official|continue as the overseer' ($launch.Args -join '|') 'SameKindFlagsPreserveArgv'
Assert-Throws { Get-OverseerLaunch -Personalisation $owner -AccountId claude-b -Channel alerts } 'Unbound chosen account fails'
Assert-Throws { Get-OverseerLaunch -Personalisation $owner -AccountId codex-a -Channel main } 'Unsupported tool fails'
$owner.channels[1].accounts=@('claude-b')
$owner.channels[0].accounts=@('claude-a')
try { Get-OverseerLaunch -Personalisation $owner -AccountId claude-a -Channel @('main','alerts'); throw 'Expected disjoint failure' }
catch { Assert-Equal 'selected channels cannot share one launch' $_.Exception.Message 'ChannelIntersection exact failure' }
& {
    $plugin = Join-Path $tempRoot 'plugin'
    Copy-Item (Join-Path $root 'plugins/ps-ai') $plugin -Recurse
    $fixtureKindFolder = Join-Path $plugin 'skills/ps-ai-fixture-channel'
    New-Item -ItemType Directory $fixtureKindFolder -Force | Out-Null
    'Fixture channel.' | Set-Content (Join-Path $fixtureKindFolder 'SKILL.md')
    '{"schemaVersion":1,"id":"fixture-channel","launch":{"claude":["--channels","second value","","2026-11-19","semi;literal","quote''value"]}}' | Set-Content (Join-Path $fixtureKindFolder 'channel.json')
    Get-ChildItem (Join-Path $plugin 'skills') -Filter overseer-model.ps1 -Recurse | Remove-Item
    . (Join-Path $plugin 'bin/ps-ai-overseer.ps1') -NoRun
    $copy = $owner | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $copy.channels[1].kind='fixture-channel'
    $copy.channels[1].accounts=@('claude-a')
    $launch = Get-OverseerLaunch -Personalisation $copy -AccountId claude-a -Channel @('main','alerts','alerts')
    Assert-Equal '--channels|plugin:telegram@claude-plugins-official|--channels|second value||2026-11-19|semi;literal|quote''value|continue as the overseer' ($launch.Args -join '|') 'SameKindFlagsPreserveArgv never deduplicates individual strings'
    'different' | Set-Content (Join-Path $fixtureKindFolder 'SKILL.md')
    $missingSkill = Join-Path $plugin 'skills/ps-ai-telegram/SKILL.md'
    Move-Item -LiteralPath $missingSkill -Destination ($missingSkill + '.fixture')
    Assert-Throws { Get-OverseerLaunch -Personalisation $copy -AccountId claude-a -Channel main } 'Missing channel skill fails before execution'
}
$repoPath = Join-Path $tempRoot 'My Projects'
New-Item -ItemType Directory $repoPath -Force | Out-Null
    $probe = Join-Path $tempRoot 'cwd-probe.ps1'
    $resultFile = Join-Path $tempRoot 'cwd.txt'
    'param($ResultFile) [System.IO.File]::WriteAllText($ResultFile, (Get-Location).Path)' | Set-Content -LiteralPath $probe
    $beforeLocation = (Get-Location).Path
    Invoke-OverseerInRepo -Repo $repoPath -Command $probe -Arguments @($resultFile)
    Assert-Equal $repoPath ([System.IO.File]::ReadAllText($resultFile)) 'Unix launch runs in repo'
    Assert-Equal $beforeLocation (Get-Location).Path 'Unix launch restores caller location'
    & {
        function Get-Command { param($Name, $CommandType, $ErrorAction) if ($Name -eq 'wt') { return $null }; throw 'Unexpected discovery' }
        $state = @{ Called=$false }
        function Invoke-OverseerInRepo {
            param($Repo, $Command, $Arguments)
            $state.Called = $true
            Assert-Equal $repoPath $Repo 'Fallback selects the project folder'
            Assert-Equal $state.Expected $Arguments[0] 'Fallback preserves literal arguments'
        }
        foreach ($value in @('ordinary argument','literal;argument')) {
            $state.Expected = $value
            Start-OverseerLaunch -Repo $repoPath -Launch @{Command='fixture';Args=@($value)}
        }
        Assert-True $state.Called 'Missing Windows Terminal uses the current terminal'
    }
    if ($IsWindows) {
        & {
            $state = @{Arguments=@()}
            function fixture-terminal { $state.Arguments=@($args) }
            function Get-Command { param($Name,$CommandType,$ErrorAction) @{Source='fixture-terminal'} }
            Start-OverseerLaunch -Repo $repoPath -Launch @{Command='fixture.cmd';Args=@('two words',"apostrophe'argument")}
            Assert-True ($state.Arguments -contains '-EncodedCommand') 'Terminal executes batch wrappers through PowerShell'
            $encoded = $state.Arguments[-1]
            $decoded = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
            Assert-True ($decoded.Contains("& 'fixture.cmd' 'two words' 'apostrophe''argument'")) 'Terminal transport preserves literal values'
        }
    }
