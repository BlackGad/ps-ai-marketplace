$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$oldIdentifier = 'Ps' + 'Ai'
$oldTestVariable = 'PS' + '_AI_(?:FAKE_[A-Z0-9_]*|WRAPPER_[A-Z0-9_]*|STATUS_BIN|CONSENT_LOG|PRIVACY_LOG|INSTALL_TEST_ROOT|TEST_LEASE_[A-Z0-9_]*)\b'
$files = @(git -C $repoRoot ls-files -- '*.ps1' '*.psm1' '*.json')
if ($LASTEXITCODE -ne 0) { throw 'Could not list tracked scripts and JSON files' }
if ($files.Count -eq 0) { throw 'No tracked scripts or JSON files found' }

$violations = @(
    foreach ($file in $files) {
        if ($file -eq 'CHANGELOG.md') { continue }
        $text = [IO.File]::ReadAllText((Join-Path $repoRoot $file))
        if ($text.Contains($oldIdentifier) -or $text -cmatch $oldTestVariable) { $file }
    }
)
if ($violations.Count) {
    throw "Legacy internal names remain in $($violations.Count) tracked files: $($violations -join ', ')"
}
