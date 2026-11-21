$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$pattern = '(?i)ps' + '-ai|ps' + '_ai|ps' + 'ai'
$files = @(git -C $repoRoot ls-files)
if ($LASTEXITCODE -ne 0 -or -not $files.Count) { throw 'Could not list tracked files' }
$violations = @(
    foreach ($file in $files) {
        if ($file -eq 'CHANGELOG.md' -or -not (Test-Path -LiteralPath (Join-Path $repoRoot $file) -PathType Leaf)) { continue }
        $text = [IO.File]::ReadAllText((Join-Path $repoRoot $file))
        $text = $text.Replace(('BlackGad/ps' + '-ai-marketplace'), 'repository-address')
        if ($text -match $pattern -or $file -match $pattern) { $file }
    }
)
if ($violations.Count) { throw "Legacy names remain in $($violations.Count) tracked files: $($violations -join ', ')" }
