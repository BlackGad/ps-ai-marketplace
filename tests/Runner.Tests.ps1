$tempRoot = Join-Path $env:TEMP ('ps-ai-tests/' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    Copy-Item (Join-Path $PSScriptRoot 'run.ps1') $tempRoot
    Copy-Item (Join-Path $PSScriptRoot 'Assert.ps1') $tempRoot
    '$fixtureLeak = 1; function fixture-leak { }; $passed = 100' | Set-Content (Join-Path $tempRoot 'A.Tests.ps1')
    @'
Assert-True ($null -eq (Get-Variable fixtureLeak -ErrorAction SilentlyContinue)) 'Test variables are isolated'
Assert-True ($null -eq (Get-Command fixture-leak -ErrorAction SilentlyContinue)) 'Test functions are isolated'
'@ | Set-Content (Join-Path $tempRoot 'B.Tests.ps1')
    $output = & pwsh -NoProfile -File (Join-Path $tempRoot 'run.ps1')
    Assert-Equal 0 $LASTEXITCODE 'Isolated runner succeeds'
    Assert-Equal '2 passed, 0 failed' $output[-1] 'Runner counts files without test scope leakage'
    Assert-True ($output -contains 'Test files:') 'Counts are explicitly labeled'
    "Write-Error 'fixture nonterminating failure'" | Set-Content (Join-Path $tempRoot 'C.Tests.ps1')
    $failedOutput = & pwsh -NoProfile -File (Join-Path $tempRoot 'run.ps1') 2>$null
    Assert-Equal 1 $LASTEXITCODE 'Runner fails on unexpected PowerShell errors'
    Assert-Equal '2 passed, 1 failed' $failedOutput[-1] 'Nonterminating errors count as failed files'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
