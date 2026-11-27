param([string]$Name = '*')

$test = Get-Item -LiteralPath (Join-Path $PSScriptRoot 'repository/Bootstrap.Tests.ps1')
if ($test.Name -notlike $Name) { throw "No test file matches -Name '$Name'" }

. (Join-Path $PSScriptRoot 'lib/paths.ps1')
. (Join-Path $PSScriptRoot 'lib/user-path.ps1')
$userPathBefore = Get-TestUserPathSnapshot
$failed = $false
$catalogPath = Join-Path $PSScriptRoot '../plugins/legion/tools.json'
$configEnvs = @()
if (Test-Path -LiteralPath $catalogPath) {
    $configEnvs = (Get-Content $catalogPath -Raw | ConvertFrom-Json).tools.configEnv
}
$toolConfigEnvs = @($configEnvs)
$configEnvs += @('LEGION_ROLE', 'LEGION_TASK', 'TELEGRAM_STATE_DIR', 'TELEGRAM_BOT_TOKEN', 'HOME', 'USERPROFILE', 'LEGION_TEST_GUARD', 'LEGION_TEST_USER_PATH_FILE', 'TMPDIR', 'TEMP', 'TMP')
function Get-TestOutsideSnapshot {
    param([string]$Path)
    return @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join '|'
}
$realHome = $HOME
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
# A stand-in first on PATH rejects every uv call.
$fakeUvFolder = Join-Path $guard 'fake-uv'
New-Item -ItemType Directory -Path $fakeUvFolder -Force | Out-Null
if ($IsWindows) {
    [IO.File]::WriteAllText((Join-Path $fakeUvFolder 'uv.cmd'), (@(
        '@>&2 echo fake uv: unexpected call: uv %*'
        '@exit /b 2'
    ) -join "`r`n") + "`r`n")
} else {
    [IO.File]::WriteAllText((Join-Path $fakeUvFolder 'uv'), (@(
        '#!/bin/sh'
        'echo "fake uv: unexpected call: uv $*" >&2'
        'exit 2'
    ) -join "`n") + "`n")
    [IO.File]::SetUnixFileMode((Join-Path $fakeUvFolder 'uv'), [IO.UnixFileMode]'UserRead, UserWrite, UserExecute')
}
$savedPath = $env:PATH
$env:PATH = $fakeUvFolder + [IO.Path]::PathSeparator + $env:PATH
try {
    & {
        $ErrorActionPreference = 'Stop'
        . (Join-Path $PSScriptRoot 'Assert.ps1')
        & $test.FullName
    }
} catch {
    Write-Output "FAIL $($test.Name): $($_.Exception.Message)"
    $failed = $true
} finally {
    try { Assert-TestUserPathUnchanged -Before $userPathBefore }
    catch {
        $failed = $true
        Write-Output "FAIL $($test.Name): $($_.Exception.Message)"
    }
    if ((Get-TestOutsideSnapshot $outside) -cne $outsideSnapshot) {
        $failed = $true
        Write-Output "FAIL $($test.Name): Test changed the fake real folder"
    }
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
Write-Output 'Test files:'
if ($failed) {
    Write-Output '0 passed, 1 failed'
    exit 1
}
Write-Output "PASS $($test.Name)"
Write-Output '1 passed, 0 failed'
