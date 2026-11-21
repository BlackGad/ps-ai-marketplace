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
    '$fixtureLeak = 1; function fixture-leak { }; $passed = 100' | Set-Content (Join-Path $testRoot 'A.Tests.ps1')
    @'
Assert-True ($null -eq (Get-Variable fixtureLeak -ErrorAction SilentlyContinue)) 'Test variables are isolated'
Assert-True ($null -eq (Get-Command fixture-leak -ErrorAction SilentlyContinue)) 'Test functions are isolated'
'@ | Set-Content (Join-Path $testRoot 'B.Tests.ps1')
    $output = & pwsh -NoProfile -File (Join-Path $testRoot 'run.ps1')
    Assert-Equal 0 $LASTEXITCODE 'Isolated runner succeeds'
    Assert-Equal '2 passed, 0 failed' $output[-1] 'Runner counts files without test scope leakage'
    Assert-True ($output -contains 'Test files:') 'Counts are explicitly labeled'
    "Write-Error 'fixture nonterminating failure'" | Set-Content (Join-Path $testRoot 'C.Tests.ps1')
    $failedOutput = & pwsh -NoProfile -File (Join-Path $testRoot 'run.ps1') 2>$null
    Assert-Equal 1 $LASTEXITCODE 'Runner fails on unexpected PowerShell errors'
    Assert-Equal '2 passed, 1 failed' $failedOutput[-1] 'Nonterminating errors count as failed files'
    Remove-Item -LiteralPath (Join-Path $testRoot 'C.Tests.ps1')

    # Run through a linked ancestor, like macOS /var -> /private/var.
    $catalogFolder = Join-Path $fixtureRepo 'plugins/legion'
    New-Item -ItemType Directory -Path $catalogFolder -Force | Out-Null
    Copy-Item (Join-Path $repo 'plugins/legion/tools.json') $catalogFolder
    Copy-Item (Join-Path $repo 'plugins/legion/bin/lib/paths.ps1') (Join-Path $testRoot 'lib/owner-paths.ps1')
    @'
. (Join-Path $PSScriptRoot 'lib/owner-paths.ps1')
$catalog = Get-Content (Join-Path $PSScriptRoot '../plugins/legion/tools.json') -Raw | ConvertFrom-Json
Assert-Equal $env:HOME $env:USERPROFILE 'Both profile variables use the same home'
foreach ($name in @('HOME', 'USERPROFILE') + @($catalog.tools.configEnv)) {
    $folder = [Environment]::GetEnvironmentVariable($name, 'Process')
    Assert-True ([IO.Path]::IsPathFullyQualified($folder)) "$name is absolute"
    Assert-True (Test-LegionOwnerPathSafe $folder) "$name has no linked ancestors"
    if ($name -in $catalog.tools.configEnv) {
        Assert-True ($folder.StartsWith($env:HOME + [IO.Path]::DirectorySeparatorChar)) "$name stays inside the fenced home"
    }
}
'@ | Set-Content (Join-Path $testRoot 'D.Tests.ps1')
    $linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
    New-Item -ItemType $linkType -Path $linkedRoot -Target $fixtureRepo | Out-Null
    $linkedOutput = & pwsh -NoProfile -File (Join-Path $linkedRoot 'tests/run.ps1')
    Assert-Equal 0 $LASTEXITCODE 'Runner succeeds through a linked ancestor'
    Assert-Equal '3 passed, 0 failed' $linkedOutput[-1] 'Every fenced home and tool folder is link-free'
} finally {
    $allowed = [IO.Path]::GetFullPath((Join-Path $repo '.agents/temp/'))
    if (-not [IO.Path]::GetFullPath($tempRoot).StartsWith($allowed)) { throw 'Unsafe runner fixture cleanup' }
    if (Test-Path -LiteralPath $linkedRoot) { Remove-Item -LiteralPath $linkedRoot -Force }
    Remove-Item -LiteralPath $tempRoot -Recurse -Force
}
