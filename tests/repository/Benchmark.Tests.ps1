$testBase = Split-Path $PSScriptRoot -Parent
$ErrorActionPreference = 'Stop'
$root = Split-Path $testBase -Parent
. (Join-Path $testBase 'lib/benchmark.ps1')
$tempRoot = Join-Path $root ('.agents/temp/benchmark-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $entries = @(
        [pscustomobject]@{ name = 'windows / setup'; unit = 's'; value = 4.21; extra = 'tool versions' }
        [pscustomobject]@{ name = 'windows / setup (repeat)'; unit = 's'; value = 0.62 }
    )

    # One entry still writes a JSON array.
    $single = Join-Path $tempRoot 'single.json'
    Write-BenchmarkFile -Path $single -Entries @($entries[1])
    $text = (Get-Content -LiteralPath $single -Raw).TrimStart()
    Assert-True ($text.StartsWith('[')) 'single entry is a JSON array'
    $loaded = ConvertFrom-Json (Get-Content -LiteralPath $single -Raw)
    Assert-Equal 1 @($loaded).Count 'single entry loads as one item'

    # Decimal point under de-DE.
    $savedCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    try {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = [cultureinfo]::GetCultureInfo('de-DE')
        $german = Join-Path $tempRoot 'german.json'
        Write-BenchmarkFile -Path $german -Entries $entries
        $germanText = Get-Content -LiteralPath $german -Raw
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $savedCulture
    }
    Assert-True ($germanText -match '"value":\s*4\.21\b') 'decimal point under de-DE'
    Assert-True ($germanText -notmatch '4,21') 'no decimal comma under de-DE'

    # Merge keeps every entry in path order and skips a missing file with a warning.
    $first = Join-Path $tempRoot 'first.json'
    $second = Join-Path $tempRoot 'second.json'
    Write-BenchmarkFile -Path $first -Entries @($entries[0])
    Write-BenchmarkFile -Path $second -Entries @($entries[1])
    $merged = Join-Path $tempRoot 'merged.json'
    $warnings = @()
    Merge-BenchmarkFiles -Path @($first, (Join-Path $tempRoot 'missing.json'), $second) -OutFile $merged -WarningVariable warnings -WarningAction SilentlyContinue
    Assert-Equal 1 @($warnings).Count 'missing file warns once'
    $mergedItems = ConvertFrom-Json (Get-Content -LiteralPath $merged -Raw)
    Assert-True ($mergedItems -is [array]) 'merged file loads as an array'
    Assert-Equal 2 $mergedItems.Count 'merged entry count'
    Assert-Equal 'windows / setup' $mergedItems[0].name 'merge order first'
    Assert-Equal 'windows / setup (repeat)' $mergedItems[1].name 'merge order second'

    $emptyFile = Join-Path $tempRoot 'empty.json'
    Write-BenchmarkFile -Path $emptyFile -Entries @()
    Assert-Equal '[]' ((Get-Content -LiteralPath $emptyFile -Raw) -replace '\s', '') 'empty entries write an empty array'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
