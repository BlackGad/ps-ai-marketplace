$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$runner = Join-Path $root 'tests/integration/run.ps1'
$tempRoot = Join-Path $root ('.agents/temp/integration-runner-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
$savedCi = $env:CI
$savedSummary = $env:GITHUB_STEP_SUMMARY
$savedNoColor = $env:NO_COLOR
$savedRendering = $PSStyle.OutputRendering
try {
    . $runner -NoRun
    Assert-Equal 'PlainText' ([string]$PSStyle.OutputRendering) 'integration runner captures plain text'
    Assert-Equal '1' $env:NO_COLOR 'integration children inherit NO_COLOR'
    $plainScript = Join-Path $tempRoot 'plain-output.ps1'
    Set-Content -LiteralPath $plainScript -Value 'Write-Output "$env:NO_COLOR|$($PSStyle.OutputRendering)"'
    $plainOutput = @(Invoke-IntegrationScript $plainScript)
    Assert-Equal '1|PlainText' ($plainOutput -join "`n") 'child PowerShell disables colour rendering'

    # Each fake step gives a first and a repeat case with a time above zero.
    $fake = @(
        @{ Name = 'one'; DependsOn = @(); First = { Start-Sleep -Milliseconds 5 }; Repeat = { Start-Sleep -Milliseconds 5 } }
        @{ Name = 'two'; DependsOn = @('one'); First = { Start-Sleep -Milliseconds 5 }; Repeat = { Start-Sleep -Milliseconds 5 } }
    )
    $cases = @(Invoke-IntegrationSteps -Steps $fake)
    Assert-Equal 4 $cases.Count 'two cases per step'
    Assert-Equal 'one' $cases[0].Name 'first-run case name'
    Assert-Equal 'one (repeat)' $cases[1].Name 'repeat case name'
    Assert-True ((-not $cases[0].Repeat) -and $cases[1].Repeat) 'Repeat flag marks the second run'
    foreach ($case in $cases) {
        Assert-Equal 'passed' $case.Result "$($case.Name) passed"
        Assert-True ($case.Seconds -gt 0) "$($case.Name) has a time above zero"
    }

    # A throwing step fails; dependants skip without running; independent steps still run.
    $script:counter = 0
    $script:independent = 0
    $failing = @(
        @{ Name = 'bad'; DependsOn = @(); First = { throw 'boom' }; Repeat = { } }
        @{ Name = 'child'; DependsOn = @('bad'); First = { $script:counter++ }; Repeat = { $script:counter++ } }
        @{ Name = 'grandchild'; DependsOn = @('child'); First = { $script:counter++ }; Repeat = { $script:counter++ } }
        @{ Name = 'free'; DependsOn = @(); First = { $script:independent++ }; Repeat = { $script:independent++ } }
    )
    $cases = @(Invoke-IntegrationSteps -Steps $failing)
    $byName = @{}
    foreach ($case in $cases) { $byName[$case.Name] = $case }
    Assert-Equal 'failed' $byName['bad'].Result 'throwing step fails'
    Assert-True ($byName['bad'].Message -like '*boom*') 'failure keeps the message'
    Assert-Equal 'skipped' $byName['child'].Result 'dependant is skipped'
    Assert-Equal 'needs bad' $byName['child'].Message 'dependant says what it needs'
    Assert-Equal 'skipped' $byName['child (repeat)'].Result 'dependant repeat is skipped'
    Assert-Equal 'skipped' $byName['grandchild'].Result 'second-level dependant is skipped'
    Assert-Equal 'needs child' $byName['grandchild'].Message 'second-level dependant names its direct parent'
    Assert-Equal 0 $script:counter 'dependant blocks never run'
    Assert-Equal 2 $script:independent 'independent step still ran both times'
    Assert-Equal 'passed' $byName['free'].Result 'independent step passed'

    # A step that returns Skipped is skipped with that message; its dependants skip too.
    $script:counter = 0
    $skipping = @(
        @{ Name = 'codex'; DependsOn = @(); First = { @{ Skipped = 'codex refuses a local folder' } }; Repeat = { $script:counter++ } }
        @{ Name = 'after'; DependsOn = @('codex'); First = { $script:counter++ }; Repeat = { $script:counter++ } }
    )
    $cases = @(Invoke-IntegrationSteps -Steps $skipping)
    Assert-Equal 'skipped' $cases[0].Result 'returned Skipped is skipped'
    Assert-Equal 'codex refuses a local folder' $cases[0].Message 'skip keeps its reason'
    Assert-Equal 'skipped' $cases[1].Result 'its repeat is skipped too'
    Assert-Equal 'needs codex' $cases[2].Message 'dependant of a skipped step says needs'
    Assert-Equal 0 $script:counter 'no block ran after a skip'

    # Step output goes to a log file when a log folder is given.
    $logs = Join-Path $tempRoot 'logs'
    $logged = @(@{ Name = 'talk'; DependsOn = @(); First = { 'hello log' }; Repeat = { 'again' } })
    Invoke-IntegrationSteps -Steps $logged -LogFolder $logs | Out-Null
    Assert-True ((Get-Content -LiteralPath (Join-Path $logs 'talk.log') -Raw) -like '*hello log*') 'step output is logged'

    $partial = Invoke-IntegrationBlock { 'before assertion'; throw 'assertion failed' }
    Assert-True ($partial.Log -like '*before assertion*assertion failed*') 'output before a throwing assertion is retained'

    # Child output must survive buffering by a caller, on both successful and failed steps.
    $installer = Join-Path $tempRoot 'installer.ps1'
    Set-Content -LiteralPath $installer -Value @('Write-Output "installer stdout"', 'Write-Output "installer stdout"', 'Write-Host "installer host output"', '[Console]::Error.WriteLine("installer stderr")')
    $installerSteps = @(
        @{ Name = 'installer-pass'; DependsOn = @(); First = { $null = Invoke-IntegrationScript $installer }; Repeat = { $null = Invoke-IntegrationScript $installer } }
        @{ Name = 'installer-assert'; DependsOn = @(); First = { $buffer = Invoke-IntegrationScript $installer; throw 'version assertion' }; Repeat = { } }
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

    # The real steps exist in the spec's order and depend on what they need (never run here).
    $steps = @(Get-IntegrationSteps -HomeRoot (Join-Path $tempRoot 'home') -Checkout $root -Work (Join-Path $tempRoot 'work') -Os 'linux')
    Assert-Equal 'install-cli-claude,install-cli-codex,install-cli-copilot,install-ps-ai,setup,add,remove,repo-private,repo-shared,uninstall,reinstall,restore-launchers' (($steps.Name) -join ',') 'step order'
    Assert-True ($steps.Where({ $_.Name -eq 'reinstall' }).DependsOn -contains 'uninstall') 'reinstall needs uninstall'
    Assert-True ($steps.Where({ $_.Name -eq 'restore-launchers' }).DependsOn -contains 'reinstall') 'restore-launchers needs reinstall'
    Assert-True ($steps.Where({ $_.Name -eq 'setup' }).DependsOn -contains 'install-ps-ai') 'setup needs install-ps-ai'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $tempRoot 'home'))) 'building the steps touches nothing'

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

    # CLI process logs are runtime output; all ps-ai state must still be compared.
    foreach ($repeatStep in 'Invoke-PsAiInstallRepeat', 'Invoke-SetupRepeat') {
        . Reset-Runner
        $repeatHome = Join-Path $tempRoot $repeatStep
        $script:Ctx.HomeRoot = $repeatHome
        foreach ($tool in 'claude', 'codex', 'copilot') { $script:Ctx.Targets[$tool] = @{ Source = $root; SourceRef = '' } }
        $config = Join-Path $repeatHome '.legion/configuration'
        New-Item -ItemType Directory -Path $config -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $config 'ps-ai-personalisation.json') -Value '{"agents":[{"id":"copilot1","tool":"copilot","configDir":"~/.legion/agents/copilot1"}]}'
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
            return @('skip: ps-ai (already done)')
        }
        $script:Ctx.HomeSnapshot = Get-IntegrationHomeSnapshot
        $result = Invoke-IntegrationBlock { & $repeatStep }
        Assert-Equal 'passed' $result.Result "$repeatStep allows CLI-owned logs and helper locks"
        # Existing logs can change while another listing creates a new one.
        $script:runtimeFiles += '.copilot/logs/process-3-300.log'
        $result = Invoke-IntegrationBlock { & $repeatStep }
        Assert-Equal 'passed' $result.Result "$repeatStep allows new CLI process logs"
        foreach ($relative in '.copilot/settings.json', '.copilot/settings.json.lock', '.claude/plugins/installed_plugins.json', '.codex/config.toml', '.copilot/logs/ps-ai.json', '.copilot/logs/process-extra.log', '.codex/tmp/ps-ai.json', '.codex/plugins/cache/ps-ai-marketplace/ps-ai/0.6.0/SKILL.md', '.legion/configuration/ps-ai-notes.md') {
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
        $fakeCli = if ($IsWindows) { 'ps-ai-fake-cli.cmd' } else { 'ps-ai-fake-cli' }
        Set-Content -LiteralPath (Join-Path $savedFolder $fakeCli) -Value $(if ($IsWindows) { '@echo off' } else { '#!/bin/sh' })
        if (-not $IsWindows) { chmod +x (Join-Path $savedFolder $fakeCli) }
        function Get-IntegrationPersistentFolders { return @($savedFolder) }
        $resolved = Resolve-IntegrationCommand 'ps-ai-fake-cli'
        Assert-True (Test-Path -LiteralPath $resolved -PathType Leaf) 'the executable is resolved from the saved PATH'
        Assert-True (@($env:PATH -split [IO.Path]::PathSeparator) -contains $savedFolder) 'the runner PATH now has the folder'
        $threw = $false
        function Get-IntegrationPersistentFolders { return @() }
        try { Resolve-IntegrationCommand 'ps-ai-missing-cli' | Out-Null } catch { $threw = $true }
        Assert-True $threw 'a tool missing everywhere is an error'
    } finally { $env:PATH = $savedPath }

    # Windows without a working winget asks the installer for the zip method.
    . Reset-Runner
    function Get-IntegrationOs { return 'windows' }
    function Invoke-IntegrationScript { param($Script, $Arguments = @()) $script:calls += , @($Arguments | ForEach-Object { $_ }); return @('ok') }
    function Test-IntegrationWingetWorks { return $false }
    Invoke-CliInstallScript 'claude' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -like '*-Method zip*') 'no winget selects -Method zip'
    function Test-IntegrationWingetWorks { return $true }
    $script:calls = @()
    Invoke-CliInstallScript 'claude' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -notlike '*-Method*') 'a working winget keeps the default method'

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

    # An ordinary installer failure fails the step, and the other tools are still tried.
    . Reset-Runner -AllowFallback
    . Install-Fakes
    $script:behavior = { param($call) if ($call.Tool -eq 'codex') { throw "install.ps1 exited 1`nnetwork unreachable" }; 'ok' }
    $result = Invoke-IntegrationBlock { Invoke-PsAiInstallFirst }
    Assert-Equal 'failed' $result.Result 'an ordinary installer failure is a failure, not a skip'
    Assert-True ($result.Message -like '*codex*network unreachable*') "the failure keeps the tool and the message: [$($result.Message)]"
    Assert-Equal 'claude,codex,copilot' (($calls | ForEach-Object { $_.Tool }) -join ',') 'the other tools were still installed'
    Assert-Equal 0 $script:Ctx.NotTested.Count 'nothing was marked not tested'

    # A positively identified refusal skips only that tool; the others pass with the checkout.
    . Reset-Runner
    . Install-Fakes
    $script:behavior = { param($call) if ($call.Tool -eq 'codex') { throw $refusal }; 'ok' }
    $result = Invoke-IntegrationBlock { Invoke-PsAiInstallFirst }
    Assert-Equal 'passed' $result.Result 'the other tools still pass'
    Assert-Equal 'codex' (@($script:Ctx.NotTested.Keys) -join ',') 'only codex is not tested'
    Assert-Equal 'claude,copilot' ((Get-IntegrationActiveTools) -join ',') 'later steps use the other two tools'
    Assert-True ($result.Log -like '*not tested from the checkout*') 'the log says codex was not tested from the checkout'
    Assert-True (-not ($calls | Where-Object { $_.Source -ne $root })) 'no call used another source'

    # A release call from a main push never falls back unless the parameter says so.
    $savedRef = $env:GITHUB_REF; $savedEvent = $env:GITHUB_EVENT_NAME
    try {
        $env:GITHUB_REF = 'refs/heads/main'; $env:GITHUB_EVENT_NAME = 'push'
        . Reset-Runner
        . Install-Fakes
        $script:behavior = { param($call) if ($call.Tool -eq 'codex') { throw $refusal }; 'ok' }
        $result = Invoke-IntegrationBlock { Invoke-PsAiInstallFirst }
        Assert-True (-not ($calls | Where-Object { $_.Source -like '*ps-ai-marketplace' -and $_.Source -ne $root })) 'the main-push environment alone enables no fallback'
        Assert-Equal 'codex' (@($script:Ctx.NotTested.Keys) -join ',') 'the release call skips codex'
    } finally { $env:GITHUB_REF = $savedRef; $env:GITHUB_EVENT_NAME = $savedEvent }

    # With the parameter, the fallback uses the published source bound to the tested revision.
    . Reset-Runner -AllowFallback
    . Install-Fakes
    function Get-IntegrationRevision { return 'abc123' }
    $script:remoteChecks = 0
    function Get-IntegrationRemoteMain { $script:remoteChecks++; return 'abc123' }
    $script:behavior = { param($call) if ($call.Tool -eq 'codex' -and $call.Source -eq $root) { throw $refusal }; 'ok' }
    $result = Invoke-IntegrationBlock { Invoke-PsAiInstallFirst }
    Assert-Equal 'passed' $result.Result 'the fallback passes'
    $fallback = @($calls | Where-Object { $_.Source -eq 'BlackGad/ps-ai-marketplace' })
    Assert-Equal 1 $fallback.Count 'only the refusing tool used the fallback'
    Assert-Equal 'codex' $fallback[0].Tool 'the fallback was for codex'
    Assert-True ((@($fallback[0].Words) -join ' ') -like '*-Ref main*') 'the fallback installs main'
    Assert-Equal 2 $script:remoteChecks 'the fallback checks main before and after installation'
    Assert-Equal 0 $script:Ctx.NotTested.Count 'a fallback tool is tested'

    . Reset-Runner -AllowFallback
    . Install-Fakes
    $script:remoteChecks = 0
    function Get-IntegrationRemoteMain { $script:remoteChecks++; if ($script:remoteChecks -eq 1) { return 'abc123' }; return 'def456' }
    $script:behavior = { param($call) if ($call.Tool -eq 'codex' -and $call.Source -eq $root) { throw $refusal }; 'ok' }
    $result = Invoke-IntegrationBlock { Invoke-PsAiInstallFirst }
    Assert-Equal 'failed' $result.Result 'main moving during fallback installation fails provenance'

    # A moved main branch is a failure, not a different revision under test.
    . Reset-Runner -AllowFallback
    . Install-Fakes
    function Get-IntegrationRevision { return 'abc123' }
    function Get-IntegrationRemoteMain { return 'def456' }
    $script:behavior = { param($call) if ($call.Tool -eq 'codex' -and $call.Source -eq $root) { throw $refusal }; 'ok' }
    $result = Invoke-IntegrationBlock { Invoke-PsAiInstallFirst }
    Assert-Equal 'failed' $result.Result 'a fallback for another revision fails'

    # When every tool refuses without a fallback, the step is skipped.
    . Reset-Runner
    . Install-Fakes
    $script:behavior = { param($call) throw "install.ps1 exited 1`n$($call.Tool) exited 1`nlocal folder marketplace is not supported" }
    $result = Invoke-IntegrationBlock { Invoke-PsAiInstallFirst }
    Assert-Equal 'skipped' $result.Result 'all tools refusing skips the step'

    # Another tool's refusal text does not excuse this tool.
    . Reset-Runner
    Assert-True (-not (Test-IntegrationLocalRefusal 'claude' $refusal)) 'a refusal by codex is not a claude refusal'
    Assert-True (Test-IntegrationLocalRefusal 'codex' $refusal) 'a codex refusal is identified'
    Assert-True (-not (Test-IntegrationLocalRefusal 'codex' "install.ps1 exited 1`ncodex exited 1`nconnection reset")) 'an unrelated failure is not a refusal'

    # Setup repeats for explicit ids and never asks for new accounts; both runs use the same arguments.
    . Reset-Runner
    foreach ($tool in 'claude', 'codex', 'copilot') { $script:Ctx.Targets[$tool] = @{ Source = $root; SourceRef = '' } }
    function Invoke-IntegrationScript { param($Script, $Arguments = @()) $script:calls += , @($Arguments | ForEach-Object { $_ }); return @('ok') }
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
    function Invoke-IntegrationScript { param($Script, $Arguments = @()) $script:calls += , @($Arguments | ForEach-Object { $_ }); return @('ok') }
    Invoke-RepositoryScript 'repo' 'Shared' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -like '*-RulesFile AGENTS.md*') 'Shared passes -RulesFile'
    $script:calls = @()
    Invoke-RepositoryScript 'repo' 'Private' | Out-Null
    Assert-True ((@($calls[0]) -join ' ') -notlike '*-RulesFile*') 'Private passes no rules file'
    $repoB = New-IntegrationRepo 'repo-b' -WithRules
    Assert-True (@(git -C $repoB ls-files 'AGENTS.md').Count -eq 1) 'the Shared fixture tracks AGENTS.md'
    $repoA = New-IntegrationRepo 'repo-a'
    Assert-True (@(git -C $repoA ls-files 'AGENTS.md').Count -eq 0) 'the plain fixture has no AGENTS.md'

    # Listing: the catalog's arguments and parser; a disabled entry is not installed.
    . Reset-Runner
    function Invoke-IntegrationCli { param($Tool, $Arguments, $Folder) $script:calls += , @($Arguments | ForEach-Object { $_ }); return @{ ExitCode = 0; Lines = @($script:listing) } }
    $script:listing = '[{"id":"ps-ai@ps-ai-marketplace","enabled":false}]'
    Assert-True (-not (Test-IntegrationPluginListed 'claude' 'folder')) 'a disabled entry is not installed'
    Assert-True (Test-IntegrationPluginListed 'claude' 'folder' -IncludeDisabled) 'a disabled entry is still listed'
    Assert-Equal 'plugin list --json' (@($calls[0]) -join ' ') 'the catalog listing arguments are used'
    $script:listing = '[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]'
    Assert-True (Test-IntegrationPluginListed 'claude' 'folder') 'an enabled entry is installed'
    $script:listing = '[]'
    Assert-True (-not (Test-IntegrationPluginListed 'claude' 'folder' -IncludeDisabled)) 'an empty folder lists nothing'
    Assert-IntegrationControlFolder 'claude'
    $script:listing = '[{"id":"ps-ai@ps-ai-marketplace","enabled":true}]'
    $threw = $false
    try { Assert-IntegrationControlFolder 'claude' } catch { $threw = $true }
    Assert-True $threw 'a control folder that lists ps-ai fails'

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
    $threw = $false
    try { Invoke-UninstallFirst | Out-Null } catch { $threw = $_.Exception.Message -like '*legion*' }
    Assert-True $threw 'an owner command left behind fails the uninstall'
    Remove-Item -LiteralPath $ownerPath
    $launcherPath = @(Get-IntegrationLauncherPaths 'claude1')[0]
    Rename-Item -LiteralPath $launcherPath -NewName 'claude1.hidden'
    $threw = $false
    try { Invoke-UninstallFirst | Out-Null } catch { $threw = $_.Exception.Message -like '*launcher claude1*' }
    Assert-True $threw 'an account launcher removed by the uninstall fails it'
    Rename-Item -LiteralPath "$launcherPath.hidden" -NewName 'claude1'
    $script:stale = 'claude1'
    $threw = $false
    try { Invoke-UninstallFirst | Out-Null } catch { $threw = $_.Exception.Message -like '*claude1*' }
    Assert-True $threw 'a plugin left in an account folder fails the uninstall'
    $script:stale = ''
    $cacheFolder = Join-Path $fakeHome '.claude/plugins/cache/ps-ai-marketplace'
    New-Item -ItemType Directory -Path $cacheFolder -Force | Out-Null
    $threw = $false
    try { Invoke-UninstallFirst | Out-Null } catch { $threw = $_.Exception.Message -like '*cache*' }
    Assert-True $threw 'a cache left behind fails the uninstall'
    Remove-Item -LiteralPath (Join-Path $fakeHome '.claude') -Recurse -Force
    $threw = $false
    try { Invoke-UninstallRepeat | Out-Null } catch { $threw = $true }
    Assert-True $threw 'a repeat that does not say Nothing to uninstall fails'
    $script:uninstallOutput = 'Nothing to uninstall.'
    Invoke-UninstallRepeat | Out-Null
} finally {
    $env:CI = $savedCi
    $env:GITHUB_STEP_SUMMARY = $savedSummary
    if ($null -eq $savedNoColor) { Remove-Item Env:NO_COLOR -ErrorAction SilentlyContinue }
    else { $env:NO_COLOR = $savedNoColor }
    $PSStyle.OutputRendering = $savedRendering
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
