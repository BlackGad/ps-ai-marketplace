param([string]$JUnitPath, [string]$Name = '*')

. (Join-Path $PSScriptRoot 'lib/junit.ps1')
. (Join-Path $PSScriptRoot 'lib/paths.ps1')
. (Join-Path $PSScriptRoot 'lib/user-path.ps1')
$userPathBefore = Get-TestUserPathSnapshot
$failed = 0
$passed = 0
$cases = @()
$catalogPath = Join-Path $PSScriptRoot '../plugins/legion/tools.json'
$configEnvs = @()
if (Test-Path -LiteralPath $catalogPath) {
    $configEnvs = (Get-Content $catalogPath -Raw | ConvertFrom-Json).tools.configEnv
}
$toolConfigEnvs = @($configEnvs)
$configEnvs += @('LEGION_TEST_UV_SYNC', 'LEGION_ROLE', 'LEGION_TASK', 'TELEGRAM_STATE_DIR', 'TELEGRAM_BOT_TOKEN', 'HOME', 'USERPROFILE', 'LEGION_TEST_GUARD', 'LEGION_TEST_USER_PATH_FILE', 'TMPDIR', 'TEMP', 'TMP')
function Get-TestOutsideSnapshot {
    param([string]$Path)
    return @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join '|'
}
$testFiles = @(Get-ChildItem $PSScriptRoot -Filter '*.Tests.ps1' -Recurse | Where-Object Name -Like $Name | Sort-Object Name)
if (-not $testFiles.Count) { throw "No test file matches -Name '$Name'" }
$realHome = $HOME
foreach ($test in $testFiles) {
    # Tests select fixture homes and modes; inherited overrides must not affect them.
    $savedConfig = @{}
    foreach ($configEnv in $configEnvs) {
        $savedConfig[$configEnv] = [Environment]::GetEnvironmentVariable($configEnv, 'Process')
        Remove-Item -LiteralPath "Env:$configEnv" -ErrorAction SilentlyContinue
    }
    $guard = Join-Path $PSScriptRoot ('../.agents/temp/test-home-' + [guid]::NewGuid().ToString('N'))
    $guardLink = Join-Path $guard 'linked'
    $guardHome = Join-Path $guardLink 'home'
    $physical = Join-Path $guard 'physical'
    $outside = Join-Path $guard 'fake-real'
    New-Item -ItemType Directory -Path (Join-Path $physical 'home'), $outside -Force | Out-Null
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $guardLink -Target (Resolve-LegionDirectoryPath $physical) | Out-Null
    $guardHome = [IO.Path]::GetFullPath($guardHome)
    $temp = Join-Path $guardHome 'temp'
    New-Item -ItemType Directory -Path $temp -Force | Out-Null
    'owner sentinel' | Set-Content (Join-Path $outside 'keep.txt')
    $outsideSnapshot = Get-TestOutsideSnapshot $outside
    $env:HOME = $guardHome
    # Scripts use $HOME as a default home too; it is a PowerShell variable apart from the environment one.
    Set-Variable -Name HOME -Value $guardHome -Force -Scope Global
    $env:USERPROFILE = $guardHome
    $env:LEGION_TEST_GUARD = $guardHome
    $env:LEGION_TEST_USER_PATH_FILE = Join-Path $guardHome 'user-path.txt'
    [IO.File]::WriteAllText($env:LEGION_TEST_USER_PATH_FILE, '')
    foreach ($tempEnv in @('TMPDIR', 'TEMP', 'TMP')) { [Environment]::SetEnvironmentVariable($tempEnv, $temp, 'Process') }
    foreach ($configEnv in $toolConfigEnvs) { [Environment]::SetEnvironmentVariable($configEnv, (Join-Path $guardHome $configEnv), 'Process') }
    # Tests never run the real uv: a stand-in first on PATH rejects every call, except `uv sync` for a
    # test that opts in with LEGION_TEST_UV_SYNC; that sync succeeds and does nothing.
    $fakeUvFolder = Join-Path $guard 'fake-uv'
    New-Item -ItemType Directory -Path $fakeUvFolder -Force | Out-Null
    if ($IsWindows) {
        [IO.File]::WriteAllText((Join-Path $fakeUvFolder 'uv.cmd'), (@(
            '@if "%~1"=="sync" if defined LEGION_TEST_UV_SYNC exit /b 0'
            '@>&2 echo fake uv: unexpected call: uv %*'
            '@exit /b 2'
        ) -join "`r`n") + "`r`n")
    } else {
        [IO.File]::WriteAllText((Join-Path $fakeUvFolder 'uv'), (@(
            '#!/bin/sh'
            'if [ "$1" = sync ] && [ -n "$LEGION_TEST_UV_SYNC" ]; then exit 0; fi'
            'echo "fake uv: unexpected call: uv $*" >&2'
            'exit 2'
        ) -join "`n") + "`n")
        [IO.File]::SetUnixFileMode((Join-Path $fakeUvFolder 'uv'), [IO.UnixFileMode]'UserRead, UserWrite, UserExecute')
    }
    $savedPath = $env:PATH
    $env:PATH = $fakeUvFolder + [IO.Path]::PathSeparator + $env:PATH
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $result = 'passed'
    $message = ''
    try {
        & {
            $ErrorActionPreference = 'Stop'
            . (Join-Path $PSScriptRoot 'Assert.ps1')
            & $test.FullName
        }
        Write-Output "PASS $($test.Name)"
        $passed++
    } catch {
        Write-Output "FAIL $($test.Name): $($_.Exception.Message)"
        $failed++
        $result = 'failed'
        $message = $_.Exception.Message
    } finally {
        try { Assert-TestUserPathUnchanged -Before $userPathBefore }
        catch {
            if ($result -eq 'passed') { $passed--; $failed++ }
            $result = 'failed'
            $message = $_.Exception.Message
            Write-Output "FAIL $($test.Name): $message"
        }
        if ((Get-TestOutsideSnapshot $outside) -cne $outsideSnapshot) {
            if ($result -eq 'passed') { $passed--; $failed++ }
            $result = 'failed'
            $message = 'Test changed the fake real folder'
            Write-Output "FAIL $($test.Name): $message"
        }
        $cases += @{ Name = $test.Name; ClassName = 'unit'; Seconds = $watch.Elapsed.TotalSeconds; Result = $result; Message = $message }
        Set-Variable -Name HOME -Value $realHome -Force -Scope Global
        $env:PATH = $savedPath
        foreach ($configEnv in $configEnvs) {
            if ($null -eq $savedConfig[$configEnv]) { Remove-Item -LiteralPath "Env:$configEnv" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($configEnv, $savedConfig[$configEnv], 'Process') }
        }
        $guardPath = [IO.Path]::GetFullPath($guard)
        $allowed = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.agents/temp/'))
        if (-not (Test-LegionPathUnder -Path $guardPath -Root $allowed)) { throw 'Unsafe test-home cleanup' }
        # Unlink first: recursive cleanup must never walk through the home link.
        Remove-Item -LiteralPath $guardLink -Force
        Remove-Item -LiteralPath $guardPath -Recurse -Force
    }
}
Write-Output 'Test files:'
Write-Output "$passed passed, $failed failed"
if ($JUnitPath) { Write-JUnitFile -Path $JUnitPath -SuiteName 'unit' -Cases $cases }
if ($failed) { exit 1 }
