$failed = 0
$passed = 0
foreach ($test in Get-ChildItem $PSScriptRoot -Filter '*.Tests.ps1' | Sort-Object Name) {
    try {
        & {
            . (Join-Path $PSScriptRoot 'Assert.ps1')
            & $test.FullName
        }
        Write-Output "PASS $($test.Name)"
        $passed++
    } catch {
        Write-Output "FAIL $($test.Name): $($_.Exception.Message)"
        $failed++
    }
}
Write-Output 'Test files:'
Write-Output "$passed passed, $failed failed"
if ($failed) { exit 1 }
