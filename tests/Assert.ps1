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
