$testHomeIsGuarded = $false
if ($env:LEGION_TEST_GUARD -and $env:HOME -and
    [IO.Path]::IsPathFullyQualified($env:LEGION_TEST_GUARD) -and [IO.Path]::IsPathFullyQualified($env:HOME)) {
    $assertGuard = [IO.Path]::GetFullPath($env:LEGION_TEST_GUARD).TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
    $assertHome = [IO.Path]::GetFullPath($env:HOME).TrimEnd([char[]]'\/') + [IO.Path]::DirectorySeparatorChar
    $comparison = if ($IsWindows) { [StringComparison]::OrdinalIgnoreCase } else { [StringComparison]::Ordinal }
    $testHomeIsGuarded = $assertHome.StartsWith($assertGuard, $comparison)
}
if (-not $testHomeIsGuarded) {
    throw 'Run tests through tests/run.ps1 (-Name <file> for one file); a direct run can reach the real home.'
}

function Assert-Equal {
    param($Expected, $Actual, [string]$Message)
    if ($Expected -cne $Actual) { throw "$Message`: expected '$Expected', got '$Actual'" }
}

function Assert-True {
    param($Condition, [string]$Message)
    if (-not $Condition) { throw "$Message`: expected true" }
}

function Assert-Throws {
    param([scriptblock]$Action, [string]$Message)
    try { & $Action } catch { return }
    throw "$Message`: expected exception"
}
