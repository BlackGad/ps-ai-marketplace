$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
. (Join-Path $PSScriptRoot 'lib/benchmark.ps1')
$tempRoot = Join-Path $root ('.agents/temp/benchmark-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $cases = @(
        [pscustomobject]@{ Name = 'setup'; Seconds = 4.21; Result = 'passed'; Repeat = $false }
        [pscustomobject]@{ Name = 'setup'; Seconds = 0.62; Result = 'passed'; Repeat = $true }
        [pscustomobject]@{ Name = 'add'; Seconds = 3.0; Result = 'failed'; Repeat = $false }
        [pscustomobject]@{ Name = 'add'; Seconds = 0.1; Result = 'skipped'; Repeat = $true }
    )

    # Names, unit, extra on first-run rows only; failed and skipped are left out.
    $entries = @(New-BenchmarkEntries -Os 'windows' -Cases $cases -Extra 'claude 2.1.0, codex 0.170.0')
    Assert-Equal 2 $entries.Count 'failed and skipped cases are left out'
    Assert-Equal 'windows / setup' $entries[0].name 'first-run name'
    Assert-Equal 'windows / setup (repeat)' $entries[1].name 'repeat name'
    Assert-Equal 's' $entries[0].unit 'unit'
    Assert-Equal 4.21 $entries[0].value 'value'
    Assert-Equal 'claude 2.1.0, codex 0.170.0' $entries[0].extra 'extra on first run'
    Assert-True (-not $entries[1].PSObject.Properties['extra']) 'no extra on repeat row'

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
    Write-BenchmarkFile -Path $second -Entries @(New-BenchmarkEntries -Os 'linux' -Cases $cases)
    $merged = Join-Path $tempRoot 'merged.json'
    $warnings = @()
    Merge-BenchmarkFiles -Path @($first, (Join-Path $tempRoot 'missing.json'), $second) -OutFile $merged -WarningVariable warnings -WarningAction SilentlyContinue
    Assert-Equal 1 @($warnings).Count 'missing file warns once'
    $mergedItems = ConvertFrom-Json (Get-Content -LiteralPath $merged -Raw)
    Assert-True ($mergedItems -is [array]) 'merged file loads as an array'
    Assert-Equal 3 $mergedItems.Count 'merged entry count'
    Assert-Equal 'windows / setup' $mergedItems[0].name 'merge order first'
    Assert-Equal 'linux / setup' $mergedItems[1].name 'merge order second'
    Assert-Equal 'linux / setup (repeat)' $mergedItems[2].name 'merge order third'

    # No passed case still gives an empty entry list and an empty JSON array file.
    $none = @(New-BenchmarkEntries -Os 'linux' -Cases @())
    Assert-Equal 0 $none.Count 'an empty case list gives no entries'
    $emptyFile = Join-Path $tempRoot 'empty.json'
    Write-BenchmarkFile -Path $emptyFile -Entries $none
    Assert-Equal '[]' ((Get-Content -LiteralPath $emptyFile -Raw) -replace '\s', '') 'empty entries write an empty array'
} finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
