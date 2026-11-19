$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$script = Join-Path $root 'plugins/ps-ai/bin/ps-ai-overseer.ps1'
$ownerFile = Join-Path $PSScriptRoot 'fixtures/personalisation/valid-owner.json'
$projectFile = Join-Path $PSScriptRoot 'fixtures/project/valid.json'
$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $personalisation = Get-Content -Raw $ownerFile | ConvertFrom-Json
    $project = Get-Content -Raw $projectFile | ConvertFrom-Json
    . $script -NoRun
    if ($IsWindows) {
        $wrapper = Join-Path $tempRoot 'fixture-wrapper'
        '' | Set-Content $wrapper
        '@exit /b 0' | Set-Content "$wrapper.cmd"
        $localOwner = Get-Content -Raw $ownerFile | ConvertFrom-Json
        $localOwner.agents[0].command = $wrapper
        $resolved = Get-OverseerLaunch -Personalisation $localOwner -Project $project -AccountId claude -Tool claude
        Assert-Equal "$wrapper.cmd" $resolved.Command 'Legacy extensionless wrapper selects batch sibling'
    }
    & {
        $owner = Get-Content -Raw $ownerFile | ConvertFrom-Json
        foreach ($toolId in @('claude', 'codex', 'copilot')) {
            $agent = @($owner.agents | Where-Object tool -eq $toolId)[0]
            $agent | Add-Member models ([pscustomobject]@{ overseer='role-model' }) -Force
            $project.id = 'model-project'
            $modelLaunch = Get-OverseerLaunch -Personalisation $owner -Project $project -AccountId $agent.id -Tool $toolId
            Assert-True (($modelLaunch.Args -join '|').Contains('--model|role-model')) "$toolId honors the overseer role model"
            foreach ($scope in @('account', 'channel', 'project')) {
                $agent | Add-Member launch ([pscustomobject]@{args=@()}) -Force
                $owner.projects | Add-Member 'model-project' ([pscustomobject]@{ notify=@(); launch=[pscustomobject]@{} }) -Force
                if ($scope -eq 'account') { $agent.launch.args = @('--model=explicit-model') }
                if ($scope -eq 'channel') {
                    $owner.projects.'model-project'.notify = @('fixture')
                    $owner.communication.channels | Add-Member fixture ([pscustomobject]@{launch=[pscustomobject]@{$toolId=@('--model', 'explicit-model')}}) -Force
                }
                if ($scope -eq 'project') { $owner.projects.'model-project'.launch | Add-Member $toolId @('-m', 'explicit-model') -Force }
                $modelLaunch = Get-OverseerLaunch -Personalisation $owner -Project $project -AccountId $agent.id -Tool $toolId
                Assert-True ($modelLaunch.Args -notcontains 'role-model') "$toolId $scope model overrides the role model"
            }
        }
    }
    $project = Get-Content -Raw $projectFile | ConvertFrom-Json
    $launch = Get-OverseerLaunch -Personalisation $personalisation -Project $project -AccountId claude -Tool claude
    Assert-Equal 'claude' $launch.Command 'Claude command'
    Assert-Equal '--channels|plugin:telegram@claude-plugins-official|continue as the overseer' ($launch.Args -join '|') 'Claude flags'
    Assert-Equal 0 $launch.Warnings.Count 'Claude channel has no warning'
    $personalisation.agents[2].roles += 'overseer'
    $launch = Get-OverseerLaunch -Personalisation $personalisation -Project $project -AccountId codex-a -Tool codex
    Assert-True ($launch.Warnings -contains "channel 'telegram-main' has no launch flags for codex; updates go to the terminal only.") 'Codex warning'
    $project.id = 'other-project'
    $launch = Get-OverseerLaunch -Personalisation $personalisation -Project $project -AccountId claude -Tool claude
    Assert-Equal 'continue as the overseer' ($launch.Args -join '|') 'Unknown project uses default notify'
    Assert-Equal 0 $launch.Warnings.Count 'No default channel warning'
    $launch = Get-OverseerLaunch -Personalisation $personalisation -Project $project -AccountId copilot -Tool copilot
    Assert-Equal '-i|continue as the overseer' ($launch.Args -join '|') 'Copilot launches interactively with first prompt after -i'
    $repoPath = Join-Path $tempRoot 'My Projects'
    $config = Join-Path $repoPath '.agents/configuration'
    New-Item -ItemType Directory -Path $config -Force | Out-Null
    Copy-Item $projectFile (Join-Path $config 'project.json')
    $ownerConfig = Join-Path $tempRoot '.agents/configuration'
    New-Item -ItemType Directory -Path $ownerConfig -Force | Out-Null
    Copy-Item $ownerFile (Join-Path $ownerConfig 'ps-ai-personalisation.json')
    $lines = @(& pwsh -NoProfile -File $script -Repo $repoPath -HomeRoot $tempRoot -Tool claude -DryRun)
    Assert-Equal 0 $LASTEXITCODE 'Dry run exits zero'
    Assert-True ($lines -contains $repoPath) 'Repo path with space is one dry-run argument'
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
    try {
        Get-OverseerLaunch -Personalisation $personalisation -Project $project -AccountId codex9 -Tool codex | Out-Null
        throw 'Expected unknown account error'
    } catch {
        Assert-Equal "unknown account 'codex9'" $_.Exception.Message 'Unknown account error'
    }
    $owner = Read-PsAiJson -Path (Join-Path $root 'tests/fixtures/personalisation/valid-owner.json')
    Assert-Equal 'claude' (Select-OverseerAccount -Personalisation $owner -Tool claude).id 'Overseer account for the named tool'
    try {
        Select-OverseerAccount -Personalisation $owner -Tool copilot | Out-Null
        throw 'Expected missing overseer for tool'
    } catch {
        Assert-Equal 'no copilot account has the overseer role; add it to one or pass -Account' $_.Exception.Message 'No silent tool switch'
    }
    try {
        Select-OverseerAccount -Personalisation $owner -Account claude-b -Tool codex | Out-Null
        throw 'Expected account and tool mismatch'
    } catch {
        Assert-Equal "account 'claude-b' is a claude account, not codex" $_.Exception.Message 'Account and tool must agree'
    }
    $emptyRepo = Join-Path $tempRoot 'empty'
    New-Item -ItemType Directory -Path $emptyRepo -Force | Out-Null
    try {
        & $script -Repo $emptyRepo -HomeRoot $tempRoot -DryRun | Out-Null
        throw 'Expected missing project error'
    } catch {
        Assert-Equal "no .agents/configuration/project.json in $emptyRepo; run setup first" $_.Exception.Message 'Missing project error'
    }
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
