# Benchmark JSON for github-action-benchmark (customSmallerIsBetter).
# A case is an object with Name, Seconds, Result (passed|failed|skipped) and Repeat (bool).

function New-BenchmarkEntries {
    param(
        [Parameter(Mandatory)][string]$Os,
        [Parameter(Mandatory)][object[]]$Cases,
        [string]$Extra
    )
    foreach ($case in $Cases) {
        # A failed or skipped step is left out so a broken run never looks fast.
        if ($case.Result -ne 'passed') { continue }
        $name = "$Os / $($case.Name)"
        if ($case.Repeat) { $name += ' (repeat)' }
        $entry = [ordered]@{ name = $name; unit = 's'; value = [double]$case.Seconds }
        if ($Extra -and -not $case.Repeat) { $entry.extra = $Extra }
        [pscustomobject]$entry
    }
}

function Write-BenchmarkFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object[]]$Entries
    )
    # -InputObject @(...) keeps a one-item array an array; ConvertTo-Json always writes a `.` decimal.
    $json = ConvertTo-Json -InputObject @($Entries) -Depth 5
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8
}

function Merge-BenchmarkFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Path,
        [Parameter(Mandatory)][string]$OutFile
    )
    $entries = @()
    foreach ($file in $Path) {
        if (-not (Test-Path -LiteralPath $file)) {
            Write-Warning "benchmark file not found, skipped: $file"
            continue
        }
        $entries += @(ConvertFrom-Json (Get-Content -LiteralPath $file -Raw))
    }
    Write-BenchmarkFile -Path $OutFile -Entries $entries
}
