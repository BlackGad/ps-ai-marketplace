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

$esc = [char]0x1B
$emoji = [char]::ConvertFromUtf32(0x1F680)
$invalid = -join @([char]0, [char]1, [char]0x0B, [char]0x0C, [char]0x1F, [char]0xFFFE, [char]0xFFFF, [char]0xDC00, [char]0xD800)
# Include both colour codes and an OSC hyperlink, with BEL and ST terminators.
$dirty = "${esc}7${esc}[31mred${esc}[0m${esc}]8;;https://example.test$([char]7)link${esc}]8;;${esc}\${esc}8${esc}(B & `"quoted`" $emoji$invalid`r`nnext"
$expected = "redlink & `"quoted`" $emoji`r`nnext"
$sanitizedText = ConvertTo-JUnitXml -SuiteName $dirty -Cases @(
    @{ Name=$dirty; ClassName=$dirty; Seconds=0; Result='failed'; Message=$dirty },
    @{ Name='skip'; ClassName='unit'; Seconds=0; Result='skipped'; Message=$dirty }
)
Assert-True (-not $sanitizedText.Contains([string]$esc)) 'JUnit drops raw ANSI escapes'
$sanitized = [xml]$sanitizedText
Assert-Equal $expected $sanitized.testsuite.name 'suite strips ANSI and invalid XML characters, preserving Unicode and newlines'
Assert-Equal $expected $sanitized.testsuite.testcase[0].name 'case name is sanitized'
Assert-Equal $expected $sanitized.testsuite.testcase[0].classname 'class name is sanitized'
Assert-Equal $expected $sanitized.testsuite.testcase[0].failure.message 'failure message is sanitized'
Assert-Equal $expected $sanitized.testsuite.testcase[1].skipped.message 'skip message is sanitized'

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
