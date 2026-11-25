$repo = Split-Path $PSScriptRoot -Parent
$tempRoot = Join-Path $repo ('.agents/temp/runner-' + [guid]::NewGuid())
$fixtureRepo = Join-Path $tempRoot 'real'
$testRoot = Join-Path $fixtureRepo 'tests'
$linkedRoot = Join-Path $tempRoot 'linked'
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
try {
    Copy-Item (Join-Path $PSScriptRoot 'run.ps1') $testRoot
    Copy-Item (Join-Path $PSScriptRoot 'Assert.ps1') $testRoot
    Copy-Item (Join-Path $PSScriptRoot 'lib') $testRoot -Recurse
    $fakeReal = Join-Path $tempRoot 'fake-real'
    $childEnvironment = @{
        HOME = Join-Path $tempRoot 'home'; USERPROFILE = Join-Path $tempRoot 'home'
        CLAUDE_CONFIG_DIR = Join-Path $fakeReal 'claude'
        CODEX_HOME = Join-Path $fakeReal 'codex'; COPILOT_HOME = Join-Path $fakeReal 'copilot'
    }
    New-Item -ItemType Directory -Path @($childEnvironment.Values) -Force | Out-Null
    function Invoke-RunnerChild {
        param([string[]]$Arguments, [string]$Guard)
        $start = [Diagnostics.ProcessStartInfo]::new('pwsh')
        $start.UseShellExecute = $false
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        foreach ($argument in @('-NoProfile') + $Arguments) { $start.ArgumentList.Add($argument) }
        foreach ($key in $childEnvironment.Keys) { $start.Environment[$key] = $childEnvironment[$key] }
        $null = $start.Environment.Remove('LEGION_TEST_GUARD')
        if ($Guard) { $start.Environment['LEGION_TEST_GUARD'] = $Guard }
        $process = [Diagnostics.Process]::Start($start)
        try {
            $stdout = $process.StandardOutput.ReadToEndAsync()
            $stderr = $process.StandardError.ReadToEndAsync()
            $process.WaitForExit()
            return @{ ExitCode = $process.ExitCode; Output = $stdout.Result.TrimEnd() -split '\r?\n'; Error = $stderr.Result }
        } finally { $process.Dispose() }
    }
    $loadAssert = "try { . '" + (Join-Path $testRoot 'Assert.ps1').Replace("'", "''") + "' } catch { [Console]::Error.WriteLine(`$_.Exception.Message); exit 1 }"
    $guardMessage = 'Run tests through tests/run.ps1 (-Name <file> for one file); a direct run can reach the real home.'
    foreach ($guard in @('', (Join-Path $tempRoot 'other'), (Join-Path $tempRoot 'hom'))) {
        $direct = Invoke-RunnerChild -Arguments @('-Command', $loadAssert) -Guard $guard
        Assert-True ($direct.ExitCode -ne 0) 'Assert rejects a missing guard or HOME outside it (including a shared prefix)'
        Assert-True ($direct.Error.Contains($guardMessage)) 'Direct run explains the safe runner command'
    }
    # A direct run of a real test file stops at the guard, before any fixture setup.
    $directHome = Join-Path $tempRoot 'direct-home'
    New-Item -ItemType Directory -Path $directHome | Out-Null
    $childEnvironment.HOME = $directHome
    $childEnvironment.USERPROFILE = $directHome
    foreach ($name in @('Bootstrap', 'TestFixtures')) {
        $realTest = Join-Path $repo "tests/$name.Tests.ps1"
        $runTest = "try { & '" + $realTest.Replace("'", "''") + "' } catch { [Console]::Error.WriteLine(`$_.Exception.Message); exit 1 }"
        $directRun = Invoke-RunnerChild -Arguments @('-Command', $runTest)
        Assert-True ($directRun.ExitCode -ne 0) "A direct run of $name fails"
        Assert-True ($directRun.Error.Contains($guardMessage)) "A direct run of $name explains the safe runner command"
    }
    Assert-Equal 0 @(Get-ChildItem -LiteralPath $directHome -Force | Where-Object Name -Like '*account').Count 'A direct run creates no fixture folders under HOME'
    $childEnvironment.HOME = Join-Path $tempRoot 'home'
    $childEnvironment.USERPROFILE = Join-Path $tempRoot 'home'

    $nothing = Invoke-RunnerChild -Arguments @('-File', (Join-Path $testRoot 'run.ps1'), '-Name', 'NoSuchFile*')
    Assert-True ($nothing.ExitCode -ne 0) 'A -Name that matches nothing fails'
    Assert-True ($nothing.Error.Contains('NoSuchFile*')) 'The failure names the pattern'
    '$fixtureLeak = 1; function fixture-leak { }; $passed = 100' | Set-Content (Join-Path $testRoot 'A.Tests.ps1')
    @'
Assert-True ($null -eq (Get-Variable fixtureLeak -ErrorAction SilentlyContinue)) 'Test variables are isolated'
Assert-True ($null -eq (Get-Command fixture-leak -ErrorAction SilentlyContinue)) 'Test functions are isolated'
'@ | Set-Content (Join-Path $testRoot 'B.Tests.ps1')
    $output = & pwsh -NoProfile -File (Join-Path $testRoot 'run.ps1')
    Assert-Equal 0 $LASTEXITCODE 'Isolated runner succeeds'
    Assert-Equal '2 passed, 0 failed' $output[-1] 'Runner counts files without test scope leakage'
    Assert-True ($output -contains 'Test files:') 'Counts are explicitly labeled'
    $single = Invoke-RunnerChild -Arguments @('-File', (Join-Path $testRoot 'run.ps1'), '-Name', 'B*')
    Assert-Equal 0 $single.ExitCode 'Filtered runner succeeds under the guard'
    Assert-Equal '1 passed, 0 failed' $single.Output[-1] 'Wildcard selects one test file'
    Assert-True ($single.Output -contains 'PASS B.Tests.ps1') 'The matching file ran'
    Assert-True ($single.Output -notcontains 'PASS A.Tests.ps1') 'The other file did not run'
    "Write-Error 'fixture nonterminating failure'" | Set-Content (Join-Path $testRoot 'C.Tests.ps1')
    $failedOutput = & pwsh -NoProfile -File (Join-Path $testRoot 'run.ps1') 2>$null
    Assert-Equal 1 $LASTEXITCODE 'Runner fails on unexpected PowerShell errors'
    Assert-Equal '2 passed, 1 failed' $failedOutput[-1] 'Nonterminating errors count as failed files'
    Remove-Item -LiteralPath (Join-Path $testRoot 'C.Tests.ps1')

    # Run through a linked ancestor, like macOS /var -> /private/var.
    $catalogFolder = Join-Path $fixtureRepo 'plugins/legion'
    New-Item -ItemType Directory -Path $catalogFolder -Force | Out-Null
    Copy-Item (Join-Path $repo 'plugins/legion/tools.json') $catalogFolder
    @'
. (Join-Path $PSScriptRoot 'lib/paths.ps1')
$catalog = Get-Content (Join-Path $PSScriptRoot '../plugins/legion/tools.json') -Raw | ConvertFrom-Json
Assert-Equal $env:HOME $env:USERPROFILE 'Both profile variables use the same home'
Assert-Equal $env:HOME $HOME 'The PowerShell HOME variable follows the fenced home'
Assert-True ((Get-Item -LiteralPath (Split-Path $env:HOME) -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) 'The fenced home is reached through a link'
foreach ($name in @('HOME', 'USERPROFILE') + @($catalog.tools.configEnv)) {
    $folder = [Environment]::GetEnvironmentVariable($name, 'Process')
    Assert-True ([IO.Path]::IsPathFullyQualified($folder)) "$name is absolute"
    Assert-True (Test-LegionPathUnder $folder -Root $env:HOME -AllowEqual) "$name stays inside the fenced home"
    if ($name -in $catalog.tools.configEnv) {
        Assert-Equal (Join-Path $env:HOME $name) $folder "$name keeps the linked spelling"
    }
}
foreach ($name in @('TMPDIR', 'TEMP', 'TMP')) {
    Assert-Equal (Join-Path $env:HOME 'temp') ([Environment]::GetEnvironmentVariable($name, 'Process')) "$name stays behind the home link"
}
'@ | Set-Content (Join-Path $testRoot 'D.Tests.ps1')
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $linkedRoot -Target $fixtureRepo | Out-Null
    $linkedOutput = & pwsh -NoProfile -File (Join-Path $linkedRoot 'tests/run.ps1')
    Assert-Equal 0 $LASTEXITCODE 'Runner succeeds through a linked ancestor'
    Assert-Equal '3 passed, 0 failed' $linkedOutput[-1] 'Every fenced home, tool folder and temp folder stays behind a link'
    Assert-Equal 0 @(Get-ChildItem (Join-Path $fixtureRepo '.agents/temp') -Force).Count 'Successful and failed child runs remove their links and physical homes'

    # Inherited account overrides must survive the profile test's applying purge.
    $seeds = @{
        'claude/settings.json' = '{"enabledPlugins":{"legion@ps-legion-marketplace":true,"other@else":true}}'
        'claude/plugins/known_marketplaces.json' = '{"ps-legion-marketplace":{"source":{"source":"github"}},"other":{"keep":1}}'
        'claude/plugins/installed_plugins.json' = '{"version":2,"plugins":{"legion@ps-legion-marketplace":[{"scope":"user"}],"other@else":[{"scope":"user"}]}}'
        'codex/config.toml' = "[plugins.`"legion@ps-legion-marketplace`"]`nenabled = true`n[plugins.`"other@else`"]`nenabled = true`n[marketplaces.ps-legion-marketplace]`nsource = 'example/repo'`n"
        'copilot/config.json' = '{"installedPlugins":[{"name":"legion","marketplace":"ps-legion-marketplace"},{"name":"other","marketplace":"else"}]}'
    }
    foreach ($tool in @('claude', 'codex', 'copilot')) {
        foreach ($marketplace in @('ps-legion-marketplace', ('ps-' + 'ai-marketplace'))) {
            $seeds["$tool/plugins/cache/$marketplace/legion/keep.txt"] = 'cache sentinel'
        }
    }
    foreach ($relative in $seeds.Keys) {
        $path = Join-Path $fakeReal $relative
        New-Item -ItemType Directory -Path (Split-Path $path -Parent) -Force | Out-Null
        [IO.File]::WriteAllText($path, $seeds[$relative])
    }
    function Get-RunnerFixtureSnapshot {
        return @(Get-ChildItem -LiteralPath $fakeReal -Recurse -Force | Sort-Object FullName | ForEach-Object {
            if ($_.PSIsContainer) { $_.FullName } else { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }
        }) -join '|'
    }
    $before = Get-RunnerFixtureSnapshot
    try {
        $profile = Invoke-RunnerChild -Arguments @('-File', (Join-Path $repo 'tests/run.ps1'), '-Name', 'Paths*')
    } finally {
        Assert-True ($before -ceq (Get-RunnerFixtureSnapshot)) 'Inherited fake-real account bytes and directory entries are unchanged'
    }
    Assert-Equal 0 $profile.ExitCode 'Paths regression succeeds with inherited fixture account overrides'
    Assert-Equal '1 passed, 0 failed' $profile.Output[-1] 'Paths regression runs only Paths'
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/'))
    if (-not [IO.Path]::GetFullPath($tempRoot).StartsWith($allowed)) { throw 'Unsafe runner fixture cleanup' }
    if (Test-Path -LiteralPath $linkedRoot) { Remove-Item -LiteralPath $linkedRoot -Force }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
