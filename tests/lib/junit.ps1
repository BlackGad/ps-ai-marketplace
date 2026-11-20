function Format-JUnitSeconds {
    param([double]$Seconds)
    $Seconds.ToString('0.000', [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-JUnitXml {
    param([string]$SuiteName, [object[]]$Cases)
    $Cases = @($Cases)
    $failures = @($Cases | Where-Object { $_.Result -eq 'failed' }).Count
    $skipped = @($Cases | Where-Object { $_.Result -eq 'skipped' }).Count
    $total = 0.0
    foreach ($case in $Cases) { $total += [double]$case.Seconds }

    $escape = { param($text) ([Security.SecurityElement]::Escape([string]$text)) -replace "`r", "&#13;" -replace "`n", "&#10;" }
    $lines = @('<?xml version="1.0" encoding="UTF-8"?>')
    $lines += "<testsuite name=""$(& $escape $SuiteName)"" tests=""$($Cases.Count)"" failures=""$failures"" skipped=""$skipped"" time=""$(Format-JUnitSeconds $total)"">"
    foreach ($case in $Cases) {
        $open = "  <testcase classname=""$(& $escape $case.ClassName)"" name=""$(& $escape $case.Name)"" time=""$(Format-JUnitSeconds $case.Seconds)"""
        $message = & $escape $case.Message
        if ($case.Result -eq 'failed') {
            $lines += "$open><failure message=""$message""/></testcase>"
        } elseif ($case.Result -eq 'skipped') {
            $lines += "$open><skipped message=""$message""/></testcase>"
        } else {
            $lines += "$open/>"
        }
    }
    $lines += '</testsuite>'
    $lines -join "`n"
}

function Write-JUnitFile {
    param([string]$Path, [string]$SuiteName, [object[]]$Cases)
    $full = [IO.Path]::GetFullPath($Path, (Get-Location).ProviderPath)
    New-Item -ItemType Directory -Force -Path (Split-Path $full -Parent) | Out-Null
    $utf8NoBom = New-Object Text.UTF8Encoding($false)
    [IO.File]::WriteAllText($full, (ConvertTo-JUnitXml -SuiteName $SuiteName -Cases $Cases) + "`n", $utf8NoBom)
}
