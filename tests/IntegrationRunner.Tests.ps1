$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/workspace.ps1')
$runner = Join-Path $root 'tests/integration/run.ps1'
$tempRoot = Join-Path $root ('.agents/temp/integration-runner-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$savedCi = $env:CI
$savedSummary = $env:GITHUB_STEP_SUMMARY
$savedNoColor = $env:NO_COLOR
$savedRendering = $PSStyle.OutputRendering
$savedSummaryText = if ($savedSummary -and (Test-Path -LiteralPath $savedSummary)) { [IO.File]::ReadAllText($savedSummary) } else { '' }
# Fake runs report into the fixture, never into the inherited CI step summary.
$env:GITHUB_STEP_SUMMARY = Join-Path $tempRoot 'full-run-summary.md'
try {
    $inheritedPathStore = $env:LEGION_TEST_USER_PATH_FILE
    $inheritedPathText = [IO.File]::ReadAllText($inheritedPathStore)
    . $runner -NoRun
    Assert-Equal $inheritedPathStore $env:LEGION_TEST_USER_PATH_FILE 'NoRun keeps the caller user PATH fence'
    Assert-Equal $inheritedPathText ([IO.File]::ReadAllText($inheritedPathStore)) 'NoRun leaves the fake store unchanged'
    . $runner
    Assert-Equal $inheritedPathStore $env:LEGION_TEST_USER_PATH_FILE 'Dot-sourcing without NoRun keeps the caller user PATH fence'
    Assert-Equal $inheritedPathText ([IO.File]::ReadAllText($inheritedPathStore)) 'Dot-sourcing leaves the fake store unchanged'
    # Execute the full main block with fake steps: no tool, download or registry call is reachable.
    $mainProbe = Join-Path $tempRoot 'main-fence.ps1'
    Set-Content -LiteralPath $mainProbe -Value @'
param($Runner, $Out, $HomeRoot, $Checkout, [switch]$ClearPathFence)
$options = @{ Out=$Out; HomeRoot=$HomeRoot; Checkout=$Checkout }
. $Runner -NoRun
$NoRun = $false
$Out = $options.Out
$HomeRoot = $options.HomeRoot
$Checkout = $options.Checkout
if ($ClearPathFence) { Remove-Item Env:LEGION_TEST_USER_PATH_FILE }
function Get-TestUserPathSnapshot { return [pscustomobject]@{ Value='fixture'; Kind=2 } }
function Open-IntegrationUserEnvironment { throw 'Fake full runs must never open the registry for writing' }
function Get-IntegrationProbeChecks { return ([ordered]@{}) }
function Get-IntegrationSteps {
    $script:Ctx = @{ Versions=@{}; NotTested=@{} }
    @{ Name='fake-install'; Action={
        if (-not $env:LEGION_TEST_USER_PATH_FILE) { throw 'full run dropped the PATH fence' }
        $before = Get-LegionUserPath
        Set-LegionUserPath -Path ($before + ';' + (Join-Path $HomeRoot '.legion/bin'))
        if ((Get-LegionUserPath) -eq $before) { throw 'fake installer did not use the PATH store' }
    } }
}
function Set-IntegrationConfigEnvironment { }
function Get-IntegrationCoverageProblem { return '' }
$main = (Get-Content -LiteralPath $Runner -Raw) -split '# ---- Main[^\r\n]*', 2
& ([scriptblock]::Create($main[1]))
'@
    $env:CI = 'true'
    $mainOutput = @(& pwsh -NoProfile -File $mainProbe $runner (Join-Path $tempRoot 'main-out') (Join-Path $tempRoot 'main-home') $root 2>&1)
    $mainExit = $LASTEXITCODE
    $mainReport = Get-Content (Join-Path $tempRoot 'main-out/summary.md') -Raw -ErrorAction SilentlyContinue
    Assert-Equal 0 $mainExit ('Full fenced run succeeds with fake installers: ' + ($mainOutput -join "`n") + $mainReport)
    Assert-True (([IO.File]::ReadAllText($inheritedPathStore)).Contains((Join-Path $tempRoot 'main-home/.legion/bin'))) 'Full run writes the inherited store'
    [IO.File]::WriteAllText($inheritedPathStore, $inheritedPathText)
    & {
        function Get-IntegrationOs { return 'windows' }
        $portableFolder = Join-Path $tempRoot 'portable-bin'
        try {
            [IO.File]::WriteAllText($inheritedPathStore, $portableFolder)
            Assert-True ((Get-IntegrationPersistentFolders) -contains $portableFolder) 'Tool discovery includes the fenced PATH store'
        } finally { [IO.File]::WriteAllText($inheritedPathStore, $inheritedPathText) }
    }
    $mainOutput = @(& pwsh -NoProfile -File $mainProbe $runner (Join-Path $tempRoot 'own-out') (Join-Path $tempRoot 'own-home') $root -ClearPathFence 2>&1)
    Assert-Equal 0 $LASTEXITCODE ('A full run creates its own PATH fence when none is inherited: ' + ($mainOutput -join "`n"))
    $ownStore = Join-Path $tempRoot 'legion-work/user-path.txt'
    Assert-True (([IO.File]::ReadAllText($ownStore)).Contains((Join-Path $tempRoot 'own-home/.legion/bin'))) 'The default PATH store stays inside the fixture'
    if ($savedSummary) {
        Assert-Equal $savedSummaryText ([IO.File]::ReadAllText($savedSummary)) 'Fake full runs leave the inherited step summary unchanged'
    }
    # Raw registry snapshots are exercised through a fake key, never through HKCU writes.
    & {
        $script:pathState = [pscustomobject]@{ Value='keep;%FIXTURE%;'; Kind=2; Opens=0; Disposals=0; RestoreFails=$false }
        function Get-TestUserPathSnapshot { return [pscustomobject]@{ Value=$script:pathState.Value; Kind=$script:pathState.Kind } }
        function Open-IntegrationUserEnvironment {
            $script:pathState.Opens++
            $key = [pscustomobject]@{}
            $key | Add-Member ScriptMethod SetValue {
                param($Name, $Value, $Kind)
                if (-not $script:pathState.RestoreFails) { $script:pathState.Value=$Value; $script:pathState.Kind=$Kind }
            }
            $key | Add-Member ScriptMethod DeleteValue { param($Name, $Throw) $script:pathState.Value=$null; $script:pathState.Kind=$null }
            $key | Add-Member ScriptMethod Dispose { $script:pathState.Disposals++ }
            return $key
        }
        $before = Get-TestUserPathSnapshot
        Restore-IntegrationUserPath -Before $before
        Assert-Equal 0 $script:pathState.Opens 'Unchanged raw PATH never opens a writable key'
        foreach ($change in 'value', 'kind', 'absent') {
            $before = if ($change -eq 'absent') { [pscustomobject]@{ Value=$null; Kind=$null } } else { [pscustomobject]@{ Value='keep;%FIXTURE%;'; Kind=2 } }
            $script:pathState.Value = if ($change -eq 'kind') { $before.Value } else { 'changed' }
            $script:pathState.Kind = 1
            Restore-IntegrationUserPath -Before $before
            Assert-Equal $before.Value $script:pathState.Value 'Restore keeps raw placeholders and absence'
            Assert-Equal $before.Kind $script:pathState.Kind 'Restore keeps the original registry kind'
        }
        Assert-Equal 3 $script:pathState.Disposals 'Every writable key is disposed'
        $script:pathState.RestoreFails=$true
        $script:pathState.Value='unrestored'
        $message = ''
        try { Restore-IntegrationUserPath -Before ([pscustomobject]@{ Value='keep;%FIXTURE%;'; Kind=2 }) }
        catch { $message=$_.Exception.Message }
        Assert-Equal 'Tests changed the real user PATH value or registry value kind.' $message 'A change remaining after restoration fails privately'
    }
    Assert-Equal 'PlainText' ([string]$PSStyle.OutputRendering) 'integration runner captures plain text'
    Assert-Equal '1' $env:NO_COLOR 'integration children inherit NO_COLOR'
    $plainScript = Join-Path $tempRoot 'plain-output.ps1'
    Set-Content -LiteralPath $plainScript -Value 'Write-Output "$env:NO_COLOR|$($PSStyle.OutputRendering)"'
    $plainOutput = @(Invoke-IntegrationScript $plainScript)
    Assert-Equal '1|PlainText' ($plainOutput -join "`n") 'child PowerShell disables colour rendering'

    # Ordered first/repeat cases stop after a failure anywhere in the list.
    foreach ($failureIndex in -1, 0, 1) {
        $ran = [Collections.Generic.List[int]]::new()
        $fake = @(foreach ($index in 0..3) {
            $current = $index
            $fail = $failureIndex
            @{ Name = $(if ($index -lt 2) { 'one' } else { 'two' }); Repeat = [bool]($index % 2)
               Action = { $ran.Add($current); if ($current -eq $fail) { throw 'boom' }; 'output' }.GetNewClosure() }
        })
        $cases = @(Invoke-IntegrationSteps -Steps $fake)
        Assert-Equal 4 $cases.Count 'one result per listed action'
        Assert-Equal 'one,one (repeat),two,two (repeat)' ($cases.Name -join ',') 'first and repeat case names'
        Assert-True ((-not $cases[0].Repeat) -and $cases[1].Repeat) 'repeat flag retained'
        if ($failureIndex -lt 0) {
            Assert-Equal '0,1,2,3' ($ran -join ',') 'successful actions run in order'
            Assert-Equal 'passed,passed,passed,passed' ($cases.Result -join ',') 'all actions passed'
        } else {
            Assert-Equal $failureIndex $ran[-1] 'no action runs after the failure'
            Assert-Equal 'failed' $cases[$failureIndex].Result 'throwing action fails'
            Assert-Equal 'boom' $cases[$failureIndex].Message 'failure retains its message'
            foreach ($case in $cases[($failureIndex + 1)..3]) {
                Assert-Equal 'skipped' $case.Result 'all remaining cases are skipped'
                Assert-Equal "previous step failed: $($cases[$failureIndex].Name)" $case.Message 'skip names the failed action'
                Assert-Equal 0 $case.Seconds 'skipped action has zero duration'
            }
        }
        foreach ($case in $cases | Where-Object Result -ne 'skipped') { Assert-True ($case.Seconds -gt 0) 'executed actions have timings' }
    }
    # An explicit skip also stops the ordered sequence and keeps its reason.
    $cases = @(Invoke-IntegrationSteps -Steps @(
        @{ Name = 'skip'; Action = { @{ Skipped = 'local folder refused' } } }
        @{ Name = 'after'; Action = { throw 'must not run' } }
    ))
    Assert-Equal 'skipped,skipped' ($cases.Result -join ',') 'explicit skip stops later actions'
    Assert-Equal 'local folder refused' $cases[0].Message 'skip reason retained'

    # Step output goes to a log file when a log folder is given.
    $logs = Join-Path $tempRoot 'logs'
    $logged = @(@{ Name = 'talk'; Action = { 'hello log' } })
    Invoke-IntegrationSteps -Steps $logged -LogFolder $logs | Out-Null
    Assert-True ((Get-Content -LiteralPath (Join-Path $logs 'talk.log') -Raw) -like '*hello log*') 'step output is logged'

    $partial = Invoke-IntegrationBlock { 'before assertion'; throw 'assertion failed' }
    Assert-True ($partial.Log -like '*before assertion*assertion failed*') 'output before a throwing assertion is retained'

    # Child output must survive buffering by a caller, on both successful and failed steps.
    $installer = Join-Path $tempRoot 'installer.ps1'
    Set-Content -LiteralPath $installer -Value @('Write-Output "installer stdout"', 'Write-Output "installer stdout"', 'Write-Host "installer host output"', '[Console]::Error.WriteLine("installer stderr")')
    $installerSteps = @(
        @{ Name = 'installer-pass'; Action = { $null = Invoke-IntegrationScript $installer } }
        @{ Name = 'installer-pass'; Repeat = $true; Action = { $null = Invoke-IntegrationScript $installer } }
        @{ Name = 'installer-assert'; Action = { $buffer = Invoke-IntegrationScript $installer; throw 'version assertion' } }
    )
    $null = Invoke-IntegrationSteps -Steps $installerSteps -LogFolder $logs
    foreach ($name in 'installer-pass', 'installer-pass-repeat', 'installer-assert') {
        $log = Get-Content -LiteralPath (Join-Path $logs "$name.log") -Raw
        foreach ($text in 'installer stdout', 'installer host output', 'installer stderr') {
            Assert-True ($log.Contains($text)) "$name keeps $text"
        }
        Assert-Equal 2 ([regex]::Matches($log, 'installer stdout').Count) "$name retains repeated lines without duplicating returned output"
    }
    Set-Content -LiteralPath $installer -Value @('Write-Output "before installer failure"', 'exit 7')
    $failedInstaller = Invoke-IntegrationBlock { $buffer = Invoke-IntegrationScript $installer }
    Assert-Equal 'failed' $failedInstaller.Result 'a failed child script still fails the step'
    Assert-True ($failedInstaller.Log -like '*before installer failure*') 'failed child output is retained'
    Assert-True ($failedInstaller.Message -like '*exited 7*') 'failed child exit code is retained'

    # The probe never adds a case and never fails, even when it throws.
    $probe = (Get-IntegrationProbe -Checks ([ordered]@{ good = { 'v1' }; bad = { throw 'no such tool' } })) -join "`n"
    Assert-True ($probe -like '*good*v1*') 'probe records a version'
    Assert-True ($probe -like '*bad*not found*') 'probe records a missing tool without throwing'
    Assert-Equal 0 @(Invoke-IntegrationSteps -Steps @()).Count 'no steps, no cases'

    # The legacy version probe passes a command, not the CLI's version-selection flag.
    $legacyProbe = Join-Path $tempRoot 'legacy-probe.ps1'
    Set-Content -LiteralPath $legacyProbe -Value @'
if (($args -join '|') -ne '-NoProfile|-Command|$PSVersionTable.PSVersion.ToString()') { throw 'unexpected legacy probe arguments' }
'5.1.0'
'@
    & {
        function Get-Command { [pscustomobject]@{ Source = $legacyProbe } }
        $checks = Get-IntegrationProbeChecks
        Assert-Equal 'powershell: 5.1.0' (Get-IntegrationProbe -Checks ([ordered]@{ powershell = $checks.powershell })) 'legacy probe records the Windows PowerShell version'
    }

    # The report: XML, benchmark JSON and summary.md; summary appended to GITHUB_STEP_SUMMARY.
    $out = Join-Path $tempRoot 'results'
    $env:GITHUB_STEP_SUMMARY = Join-Path $tempRoot 'step-summary.md'
    $reportCases = @(
        [pscustomobject]@{ Name = 'setup'; Seconds = 4.21; Result = 'passed'; Message = ''; Repeat = $false }
        [pscustomobject]@{ Name = 'setup (repeat)'; Seconds = 0.62; Result = 'passed'; Message = ''; Repeat = $true }
        [pscustomobject]@{ Name = 'add'; Seconds = 1.5; Result = 'failed'; Message = 'boom'; Repeat = $false }
        [pscustomobject]@{ Name = 'add (repeat)'; Seconds = 0; Result = 'skipped'; Message = 'needs add'; Repeat = $true }
    )
    Write-IntegrationReport -Out $out -Os 'linux' -Cases $reportCases -Probe @('winget: not found') -Extra 'claude 2.1.0'
    $xml = [xml](Get-Content -LiteralPath (Join-Path $out 'integration-linux.xml') -Raw)
    Assert-Equal 'integration.linux' $xml.testsuite.name 'suite name'
    Assert-Equal '4' $xml.testsuite.tests 'four test cases'
    Assert-Equal 'integration.linux' $xml.testsuite.testcase[0].classname 'class name'
    $bench = @(ConvertFrom-Json (Get-Content -LiteralPath (Join-Path $out 'integration-bench-linux.json') -Raw))
    Assert-Equal 2 $bench.Count 'only passed cases in the benchmark'
    Assert-Equal 'linux / setup' $bench[0].name 'benchmark name'
    Assert-Equal 'claude 2.1.0' $bench[0].extra 'extra on the first-run row'
    $summary = Get-Content -LiteralPath (Join-Path $out 'summary.md') -Raw
    Assert-True ($summary -like '*winget: not found*') 'summary has the probe'
    Assert-True ($summary -like '*| step | first s | repeat s | result |*') 'summary has the table header'
    Assert-True ($summary -like '*| setup | 4.210 | 0.620 | passed |*') 'summary row for a passed step'
    Assert-True ($summary -like '*| add | 1.500 | 0.000 | failed |*') 'summary row for a failed step'
    Assert-True ((Get-Content -LiteralPath $env:GITHUB_STEP_SUMMARY -Raw) -like '*| setup | 4.210*') 'summary appended to GITHUB_STEP_SUMMARY'

    # Snapshots retain content hashes and diagnose changed, added and removed paths.
    $tree = Join-Path $tempRoot 'tree'
    New-Item -ItemType Directory -Path (Join-Path $tree 'sub') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $tree 'sub/a.txt') -Value 'one'
    $before = Get-TreeSnapshot -Path $tree
    Assert-TreeUnchanged $before (Get-TreeSnapshot -Path $tree)
    Set-Content -LiteralPath (Join-Path $tree 'sub/a.txt') -Value 'two'
    $result = Invoke-IntegrationBlock { Assert-TreeUnchanged $before (Get-TreeSnapshot -Path $tree) }
    Assert-True ($result.Message -like '*changed: sub/a.txt*') 'changed file is named'
    Set-Content -LiteralPath (Join-Path $tree 'sub/a.txt') -Value 'one'
    Rename-Item -LiteralPath (Join-Path $tree 'sub/a.txt') -NewName 'b.txt'
    $result = Invoke-IntegrationBlock { Assert-TreeUnchanged $before (Get-TreeSnapshot -Path $tree) }
    Assert-True ($result.Message -like '*removed: sub/a.txt*') 'removed file is named'
    Assert-True ($result.Message -like '*added: sub/b.txt*') 'added file is named'
    foreach ($number in 1..25) { Set-Content -LiteralPath (Join-Path $tree "file-$number.txt") -Value 'new' }
    $result = Invoke-IntegrationBlock { Assert-TreeUnchanged $before (Get-TreeSnapshot -Path $tree) }
    Assert-Equal 20 @($result.Message -split "`n" | Where-Object { $_ -match '^(added|removed|changed):' }).Count 'diagnostic lists at most 20 relative paths'
    Assert-True ($result.Message -like '*7 more paths omitted*') 'diagnostic reports omitted path count'

    # Without -NoRun and without CI=true the script stops before any step.
    $env:CI = ''
    $refusedOut = Join-Path $tempRoot 'refused'
    $text = (& pwsh -NoProfile -File $runner -Out $refusedOut -HomeRoot (Join-Path $tempRoot 'home') 2>&1 | Out-String)
    Assert-True ($LASTEXITCODE -ne 0) 'a local run exits non-zero'
    Assert-True ($text -like '*CI*') 'the refusal mentions CI'
    Assert-True (-not (Test-Path -LiteralPath $refusedOut)) 'a refused run writes nothing'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'home'))) 'a refused run does not create the home'

    # Dry listing: building the complete real-CLI sequence invokes no action.
    $steps = @(Get-IntegrationSteps -HomeRoot (Join-Path $tempRoot 'home') -Checkout $root -Work (Join-Path $tempRoot 'work') -Os 'linux')
    $expected = 'install-cli-claude,install-cli-codex,install-cli-copilot,install-uv,install-legion,setup,add,remove,repo-private,repo-shared,uninstall,reinstall,restore-launchers,purge'
    Assert-Equal $expected (($steps | Where-Object { -not $_.Repeat }).Name -join ',') 'first-run step order unchanged'
    Assert-Equal $expected (($steps | Where-Object Repeat).Name -join ',') 'repeat step order unchanged'
    Assert-Equal 28 $steps.Count 'all fourteen first/repeat pairs retained'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'home'))) 'building the steps touches nothing'
    # Replace every real entry point with a recorder to verify action wiring, not just labels.
    $script:listedCalls = @()
    foreach ($functionName in @('Invoke-CliInstallFirst', 'Invoke-CliInstallRepeat', 'Invoke-UvInstallFirst', 'Invoke-UvInstallRepeat', 'Invoke-LegionInstallFirst', 'Invoke-LegionInstallRepeat', 'Invoke-SetupFirst', 'Invoke-SetupRepeat', 'Invoke-AddFirst', 'Invoke-AddRepeat', 'Invoke-RemoveFirst', 'Invoke-RemoveRepeat', 'Invoke-RepoPrivateFirst', 'Invoke-RepoPrivateRepeat', 'Invoke-RepoSharedFirst', 'Invoke-RepoSharedRepeat', 'Invoke-UninstallFirst', 'Invoke-UninstallRepeat', 'Invoke-ReinstallFirst', 'Invoke-ReinstallRepeat', 'Invoke-RestoreLaunchersFirst', 'Invoke-RestoreLaunchersRepeat', 'Invoke-PurgeFirst', 'Invoke-PurgeRepeat')) {
        Set-Item "Function:$functionName" ([scriptblock]::Create("`$script:listedCalls += '$functionName ' + (`$args -join ' ')"))
    }
    $listed = @(Invoke-IntegrationSteps $steps)
    Assert-Equal 28 $script:listedCalls.Count 'every listed action is wired to a real entry point'
    Assert-Equal 0 @($listed | Where-Object Result -ne 'passed').Count 'dry sequence passes with fakes'
    Assert-Equal 'Invoke-CliInstallFirst claude,Invoke-CliInstallRepeat claude,Invoke-CliInstallFirst codex,Invoke-CliInstallRepeat codex,Invoke-CliInstallFirst copilot,Invoke-CliInstallRepeat copilot' ($script:listedCalls[0..5] -join ',') 'each CLI first/repeat receives the right tool'
    Assert-Equal 'Invoke-UvInstallFirst ,Invoke-UvInstallRepeat ,Invoke-LegionInstallFirst ,Invoke-LegionInstallRepeat ,Invoke-SetupFirst ,Invoke-SetupRepeat ,Invoke-AddFirst ,Invoke-AddRepeat ,Invoke-RemoveFirst ,Invoke-RemoveRepeat ,Invoke-RepoPrivateFirst ,Invoke-RepoPrivateRepeat ,Invoke-RepoSharedFirst ,Invoke-RepoSharedRepeat ,Invoke-UninstallFirst ,Invoke-UninstallRepeat ,Invoke-ReinstallFirst ,Invoke-ReinstallRepeat ,Invoke-RestoreLaunchersFirst ,Invoke-RestoreLaunchersRepeat ,Invoke-PurgeFirst ,Invoke-PurgeRepeat ' ($script:listedCalls[6..27] -join ',') 'remaining entry points run in order'

    # ---- Fakes below replace the runner's functions; each block loads the real ones again first. ----
    $fakeHome = Join-Path $tempRoot 'fake-home'
    $fakeWork = Join-Path $tempRoot 'fake-work'
    New-Item -ItemType Directory -Path $fakeHome, $fakeWork -Force | Out-Null
    function Reset-Runner {
        param([switch]$AllowFallback)
        . $runner -NoRun
        $null = Get-IntegrationSteps -HomeRoot $fakeHome -Checkout $root -Work $fakeWork -Os 'linux' -AllowFallback:$AllowFallback
        $script:calls = @()
    }
    # Dot-source to replace the script runner with one that records each call's arguments.
    function Use-CallRecorder {
        function Invoke-IntegrationScript { param($Script, $Arguments = @()) $script:calls += , @($Arguments | ForEach-Object { $_ }); return @('ok') }
    }
    function Assert-ThrowsLike {
        param([scriptblock]$Action, [string]$Pattern, [string]$Message)
        $text = $null
        try { & $Action | Out-Null } catch { $text = $_.Exception.Message }
        Assert-True (($null -ne $text) -and ($text -like $Pattern)) $Message
    }

    # CLI process logs are runtime output; all legion state must still be compared.
    foreach ($repeatStep in 'Invoke-LegionInstallRepeat', 'Invoke-SetupRepeat') {
        . Reset-Runner
        $repeatHome = Join-Path $tempRoot $repeatStep
        $script:Ctx.HomeRoot = $repeatHome
        foreach ($tool in 'claude', 'codex', 'copilot') { $script:Ctx.Targets[$tool] = @{ Source = $root; SourceRef = '' } }
        $config = Join-Path $repeatHome '.legion/configuration'
        New-Item -ItemType Directory -Path $config -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $config 'personalisation.json') -Value '{"agents":[{"id":"copilot1","tool":"copilot","configDir":"~/.legion/agents/copilot1"}]}'
        New-Item -ItemType Directory -Path (Join-Path $repeatHome '.copilot'), (Join-Path $repeatHome '.codex'), (Join-Path $repeatHome '.legion/agents/copilot1') -Force | Out-Null
        $script:runtimeFiles = @('.copilot/logs/process-1-100.log', '.legion/agents/copilot1/logs/process-2-200.log')
        foreach ($os in 'windows', 'linux', 'macos') { $script:runtimeFiles += ".codex/tmp/arg0-$os/codex-arg0abc123/.lock" }
        $script:ownedFile = ''
        function Invoke-IntegrationScript {
            foreach ($relative in $script:runtimeFiles) {
                $log = Join-Path $script:Ctx.HomeRoot $relative
                New-Item -ItemType Directory -Path (Split-Path $log) -Force | Out-Null
                Add-Content -LiteralPath $log -Value 'listing'
            }
            if ($script:ownedFile) { Add-Content -LiteralPath (Join-Path $script:Ctx.HomeRoot $script:ownedFile) -Value 'unexpected write' }
            return @('skip: legion (already done)')
        }
        $script:Ctx.HomeSnapshot = Get-IntegrationHomeSnapshot
        $result = Invoke-IntegrationBlock { & $repeatStep }
        Assert-Equal 'passed' $result.Result "$repeatStep allows CLI-owned logs and helper locks"
        # Existing logs can change while another listing creates a new one.
        $script:runtimeFiles += '.copilot/logs/process-3-300.log'
        $result = Invoke-IntegrationBlock { & $repeatStep }
        Assert-Equal 'passed' $result.Result "$repeatStep allows new CLI process logs"
        foreach ($relative in '.copilot/settings.json', '.copilot/settings.json.lock', '.claude/plugins/installed_plugins.json', '.codex/config.toml', '.copilot/logs/legion.json', '.copilot/logs/process-extra.log', '.codex/tmp/legion.json', '.codex/plugins/cache/ps-legion-marketplace/legion/0.6.0/SKILL.md', '.legion/configuration/notes.md') {
            $file = Join-Path $repeatHome $relative
            New-Item -ItemType Directory -Path (Split-Path $file) -Force | Out-Null
            Set-Content -LiteralPath $file -Value 'first'
            $script:Ctx.HomeSnapshot = Get-IntegrationHomeSnapshot
            $script:ownedFile = $relative
            $result = Invoke-IntegrationBlock { & $repeatStep }
            Assert-Equal 'failed' $result.Result "$repeatStep rejects changes to $relative"
            Assert-True ($result.Message.Contains("changed: $relative")) 'failure names the changed relative path'
        }
    }

    # Every CLI's config variable points at the throwaway default folder.
    . Reset-Runner
    $savedEnv = @{}
    foreach ($name in 'CLAUDE_CONFIG_DIR', 'CODEX_HOME', 'COPILOT_HOME') { $savedEnv[$name] = [Environment]::GetEnvironmentVariable($name) }
    try {
        Set-IntegrationConfigEnvironment
        Assert-Equal (Join-Path $fakeHome '.claude') $env:CLAUDE_CONFIG_DIR 'claude config variable'
        Assert-Equal (Join-Path $fakeHome '.codex') $env:CODEX_HOME 'codex config variable'
    } finally {
        foreach ($name in $savedEnv.Keys) {
            if ($null -eq $savedEnv[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($name, $savedEnv[$name]) }
        }
    }

    # After an install the executable is found through the saved PATH, in this process.
    . Reset-Runner
    $savedPath = $env:PATH
    try {
        # A tiny fake CLI in a folder that is not on PATH yet.
        $savedFolder = Join-Path $fakeWork 'saved-bin'
        New-Item -ItemType Directory -Path $savedFolder -Force | Out-Null
        $fakeCli = if ($IsWindows) { 'legion-fake-cli.cmd' } else { 'legion-fake-cli' }
        Set-Content -LiteralPath (Join-Path $savedFolder $fakeCli) -Value $(if ($IsWindows) { '@echo off' } else { '#!/bin/sh' })
        Set-TestExecutable (Join-Path $savedFolder $fakeCli)
        function Get-IntegrationPersistentFolders { return @($savedFolder) }
        $resolved = Resolve-IntegrationCommand 'legion-fake-cli'
        Assert-True (Test-Path -LiteralPath $resolved -PathType Leaf) 'the executable is resolved from the saved PATH'
        Assert-True (@($env:PATH -split [IO.Path]::PathSeparator) -contains $savedFolder) 'the runner PATH now has the folder'
        $threw = $false
        function Get-IntegrationPersistentFolders { return @() }
        try { Resolve-IntegrationCommand 'legion-missing-cli' | Out-Null } catch { $threw = $true }
        Assert-True $threw 'a tool missing everywhere is an error'
    } finally { $env:PATH = $savedPath }

    # Windows without a working winget asks the installer for the zip method.
    . Reset-Runner
    function Get-IntegrationOs { return 'windows' }
    . Use-CallRecorder
    function Test-IntegrationWingetWorks { return $false }
    Invoke-CliInstallScript 'claude' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -like '*-Method zip*') 'no winget selects -Method zip'
    function Test-IntegrationWingetWorks { return $true }
    $script:calls = @()
    Invoke-CliInstallScript 'claude' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -notlike '*-Method*') 'a working winget keeps the default method'
    # winget runs but its install fails: the installer asks for a method (exit 2), so the runner retries with zip.
    function Invoke-IntegrationScript {
        param($Script, $Arguments = @())
        $script:calls += , @($Arguments | ForEach-Object { $_ })
        if ($Arguments -notcontains '-Method') { throw "$(Split-Path $Script -Leaf) exited 2`nwinget failed (exit 1)." }
        return @('ok')
    }
    $script:calls = @()
    $lines = Invoke-CliInstallScript 'uv'
    Assert-Equal 2 $calls.Count 'a failed winget install is retried once'
    Assert-True ((@($calls[1]) -join ' ') -like '*-Method zip*') 'the retry uses -Method zip'
    Assert-Equal 'ok' ($lines -join '|') 'the retry output is returned'
    function Invoke-IntegrationScript { param($Script, $Arguments = @()) throw "$(Split-Path $Script -Leaf) exited 1" }
    Assert-ThrowsLike { Invoke-CliInstallScript 'uv' } '*exited 1*' 'other install failures are not retried'

    # CLI repeats compare the version token and executable independently of notices.
    foreach ($tool in 'claude', 'codex', 'copilot') {
        . Reset-Runner
        $script:fakeCommand = Join-Path $fakeWork "version-$tool.ps1"
        $firstCommand = $script:fakeCommand
        function Resolve-IntegrationCommand { return $script:fakeCommand }
        function Invoke-CliInstallScript { return @('skip: CLI (already done)') }
        Set-Content -LiteralPath $firstCommand -Value @(
            "Write-Output 'first-run notice'"
            "Write-Error 'stderr notice' -ErrorAction Continue"
            "Write-Output 'cli v1.2.3-beta.1'"
            '$global:LASTEXITCODE = 0'
        )
        Invoke-CliInstallFirst $tool | Out-Null
        Set-Content -LiteralPath $firstCommand -Value @("Write-Output 'cli 1.2.3-beta.1'", '$global:LASTEXITCODE = 0')
        $result = Invoke-IntegrationBlock { Invoke-CliInstallRepeat $tool }
        Assert-Equal 'passed' $result.Result "$tool repeat ignores first-call stdout and stderr notices"
        Assert-Equal '1.2.3-beta.1' $script:Ctx.Versions[$tool] "$tool stores the parsed version token"

        Set-Content -LiteralPath $firstCommand -Value @("Write-Output 'cli 1.2.4'", '$global:LASTEXITCODE = 0')
        $result = Invoke-IntegrationBlock { Invoke-CliInstallRepeat $tool }
        Assert-Equal 'failed' $result.Result "$tool repeat rejects a real version change"
        Assert-True ($result.Message.Contains("first version:`n1.2.3-beta.1`nrepeat version:`n1.2.4")) "$tool failure prints both versions verbatim"

        $script:fakeCommand = Join-Path $fakeWork "other-version-$tool.ps1"
        Set-Content -LiteralPath $script:fakeCommand -Value @("Write-Output 'cli 1.2.3-beta.1'", '$global:LASTEXITCODE = 0')
        $result = Invoke-IntegrationBlock { Invoke-CliInstallRepeat $tool }
        Assert-Equal 'failed' $result.Result "$tool repeat rejects a different executable with the same version"
        Assert-True ($result.Message.Contains("first executable:`n$firstCommand`nrepeat executable:`n$script:fakeCommand")) "$tool failure prints both executable paths verbatim"
    }

    # Step 2 with fakes: nothing real runs; the behaviour block decides what each install.ps1 call does.
    $refusal = "install.ps1 exited 1`ncodex exited 1`nlocal folder marketplace is not supported"
    function Install-Fakes {
        function Invoke-IntegrationScript {
            param($Script, $Arguments = @())
            $words = @($Arguments)
            $call = @{ Tool = $words[$words.IndexOf('-Tools') + 1]; Source = $words[$words.IndexOf('-Source') + 1]; Words = $words }
            $script:calls += , $call
            return @(& $script:behavior $call)
        }
        function Test-IntegrationPluginListed { return $true }
        function Assert-IntegrationControlFolder { }
        function Get-IntegrationPluginVersion { return Get-CheckoutVersion }
    }

    # A release call from a main push never falls back unless the parameter says so.
    $savedRef = $env:GITHUB_REF; $savedEvent = $env:GITHUB_EVENT_NAME
    try {
        $env:GITHUB_REF = 'refs/heads/main'; $env:GITHUB_EVENT_NAME = 'push'
        . Reset-Runner
        . Install-Fakes
        $script:behavior = { param($call) if ($call.Tool -eq 'codex') { throw $refusal }; 'ok' }
        $result = Invoke-IntegrationBlock { Invoke-LegionInstallFirst }
        Assert-True (-not ($calls | Where-Object { $_.Source -eq $script:MarketplaceRepo -and $_.Source -ne $root })) 'the main-push environment alone enables no fallback'
        Assert-Equal 'codex' (@($script:Ctx.NotTested.Keys) -join ',') 'the release call skips codex'
    } finally { $env:GITHUB_REF = $savedRef; $env:GITHUB_EVENT_NAME = $savedEvent }

    # Each case resets the runner, fakes the installer (codex throws the given text), runs the install step and checks the outcome.
    $codexRefused = { param($call) if ($call.Tool -eq 'codex' -and $call.Source -eq $root) { throw $refusal }; 'ok' }
    $cases = @(
        @{ Name = 'an ordinary installer failure fails the step and the other tools are still tried'; Fallback = $true
           Behavior = { param($call) if ($call.Tool -eq 'codex') { throw "install.ps1 exited 1`nnetwork unreachable" }; 'ok' }
           Result = 'failed'; Check = {
               Assert-True ($result.Message -like '*codex*network unreachable*') "the failure keeps the tool and the message: [$($result.Message)]"
               Assert-Equal 'claude,codex,copilot' (($calls | ForEach-Object { $_.Tool }) -join ',') 'the other tools were still installed'
               Assert-Equal 0 $script:Ctx.NotTested.Count 'nothing was marked not tested' } }
        @{ Name = 'a positively identified refusal skips only that tool'; Fallback = $false
           Behavior = { param($call) if ($call.Tool -eq 'codex') { throw $refusal }; 'ok' }
           Result = 'passed'; Check = {
               Assert-Equal 'codex' (@($script:Ctx.NotTested.Keys) -join ',') 'only codex is not tested'
               Assert-Equal 'claude,copilot' ((Get-IntegrationActiveTools) -join ',') 'later steps use the other two tools'
               Assert-True ($result.Log -like '*not tested from the checkout*') 'the log says codex was not tested from the checkout'
               Assert-True (-not ($calls | Where-Object { $_.Source -ne $root })) 'no call used another source' } }
        @{ Name = 'the fallback uses the published source bound to the tested revision'; Fallback = $true
           Behavior = $codexRefused; Revision = 'abc123'; Main = { 'abc123' }
           Result = 'passed'; Check = {
               $fallback = @($calls | Where-Object { $_.Source -eq 'BlackGad/ps-legion-marketplace' })
               Assert-Equal 1 $fallback.Count 'only the refusing tool used the fallback'
               Assert-Equal 'codex' $fallback[0].Tool 'the fallback was for codex'
               Assert-True ((@($fallback[0].Words) -join ' ') -like '*-Ref main*') 'the fallback installs main'
               Assert-Equal 2 $script:remoteChecks 'the fallback checks main before and after installation'
               Assert-Equal 0 $script:Ctx.NotTested.Count 'a fallback tool is tested' } }
        @{ Name = 'main moving during fallback installation fails provenance'; Fallback = $true
           Behavior = $codexRefused; Main = { if ($script:remoteChecks -eq 1) { 'abc123' } else { 'def456' } }; Result = 'failed' }
        @{ Name = 'a fallback for another revision fails'; Fallback = $true
           Behavior = $codexRefused; Revision = 'abc123'; Main = { 'def456' }; Result = 'failed' }
        @{ Name = 'all tools refusing without a fallback skips the step'; Fallback = $false
           Behavior = { param($call) throw "install.ps1 exited 1`n$($call.Tool) exited 1`nlocal folder marketplace is not supported" }; Result = 'skipped' }
    )
    foreach ($case in $cases) {
        . Reset-Runner -AllowFallback:$case.Fallback
        . Install-Fakes
        if ($case.Revision) { function Get-IntegrationRevision { return $case.Revision } }
        $script:remoteChecks = 0
        $script:mainBlock = $case.Main
        if ($case.Main) { function Get-IntegrationRemoteMain { $script:remoteChecks++; return & $script:mainBlock } }
        $script:behavior = $case.Behavior
        $result = Invoke-IntegrationBlock { Invoke-LegionInstallFirst }
        Assert-Equal $case.Result $result.Result $case.Name
        if ($case.Check) { & $case.Check }
    }
    # When every tool refused the checkout nothing real was tested; the gate must say so instead of passing.
    . Reset-Runner
    Assert-Equal '' (Get-IntegrationCoverageProblem) 'Nothing refused is no coverage problem'
    $script:Ctx.NotTested.codex = 'codex refuses a local folder'
    Assert-Equal '' (Get-IntegrationCoverageProblem) 'One refusing tool still leaves tested tools'
    $script:Ctx.NotTested.claude = 'claude refuses a local folder'
    $script:Ctx.NotTested.copilot = 'copilot refuses a local folder'
    Assert-True ((Get-IntegrationCoverageProblem).Contains('codex refuses a local folder')) 'Every tool refusing fails the gate with the reasons'
    # Another tool's refusal text does not excuse this tool.
    . Reset-Runner
    Assert-True (-not (Test-IntegrationLocalRefusal 'claude' $refusal)) 'a refusal by codex is not a claude refusal'
    Assert-True (Test-IntegrationLocalRefusal 'codex' $refusal) 'a codex refusal is identified'
    Assert-True (-not (Test-IntegrationLocalRefusal 'codex' "install.ps1 exited 1`ncodex exited 1`nconnection reset")) 'an unrelated failure is not a refusal'

    # Setup repeats for explicit ids and never asks for new accounts; both runs use the same arguments.
    . Reset-Runner
    foreach ($tool in 'claude', 'codex', 'copilot') { $script:Ctx.Targets[$tool] = @{ Source = $root; SourceRef = '' } }
    . Use-CallRecorder
    Invoke-SetupAccounts | Out-Null
    $firstCalls = @($calls | ForEach-Object { @($_) -join ' ' })
    $script:calls = @()
    Invoke-SetupAccounts | Out-Null
    $repeatCalls = @($calls | ForEach-Object { @($_) -join ' ' })
    Assert-Equal 3 $firstCalls.Count 'one setup call per tool'
    Assert-Equal ($firstCalls -join "`n") ($repeatCalls -join "`n") 'the repeat uses the same arguments'
    foreach ($tool in 'claude', 'codex', 'copilot') {
        Assert-True (@($firstCalls | Where-Object { $_ -like "*-Add $tool -Id ${tool}1 *" }).Count -eq 1) "$tool has an explicit stable id"
    }

    # The Shared fixture commits AGENTS.md and passes -RulesFile; Private passes none.
    . Reset-Runner
    . Use-CallRecorder
    Invoke-RepositoryScript 'repo' 'Shared' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -like '*-RulesFile AGENTS.md*') 'Shared passes -RulesFile'
    $script:calls = @()
    Invoke-RepositoryScript 'repo' 'Private' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -notlike '*-RulesFile*') 'Private passes no rules file'
    $repoB = New-IntegrationRepo 'repo-b' -WithRules
    Assert-True (@(git -C $repoB ls-files 'AGENTS.md').Count -eq 1) 'the Shared fixture tracks AGENTS.md'
    $repoA = New-IntegrationRepo 'repo-a'
    Assert-True (@(git -C $repoA ls-files 'AGENTS.md').Count -eq 0) 'the plain fixture has no AGENTS.md'

    # Check Shared rules assertions with the bundled block and fake setup, without real CLIs.
    & {
        . Reset-Runner
        $sharedRepo = New-IntegrationRepo 'rules-check' -WithRules
        $rulesBlock = Get-Content -LiteralPath (Join-Path $root 'plugins/legion/skills/legion-repository/references/rules-file-lines.md') -Raw
        $rulesCopies = 1
        function New-IntegrationRepo { return $sharedRepo }
        function Assert-LegionItems { }
        function Invoke-RepositoryScript {
            Set-Content -LiteralPath (Join-Path $sharedRepo 'AGENTS.md') -Value ($rulesBlock * $rulesCopies)
            git -C $sharedRepo add AGENTS.md
            git -C $sharedRepo commit --quiet -m 'Set up legion orchestration'
            return @('prepared: Shared orchestration')
        }
        Invoke-RepoSharedFirst | Out-Null
        foreach ($rulesCopies in 0, 2) {
            $message = ''
            try { Invoke-RepoSharedFirst | Out-Null } catch { $message = $_.Exception.Message }
            Assert-Equal "AGENTS.md has the rules block $rulesCopies times" $message 'Shared rejects missing and duplicated rules blocks'
        }
    }

    # Listing: the catalog's arguments and parser; a disabled entry is not installed.
    . Reset-Runner
    function Invoke-IntegrationCli { param($Tool, $Arguments, $Folder) $script:calls += , @($Arguments | ForEach-Object { $_ }); return @{ ExitCode = 0; Lines = @($script:listing) } }
    $script:listing = '[{"id":"legion@ps-legion-marketplace","enabled":false}]'
    Assert-True (-not (Test-IntegrationPluginListed 'claude' 'folder')) 'a disabled entry is not installed'
    Assert-True (Test-IntegrationPluginListed 'claude' 'folder' -IncludeDisabled) 'a disabled entry is still listed'
    Assert-Equal 'plugin list --json' (@($calls[0]) -join ' ') 'the catalog listing arguments are used'
    $script:listing = '[{"id":"legion@ps-legion-marketplace","enabled":true}]'
    Assert-True (Test-IntegrationPluginListed 'claude' 'folder') 'an enabled entry is installed'
    $script:listing = '[]'
    Assert-True (-not (Test-IntegrationPluginListed 'claude' 'folder' -IncludeDisabled)) 'an empty folder lists nothing'
    Assert-IntegrationControlFolder 'claude'
    $script:listing = '[{"id":"legion@ps-legion-marketplace","enabled":true}]'
    Assert-ThrowsLike { Assert-IntegrationControlFolder 'claude' } '*' 'a control folder that lists legion fails'

    # Uninstall: default and account folders are captured first and checked afterwards; the repeat must have nothing to do.
    . Reset-Runner
    foreach ($tool in 'claude', 'codex', 'copilot') { $script:Ctx.Targets[$tool] = @{ Source = $root; SourceRef = '' } }
    New-Item -ItemType Directory -Path (Join-Path $fakeHome '.legion/configuration'), (Join-Path $fakeHome '.legion/agents'), (Join-Path $fakeHome '.legion/bin') -Force | Out-Null
    $accountFolder = '~/.legion/agents/claude1'
    function Get-IntegrationSettings { return @{ Path = 'x'; Data = [pscustomobject]@{ agents = @([pscustomobject]@{ id = 'claude1'; tool = 'claude'; configDir = $accountFolder }) } } }
    $targets = @(Get-IntegrationUninstallTargets)
    Assert-Equal 4 $targets.Count 'three default folders and one account folder'
    Assert-True (@($targets | Where-Object { $_.Tool -eq 'claude' -and $_.Folder -eq (Join-Path $fakeHome '.legion/agents/claude1') }).Count -eq 1) 'the account folder is a target'
    function Invoke-UninstallScript { return @($script:uninstallOutput) }
    function Resolve-IntegrationCommand { return @((Get-Command pwsh -CommandType Application).Source)[0] }
    function Get-IntegrationPluginVersion { return $null }
    $script:stale = ''
    function Test-IntegrationPluginListed { param($Tool, $Folder, [switch]$IncludeDisabled) return ($Folder -like "*$script:stale*" -and $script:stale -ne '') }
    $script:uninstallOutput = 'Uninstalled'
    foreach ($path in Get-IntegrationLauncherPaths 'claude1') { Set-Content -LiteralPath $path -Value 'launcher' }
    Invoke-UninstallFirst | Out-Null
    $ownerPath = @(Get-IntegrationLauncherPaths 'legion')[0]
    Set-Content -LiteralPath $ownerPath -Value 'owner'
    Assert-ThrowsLike { Invoke-UninstallFirst } '*legion*' 'an owner command left behind fails the uninstall'
    Remove-Item -LiteralPath $ownerPath
    $launcherPath = @(Get-IntegrationLauncherPaths 'claude1')[0]
    Rename-Item -LiteralPath $launcherPath -NewName 'claude1.hidden'
    Assert-ThrowsLike { Invoke-UninstallFirst } '*launcher claude1*' 'an account launcher removed by the uninstall fails it'
    Rename-Item -LiteralPath "$launcherPath.hidden" -NewName 'claude1'
    $script:stale = 'claude1'
    Assert-ThrowsLike { Invoke-UninstallFirst } '*claude1*' 'a plugin left in an account folder fails the uninstall'
    $script:stale = ''
    $cacheFolder = Join-Path $fakeHome '.claude/plugins/cache/ps-legion-marketplace'
    New-Item -ItemType Directory -Path $cacheFolder -Force | Out-Null
    Assert-ThrowsLike { Invoke-UninstallFirst } '*cache*' 'a cache left behind fails the uninstall'
    Remove-Item -LiteralPath (Join-Path $fakeHome '.claude') -Recurse -Force
    Assert-ThrowsLike { Invoke-UninstallRepeat } '*' 'a repeat that does not say Nothing to uninstall fails'
    $script:uninstallOutput = 'Nothing to uninstall.'
    Invoke-UninstallRepeat | Out-Null

    # Exercise only the new purge assertions, with fake scripts/CLIs and a separate home.
    & {
        . Reset-Runner
        $purgeHome = Join-Path $tempRoot 'purge-home'
        $outside = Join-Path $tempRoot 'purge-fake-real'
        New-Item -ItemType Directory -Path $purgeHome, $outside -Force | Out-Null
        Set-Content (Join-Path $outside 'keep.txt') 'outside data'
        $outsideHash = (Get-FileHash (Join-Path $outside 'keep.txt')).Hash
        $saved = @{}
        foreach ($name in 'HOME', 'USERPROFILE', 'CLAUDE_CONFIG_DIR', 'CODEX_HOME', 'COPILOT_HOME') { $saved[$name] = [Environment]::GetEnvironmentVariable($name) }
        $env:HOME=$purgeHome
        $env:USERPROFILE=$purgeHome
        $script:Ctx.HomeRoot=$purgeHome
        $script:Ctx.NotTested.copilot='fixture skipped plugin install'
        Set-IntegrationConfigEnvironment
        function Remove-PurgeFixtureFolder {
            param($Path)
            $prefix = [IO.Path]::GetFullPath($purgeHome) + [IO.Path]::DirectorySeparatorChar
            if (-not [IO.Path]::GetFullPath($Path).StartsWith($prefix)) { throw 'Unsafe purge assertion fixture cleanup' }
            if (Test-Path -LiteralPath $Path) { Remove-Item -LiteralPath $Path -Recurse -Force }
        }
        try {
            $legion = Join-Path $purgeHome '.legion'
            New-Item -ItemType Directory -Path (Join-Path $legion 'configuration'), (Join-Path $purgeHome 'custom-claude') -Force | Out-Null
            Set-Content (Join-Path $legion 'configuration/personalisation.json') '{"agents":[{"tool":"claude","configDir":"~/custom-claude"}]}'
            foreach ($tool in $script:IntegrationTools) { New-Item -ItemType Directory -Path (Get-IntegrationToolFolder $tool) -Force | Out-Null }
            $script:purgeOutput='done: purge'
            $script:purgeKeepLegion=$false
            $script:purgeBadVersion=''
            $script:purgeMarketplace=''
            $script:versionCalls=@()
            function Invoke-IntegrationScript {
                param($Script, $Arguments)
                foreach ($flag in '-Uninstall', '-Purge', '-Yes') { Assert-True ($Arguments -contains $flag) "Purge passes $flag" }
                Assert-True ($Arguments -contains $purgeHome) 'Purge passes the isolated home'
                if (-not $script:purgeKeepLegion) { Remove-PurgeFixtureFolder $legion }
                return @($script:purgeOutput)
            }
            function Test-IntegrationPluginListed { $false }
            function Get-IntegrationPluginVersion { $null }
            function Invoke-IntegrationCli {
                param($Tool, $Arguments, $Folder)
                Assert-True ($Folder.StartsWith($purgeHome + [IO.Path]::DirectorySeparatorChar)) 'Every fake CLI call selects a config folder in the purge home'
                if ($Arguments -contains '--version') {
                    $script:versionCalls += $Tool
                    return @{ ExitCode=$(if ($Tool -eq $script:purgeBadVersion) { 1 } else { 0 }); Lines=@('fixture version') }
                }
                $items = @()
                if ($Tool -eq $script:purgeMarketplace) { $items = @(@{name='ps-legion-marketplace'}) }
                $text = if ($Tool -eq 'codex') { @{marketplaces=$items} | ConvertTo-Json -Compress } else { ConvertTo-Json -InputObject $items -Compress }
                return @{ ExitCode=0; Lines=@($text) }
            }
            Invoke-PurgeFirst | Out-Null
            Assert-Equal 4 $script:Ctx.PurgeTargets.Count 'Purge captures defaults and recorded folders before settings disappear'
            Assert-True ($script:Ctx.PurgeTargets.Tool -contains 'copilot') 'Purge checks defaults even for a skipped plugin install'
            Assert-Equal 'claude,codex,copilot' ($script:versionCalls -join ',') 'Purge checks --version for all three CLIs'
            $script:purgeOutput='skip: purge (already done)'
            Invoke-PurgeRepeat | Out-Null

            foreach ($tool in $script:IntegrationTools) {
                $info = Get-IntegrationToolInfo $tool
                $folder = Get-IntegrationToolFolder $tool
                foreach ($relative in (@($info.plugin.cacheDir) + @($info.plugin.purge.paths) + @($info.plugin.purge.emptyDirs))) {
                    if (-not $relative) { continue }
                    $path = Join-Path $folder $relative
                    New-Item -ItemType Directory -Path $path -Force | Out-Null
                    Assert-Throws { Assert-IntegrationPurgeComplete } "Purge assertions reject leftover path $relative"
                    Remove-PurgeFixtureFolder $path
                }
                foreach ($setting in $info.plugin.purge.settings) {
                    $path = Join-Path $folder $setting.path
                    New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
                    Set-Content -LiteralPath $path -Value 'legion leftover'
                    Assert-Throws { Assert-IntegrationPurgeComplete } "Purge assertions reject legion text in $($setting.path)"
                    Remove-Item -LiteralPath $path -Force
                }
            }
            $script:purgeMarketplace='codex'
            Assert-Throws { Assert-IntegrationPurgeComplete } 'Purge assertions reject a marketplace still listed by the CLI'
            $script:purgeMarketplace=''
            $script:purgeBadVersion='copilot'
            Assert-Throws { Assert-IntegrationPurgeComplete } 'Purge assertions reject a broken CLI'
            $script:purgeBadVersion=''
            New-Item -ItemType Directory -Path $legion -Force | Out-Null
            Assert-Throws { Assert-IntegrationPurgeComplete } 'Purge assertions reject a remaining legion home'
            Remove-PurgeFixtureFolder $legion
            $script:purgeOutput='done: purge'
            Assert-Throws { Invoke-PurgeRepeat } 'Repeat must print the exact already-done message'
        } finally {
            Assert-Equal $outsideHash (Get-FileHash (Join-Path $outside 'keep.txt')).Hash 'Purge assertion fakes preserve outside-home bytes'
            Assert-Equal 1 @(Get-ChildItem $outside -Recurse -Force).Count 'Purge assertion fakes preserve outside-home inventory'
            foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name]) }
        }
    }
} finally {
    $env:CI = $savedCi
    $env:GITHUB_STEP_SUMMARY = $savedSummary
    if ($null -eq $savedNoColor) { Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue }
    else { $env:NO_COLOR = $savedNoColor }
    $PSStyle.OutputRendering = $savedRendering
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
