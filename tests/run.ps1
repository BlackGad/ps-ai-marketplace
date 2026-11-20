param([string]$JUnitPath)

. (Join-Path $PSScriptRoot 'lib/junit.ps1')
$failed = 0
$passed = 0
$cases = @()
$catalogPath = Join-Path $PSScriptRoot '../tools.json'
$configEnvs = @()
if (Test-Path -LiteralPath $catalogPath) {
    $configEnvs = (Get-Content $catalogPath -Raw | ConvertFrom-Json).tools.configEnv
}
$configEnvs += @('PS_AI_ROLE', 'PS_AI_TASK')
foreach ($test in Get-ChildItem $PSScriptRoot -Filter '*.Tests.ps1' | Sort-Object Name) {
    # Tests select fixture homes and modes; inherited overrides must not affect them.
    $savedConfig = @{}
    foreach ($name in $configEnvs) {
        $savedConfig[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
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
        $cases += @{ Name = $test.Name; ClassName = 'unit'; Seconds = $watch.Elapsed.TotalSeconds; Result = $result; Message = $message }
        foreach ($name in $configEnvs) {
            if ($null -eq $savedConfig[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($name, $savedConfig[$name], 'Process') }
        }
    }
}
Write-Output 'Test files:'
Write-Output "$passed passed, $failed failed"
if ($JUnitPath) { Write-JUnitFile -Path $JUnitPath -SuiteName 'unit' -Cases $cases }
if ($failed) { exit 1 }
