# Benchmark JSON for github-action-benchmark (customSmallerIsBetter).
function Write-BenchmarkFile {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Entries
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
