. (Join-Path $PSScriptRoot 'lib/junit.ps1')

$cases = @(
    @{ Name = 'a <b> & "c" ''d'''; ClassName = 'unit'; Seconds = 4.21; Result = 'passed'; Message = '' },
    @{ Name = 'bad'; ClassName = 'unit'; Seconds = 1; Result = 'failed'; Message = 'x < y & "z" ''w''' },
    @{ Name = 'skip'; ClassName = 'unit'; Seconds = 0; Result = 'skipped'; Message = 'needs step' }
)

$text = ConvertTo-JUnitXml -SuiteName 'unit & co' -Cases $cases
$xml = [xml]$text
$suite = $xml.testsuite
Assert-Equal 'unit & co' $suite.name 'suite name'
Assert-Equal '3' $suite.tests 'tests total'
Assert-Equal '1' $suite.failures 'failures total'
Assert-Equal '1' $suite.skipped 'skipped total'
Assert-Equal '5.210' $suite.time 'time total'
$testcases = @($suite.testcase)
Assert-Equal 3 $testcases.Count 'testcase count'
Assert-Equal 'a <b> & "c" ''d''' $testcases[0].name 'name round trip'
Assert-Equal 'unit' $testcases[0].classname 'classname'
Assert-Equal '4.210' $testcases[0].time 'case time'
Assert-Equal 'x < y & "z" ''w''' $testcases[1].failure.message 'failure message'
Assert-Equal 'needs step' $testcases[2].skipped.message 'skipped message'
Assert-True ($null -eq $testcases[0].failure) 'passed case has no failure'

$saved = [Threading.Thread]::CurrentThread.CurrentCulture
try {
    [Threading.Thread]::CurrentThread.CurrentCulture = [Globalization.CultureInfo]::GetCultureInfo('de-DE')
    $german = [xml](ConvertTo-JUnitXml -SuiteName 's' -Cases $cases)
    Assert-Equal '4.210' @($german.testsuite.testcase)[0].time 'time under de-DE'
    Assert-Equal '5.210' $german.testsuite.time 'suite time under de-DE'
} finally {
    [Threading.Thread]::CurrentThread.CurrentCulture = $saved
}

$folder = Join-Path ([IO.Path]::GetTempPath()) "junit-test-$([guid]::NewGuid())"
try {
    $file = Join-Path $folder 'deep/unit.xml'
    Write-JUnitFile -Path $file -SuiteName 'unit' -Cases $cases
    Assert-True (Test-Path -LiteralPath $file) 'file written in a new folder'
    $bytes = [IO.File]::ReadAllBytes($file)
    Assert-True ($bytes[0] -ne 0xEF) 'no BOM'
    Assert-Equal '3' ([xml](Get-Content -Raw $file)).testsuite.tests 'file loads'
} finally {
    Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue
}
