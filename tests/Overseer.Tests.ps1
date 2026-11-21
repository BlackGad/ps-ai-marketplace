$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-overseer.ps1'
$tempRoot = Join-Path $root ('.agents/temp/overseer-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $tempRoot -Force | Out-Null
$lines = @(& pwsh -NoProfile -File $script -HomeRoot $tempRoot -Repo $tempRoot 2>&1)
Assert-True ($LASTEXITCODE -ne 0) 'Bare launcher without configuration fails'
Assert-True (-not ($lines -match 'Usage:')) 'Bare launcher prints no usage line'
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
$launch = Get-OverseerLaunch -Personalisation $owner -AccountId claude-a -Channel @('main','alerts','main') -HomeRoot $tempRoot
Assert-Equal '--channels|plugin:telegram@claude-plugins-official|--|continue as the overseer' ($launch.Args -join '|') 'SameKindFlagsPreserveArgv'
$launch = Get-OverseerLaunch -Personalisation $owner -AccountId claude-a -Arguments @('--channels','plugin:telegram@claude-plugins-official') -HomeRoot $tempRoot
Assert-Equal '--channels|plugin:telegram@claude-plugins-official|--|continue as the overseer' ($launch.Args -join '|') 'ExplicitChannelFlagStopsBeforePrompt'
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
    . (Join-Path $plugin 'bin/ps-ai-overseer.ps1') -NoRun -HomeRoot $tempRoot
    $copy = $owner | ConvertTo-Json -Depth 100 | ConvertFrom-Json
    $copy.channels[1].kind='fixture-channel'
    $copy.channels[1].accounts=@('claude-a')
    $launch = Get-OverseerLaunch -Personalisation $copy -AccountId claude-a -Channel @('main','alerts','alerts') -HomeRoot $tempRoot
    Assert-Equal '--channels|plugin:telegram@claude-plugins-official|--channels|second value||2026-11-19|semi;literal|quote''value|--|continue as the overseer' ($launch.Args -join '|') 'SameKindFlagsPreserveArgv never deduplicates individual strings'
    'different' | Set-Content (Join-Path $fixtureKindFolder 'SKILL.md')
    $missingSkill = Join-Path $plugin 'skills/ps-ai-telegram/SKILL.md'
    Move-Item -LiteralPath $missingSkill -Destination ($missingSkill + '.fixture')
    Assert-Throws { Get-OverseerLaunch -Personalisation $copy -AccountId claude-a -Channel main } 'Missing channel skill fails before execution'
}
$repoPath = Join-Path $tempRoot 'My Projects'
New-Item -ItemType Directory $repoPath -Force | Out-Null
    $probe = Join-Path $tempRoot 'cwd-probe.ps1'
    $resultFile = Join-Path $tempRoot 'cwd.txt'
    'param($ResultFile) [System.IO.File]::WriteAllText($ResultFile, (Get-Location).Path + "|$env:CLAUDECODE|$env:CLAUDE_CODE_CHILD_SESSION|$env:CLAUDE_CODE_FIXTURE|$env:NO_COLOR|$env:TERM")' | Set-Content -LiteralPath $probe
    $beforeLocation = (Get-Location).Path
    $savedParent = @($env:CLAUDECODE, $env:CLAUDE_CODE_CHILD_SESSION, $env:CLAUDE_CODE_FIXTURE, $env:NO_COLOR, $env:TERM)
    try {
        $env:CLAUDECODE = '1'; $env:CLAUDE_CODE_CHILD_SESSION = '1'; $env:CLAUDE_CODE_FIXTURE = 'fixture'; $env:NO_COLOR = '1'; $env:TERM = 'dumb'
        Invoke-OverseerInRepo -Repo $repoPath -Command $probe -Arguments @($resultFile)
        Assert-Equal "$repoPath|||||" ([System.IO.File]::ReadAllText($resultFile)) 'In-place launch clears all parent Claude and terminal variables'
        Assert-Equal '1|1|fixture|1|dumb' "$env:CLAUDECODE|$env:CLAUDE_CODE_CHILD_SESSION|$env:CLAUDE_CODE_FIXTURE|$env:NO_COLOR|$env:TERM" 'In-place launch restores the caller environment'
        function failing-overseer { throw 'fixture failure' }
        Assert-Throws { Invoke-OverseerInRepo -Repo $repoPath -Command failing-overseer } 'Launch errors propagate'
        Assert-Throws { Invoke-OverseerInRepo -Repo (Join-Path $tempRoot 'missing-repo') -Command $probe } 'Missing launch folder fails'
        Assert-Equal '1|1|fixture|1|dumb' "$env:CLAUDECODE|$env:CLAUDE_CODE_CHILD_SESSION|$env:CLAUDE_CODE_FIXTURE|$env:NO_COLOR|$env:TERM" 'Failed launches restore the caller environment'
    } finally {
        $env:CLAUDECODE, $env:CLAUDE_CODE_CHILD_SESSION, $env:CLAUDE_CODE_FIXTURE, $env:NO_COLOR, $env:TERM = $savedParent
    }
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
            Assert-True ($decoded.StartsWith('Remove-Item Env:NO_COLOR, Env:TERM, Env:CLAUDECODE, ')) 'New terminal tab drops inherited no-color settings'
            Assert-True ($decoded.Contains('Env:CLAUDE_CODE_*')) 'New terminal tab clears every Claude session variable'
        }
    }

