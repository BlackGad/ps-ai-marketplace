param([string]$JUnitPath)

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
$configEnvs += @('LEGION_ROLE', 'LEGION_TASK', 'HOME', 'USERPROFILE')
function Get-TestOutsideSnapshot {
    param([string]$Path)
    return @(Get-ChildItem -LiteralPath $Path -File -Recurse -Force | Sort-Object FullName | ForEach-Object { $_.FullName + ':' + (Get-FileHash -LiteralPath $_.FullName).Hash }) -join '|'
}
foreach ($test in Get-ChildItem $PSScriptRoot -Filter '*.Tests.ps1' | Sort-Object Name) {
    # Tests select fixture homes and modes; inherited overrides must not affect them.
    $savedConfig = @{}
    foreach ($name in $configEnvs) {
        $savedConfig[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
    $guard = Join-Path $PSScriptRoot ('../.agents/temp/test-home-' + [guid]::NewGuid().ToString('N'))
    $guardHome = Join-Path $guard 'home'
    $outside = Join-Path $guard 'fake-real'
    New-Item -ItemType Directory -Path $guardHome, $outside -Force | Out-Null
    $guardHome = Resolve-TestDirectory $guardHome
    'owner sentinel' | Set-Content (Join-Path $outside 'keep.txt')
    $outsideSnapshot = Get-TestOutsideSnapshot $outside
    $env:HOME = $guardHome
    $env:USERPROFILE = $guardHome
    foreach ($name in $toolConfigEnvs) { [Environment]::SetEnvironmentVariable($name, (Join-Path $guardHome $name), 'Process') }
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
        foreach ($name in $configEnvs) {
            if ($null -eq $savedConfig[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($name, $savedConfig[$name], 'Process') }
        }
        $guardPath = [IO.Path]::GetFullPath($guard)
        $allowed = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../.agents/temp/'))
        if (-not $guardPath.StartsWith($allowed)) { throw 'Unsafe test-home cleanup' }
        Remove-Item -LiteralPath $guardPath -Recurse -Force
    }
}
Write-Output 'Test files:'
Write-Output "$passed passed, $failed failed"
if ($JUnitPath) { Write-JUnitFile -Path $JUnitPath -SuiteName 'unit' -Cases $cases }
if ($failed) { exit 1 }
