# Stops a test file that was run directly: it could reach the real home. The first line of every shared test library.
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
