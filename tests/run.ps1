$failed = 0
$passed = 0
$catalogPath = Join-Path $PSScriptRoot '../tools.json'
$configEnvs = @()
if (Test-Path -LiteralPath $catalogPath) {
    $configEnvs = (Get-Content $catalogPath -Raw | ConvertFrom-Json).tools.configEnv
}
foreach ($test in Get-ChildItem $PSScriptRoot -Filter '*.Tests.ps1' | Sort-Object Name) {
    # Tests select fixture homes; inherited CLI overrides must not select real folders.
    $savedConfig = @{}
    foreach ($name in $configEnvs) {
        $savedConfig[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
        Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue
    }
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
    } finally {
        foreach ($name in $configEnvs) {
            if ($null -eq $savedConfig[$name]) { Remove-Item -LiteralPath "Env:$name" -ErrorAction SilentlyContinue }
            else { [Environment]::SetEnvironmentVariable($name, $savedConfig[$name], 'Process') }
        }
    }
}
Write-Output 'Test files:'
Write-Output "$passed passed, $failed failed"
if ($failed) { exit 1 }
