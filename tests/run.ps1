param([string]$JUnitPath, [string]$Name = '*')

. (Join-Path $PSScriptRoot 'lib/junit.ps1')
. (Join-Path $PSScriptRoot 'lib/paths.ps1')
$failed = 0
$passed = 0
$cases = @()
$catalogPath = Join-Path $PSScriptRoot '../plugins/legion/tools.json'
$configEnvs = @()
if (Test-Path -LiteralPath $catalogPath) {
    $configEnvs = (Get-Content $catalogPath -Raw | ConvertFrom-Json).tools.configEnv
}
$toolConfigEnvs = @($configEnvs)
$configEnvs += @('LEGION_ROLE', 'LEGION_TASK', 'HOME', 'USERPROFILE', 'LEGION_TEST_GUARD', 'TMPDIR', 'TEMP', 'TMP')
function Get-TestOutsideSnapshot {
    param([string]$Path)
    return @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join '|'
}
$testFiles = @(Get-ChildItem $PSScriptRoot -Filter '*.Tests.ps1' | Where-Object Name -Like $Name | Sort-Object Name)
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
    foreach ($tempEnv in @('TMPDIR', 'TEMP', 'TMP')) { [Environment]::SetEnvironmentVariable($tempEnv, $temp, 'Process') }
    foreach ($configEnv in $toolConfigEnvs) { [Environment]::SetEnvironmentVariable($configEnv, (Join-Path $guardHome $configEnv), 'Process') }
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
        if ((Get-TestOutsideSnapshot $outside) -cne $outsideSnapshot) {
            if ($result -eq 'passed') { $passed--; $failed++ }
            $result = 'failed'
            $message = 'Test changed the fake real folder'
            Write-Output "FAIL $($test.Name): $message"
        }
        $cases += @{ Name = $test.Name; ClassName = 'unit'; Seconds = $watch.Elapsed.TotalSeconds; Result = $result; Message = $message }
        Set-Variable -Name HOME -Value $realHome -Force -Scope Global
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