# Account and channel choice (Task 5). Nothing below opens a terminal or starts an agent.
# Saved launch keys follow the host filesystem's case rules and ignore a trailing separator.
$savedHome = Join-Path $tempRoot 'saved-home'
$repoA = Join-Path $tempRoot 'ProjectA'
$repoB = Join-Path $tempRoot 'ProjectB'
Save-OverseerLastLaunch -Repo $repoA -HomeRoot $savedHome -Account claude-a -Channel @('main', 'alerts') -Arguments @('--model', 'chosen', '', 'two words')
$saved = Get-OverseerLastLaunch -Repo ($repoA + [IO.Path]::DirectorySeparatorChar) -HomeRoot $savedHome
Assert-Equal 'claude-a' $saved.account 'A one-repository JSON object round trips with a trailing separator'
Assert-Equal 'main|alerts' ($saved.channels -join '|') 'Saved launch keeps all channel ids'
Assert-Equal '--model|chosen||two words' ($saved.arguments -join '|') 'Saved launch keeps literal arguments'
Save-OverseerLastLaunch -Repo $repoB -HomeRoot $savedHome -Account codex-a
Save-OverseerLastLaunch -Repo $repoA -HomeRoot $savedHome -Account claude-b
Assert-Equal 'claude-b' (Get-OverseerLastLaunch -Repo $repoA -HomeRoot $savedHome).account 'Updating one repository replaces its launch'
Assert-Equal 'codex-a' (Get-OverseerLastLaunch -Repo $repoB -HomeRoot $savedHome).account 'Updating one repository preserves other repositories'
Assert-Equal 0 @( (Get-OverseerLastLaunch -Repo $repoA -HomeRoot $savedHome).channels ).Count 'No-channel launch saves an empty array'
Assert-True ($null -eq (Get-OverseerLastLaunch -Repo (Join-Path $tempRoot 'unseen') -HomeRoot $savedHome)) 'Unknown repository has no saved launch'
$caseVariant = Join-Path $tempRoot 'projecta'
if ($IsWindows) {
    Assert-Equal (Get-OverseerRepoKey $repoA) (Get-OverseerRepoKey $caseVariant) 'Windows repository keys ignore case'
    Assert-Equal 'claude-b' (Get-OverseerLastLaunch -Repo $caseVariant -HomeRoot $savedHome).account 'Windows case variants reuse the saved launch'
} else {
    Assert-True ((Get-OverseerRepoKey $repoA) -cne (Get-OverseerRepoKey $caseVariant)) 'Unix repository keys keep case'
    Assert-True ($null -eq (Get-OverseerLastLaunch -Repo $caseVariant -HomeRoot $savedHome)) 'Unix case variants do not reuse a saved launch'
    Save-OverseerLastLaunch -Repo $caseVariant -HomeRoot $savedHome -Account codex-b
    Assert-Equal 'claude-b' (Get-OverseerLastLaunch -Repo $repoA -HomeRoot $savedHome).account 'Unix case-distinct repositories coexist in JSON'
    Assert-Equal 'codex-b' (Get-OverseerLastLaunch -Repo $caseVariant -HomeRoot $savedHome).account 'Unix case-distinct launch round trips'
}
$driveRoot = [IO.Path]::GetPathRoot([IO.Path]::GetFullPath($repoA))
Assert-Equal $(if ($IsWindows) { $driveRoot.ToLowerInvariant() } else { $driveRoot }) (Get-OverseerRepoKey $driveRoot) 'Repository key preserves a filesystem root'

$one = [pscustomobject]@{schemaVersion=1;agents=@(@{id='claude1';tool='claude';configDir='~/a'})}
Assert-Equal 'claude1' (Select-OverseerAccount $one).id 'One account is picked'
$two = [pscustomobject]@{schemaVersion=1;agents=@(
    @{id='claude1';tool='claude';configDir='~/a'},
    @{id='codex1';tool='codex';configDir='~/c'}
);channels=@(@{id='my-telegram';kind='telegram';target='123';accounts=@('claude1')})}
try { Select-OverseerAccount $two; throw 'Expected a choice error' }
catch { Assert-Equal 'Choose an account: -Account claude1 | codex1' $_.Exception.Message 'Two accounts list the candidates' }
Assert-Equal 'claude1' (Select-OverseerAccount $two -Channel @('my-telegram')).id 'Channel narrows the choice to one account'
Assert-Equal 'codex1' (Select-OverseerAccount $two -Tool codex).id 'Tool narrows the choice to one account'

Assert-Equal 'my-telegram' (Get-OverseerDefaultChannel -Personalisation $two -AccountId claude1 -Tool claude) 'One fitting binding is the default channel'
Assert-True ($null -eq (Get-OverseerDefaultChannel -Personalisation $two -AccountId codex1 -Tool codex)) 'No binding means no default channel'
$both = $two | ConvertTo-Json -Depth 100 | ConvertFrom-Json
$both.channels = @($both.channels) + [pscustomobject]@{id='alerts';kind='telegram';target='456';accounts=@('claude1')}
Assert-True ($null -eq (Get-OverseerDefaultChannel -Personalisation $both -AccountId claude1 -Tool claude)) 'Two fitting bindings give no default channel'

# Whole run with a temp home; Start-OverseerLaunch is replaced, so no agent starts.
$runHome = Join-Path $tempRoot 'run-home'
$runRepo = Join-Path $tempRoot 'run-repo'
New-Item -ItemType Directory (Join-Path $runHome '.legion/configuration'), (Join-Path $runRepo '.legion/configuration') -Force | Out-Null
'{"schemaVersion":1}' | Set-Content (Join-Path $runRepo '.legion/configuration/project.json')
$two | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $runHome '.legion/configuration/ps-ai-personalisation.json')
& {
    $state = @{Launch=$null; Fail=$false}
    function Start-OverseerLaunch {
        param([string]$Repo, $Launch, [switch]$DryRun)
        if ($state.Fail) { throw 'terminal failed' }
        $state.Launch = $Launch
    }
    $run = @{Repo=$runRepo; HomeRoot=$runHome; Arguments=@()}
    $text = @(Invoke-Overseer @run -Account claude1 -Channel @())
    Assert-Equal ('launched claude1 (claude) in ' + $runRepo + ' channel my-telegram') ($text -join '|') 'Launched line names the default channel'
    Assert-True ($state.Launch.Args -contains '--channels') 'One fitting binding adds the channel arguments'
    $text = @(Invoke-Overseer @run -Account claude1 -Channel @() -NoChannel)
    Assert-Equal ('launched claude1 (claude) in ' + $runRepo) ($text -join '|') 'NoChannel launched line has no channel'
    Assert-True ($state.Launch.Args -cnotcontains '--channels') 'NoChannel adds no channel arguments'
    $text = @(Invoke-Overseer @run -Account '' -Channel @() -Tool claude)
    Assert-True ($text -contains ('launched claude1 (claude) in ' + $runRepo + ' channel my-telegram')) 'The only claude account is picked without -Account'
    # Without a last launch, a bare start uses the account that last held the lease, with its channel.
    $leaseFile = Join-Path $runRepo '.legion/temp/overseer.lock'
    New-Item -ItemType Directory (Split-Path $leaseFile) -Force | Out-Null
    '{"tool":"claude","account":"claude1","host":"other-host","pid":1,"processStartedAt":"2026-01-01T00:00:00Z"}' | Set-Content $leaseFile
    $lastFile = Join-Path $runHome '.legion/state/overseer-launches.json'
    Remove-Item -LiteralPath $lastFile -ErrorAction Ignore
    $null = Invoke-Overseer @run -Account '' -Channel @() -DryRun
    Assert-True (-not (Test-Path -LiteralPath $lastFile)) 'Dry run does not create saved launches'
    $text = @(Invoke-Overseer @run -Account '' -Channel @())
    Assert-Equal ('launched claude1 (claude) in ' + $runRepo + ' channel my-telegram') ($text -join '|') 'Bare start falls back to the lease account'
    Remove-Item -LiteralPath $leaseFile
    Save-OverseerLastLaunch -Repo $runRepo -HomeRoot $runHome -Account removed-account -Channel @('removed-channel') -Arguments @('--old')
    Assert-Throws { Invoke-Overseer @run } 'A removed saved account with no lease falls back to normal account selection'
    '{"account":"codex1","host":"other-host","pid":1,"processStartedAt":"2026-01-01T00:00:00Z"}' | Set-Content $leaseFile
    $text = @(Invoke-Overseer @run)
    Assert-Equal ('launched codex1 (codex) in ' + $runRepo) ($text -join '|') 'A removed saved account falls back to the foreign lease account'
    Assert-Equal 'continue as the overseer' ($state.Launch.Args -join '|') 'Removed account channels and arguments are discarded'
    Remove-Item -LiteralPath $lastFile, $leaseFile
    Assert-Throws { Invoke-Overseer @run } 'Missing saved launch and lease list eligible accounts'
    '{"account":"removed-account"}' | Set-Content $leaseFile
    Assert-Throws { Invoke-Overseer @run } 'A removed lease account falls back to normal selection'
    '{"account":"claude1"}' | Set-Content $leaseFile
    $null = Invoke-Overseer @run
    Assert-Equal (Get-PsAiWrapperCommand claude1 $runHome) $state.Launch.Command 'A stale lease can supply the last account'
    Remove-Item -LiteralPath $lastFile, $leaseFile
    $single = [pscustomobject]@{schemaVersion=1;agents=@($two.agents[1]);channels=@()}
    $single | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $runHome '.legion/configuration/ps-ai-personalisation.json')
    $null = Invoke-Overseer @run
    Assert-Equal (Get-PsAiWrapperCommand codex1 $runHome) $state.Launch.Command 'One eligible account starts when no history exists'
    $two | ConvertTo-Json -Depth 100 | Set-Content (Join-Path $runHome '.legion/configuration/ps-ai-personalisation.json')
    # A bare start brings back the last minion with its settings, whatever ran in between.
    $null = Invoke-Overseer @run -Account claude1 -Channel @() -NoChannel -Arguments @('--model', 'chosen', '')
    $text = @(Invoke-Overseer @run -Account '' -Channel @())
    Assert-Equal ('launched claude1 (claude) in ' + $runRepo) ($text -join '|') 'Bare start repeats the last account without a channel'
    Assert-Equal '--model|chosen||continue as the overseer' ($state.Launch.Args -join '|') 'Bare start repeats the last arguments'
    $savedBeforeDryRun = Get-Content -LiteralPath $lastFile -Raw
    $null = Invoke-Overseer @run -Account codex1 -DryRun
    Assert-Equal $savedBeforeDryRun (Get-Content -LiteralPath $lastFile -Raw) 'Dry run does not replace the last launch'
    $null = Invoke-Overseer @run -Channel my-telegram
    Assert-True ($state.Launch.Args -contains '--channels') 'Explicit channel bypasses a saved no-channel launch'
    $null = Invoke-Overseer @run -NoChannel -Tool claude
    Assert-True ($state.Launch.Args -cnotcontains '--channels') 'Explicit NoChannel and tool bypass saved channels'
    Assert-Throws { Invoke-Overseer @run -NoChannel } 'NoChannel alone does not reuse the saved account'
    Assert-Throws { Invoke-Overseer @run -Arguments @('--model', 'other') } 'Arguments alone do not reuse the saved account'
    $null = Invoke-Overseer @run -Account codex1 -Channel @()
    $null = Invoke-Overseer @run -Account claude1 -Channel @()
    $text = @(Invoke-Overseer @run -Account '' -Channel @())
    Assert-Equal ('launched claude1 (claude) in ' + $runRepo + ' channel my-telegram') ($text -join '|') 'Bare start repeats the last account with its Telegram channel'
    $text = @(Invoke-Overseer @run -Account codex1 -Channel @())
    Assert-Equal ('launched codex1 (codex) in ' + $runRepo) ($text -join '|') 'An explicit account still wins'
    $text = @(Invoke-Overseer @run -Account '' -Channel @())
    Assert-Equal ('launched codex1 (codex) in ' + $runRepo) ($text -join '|') 'The explicit account becomes the last one'
    $null = Invoke-Overseer @run -Account claude1 -Channel @()
    $state.Fail = $true
    $text = @()
    try { $text = @(Invoke-Overseer @run -Account claude1 -Channel @()); throw 'Expected launch failure' }
    catch { Assert-Equal 'terminal failed' $_.Exception.Message 'A failed launch raises the error' }
    Assert-True (-not ($text -match 'launched')) 'A failed launch prints no launched line'

    # A wrapper or terminal that exits nonzero is a failed launch, not a launched one.
    $state.Fail = $false
    function Start-OverseerLaunch {
        param([string]$Repo, $Launch, [switch]$DryRun)
        $global:LASTEXITCODE = 5
    }
    $text = @()
    try { $text = @(Invoke-Overseer @run -Account claude1 -Channel @()); throw 'Expected launch failure' }
    catch { Assert-True ($_.Exception.Message -like '*exit code 5*') 'A nonzero exit raises an error naming the code' }
    Assert-True (-not ($text -match 'launched')) 'A nonzero exit prints no launched line'
}
