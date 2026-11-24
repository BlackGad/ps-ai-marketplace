$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$pattern = '(?i)ps' + '-ai|ps' + '_ai|ps' + 'ai'
$files = @(git -C $repoRoot ls-files)
if ($LASTEXITCODE -ne 0 -or -not $files.Count) { throw 'Could not list tracked files' }
$violations = @(
    foreach ($file in $files) {
        if ($file -eq 'CHANGELOG.md' -or -not (Test-Path -LiteralPath (Join-Path $repoRoot $file) -PathType Leaf)) { continue }
        $text = [IO.File]::ReadAllText((Join-Path $repoRoot $file))
        if ($text -match $pattern -or $file -match $pattern) { $file }
    }
)
if ($violations.Count) { throw "Legacy names remain in $($violations.Count) tracked files: $($violations -join ', ')" }

$powerShellFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'plugins/legion/bin') -Filter '*.ps1' -Recurse -File)
$legacyValidation = @($powerShellFiles | Where-Object { [IO.File]::ReadAllText($_.FullName) -match 'Invoke-LegionValidation' })
Assert-Equal 0 $legacyValidation.Count 'PowerShell no longer calls the retired validator'
$skillFiles = @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'plugins/legion/skills') -Filter '*.md' -Recurse -File)
$sourcedLibraries = @($skillFiles | Where-Object { [IO.File]::ReadAllText($_.FullName) -match '(?m)^\s*\.\s+.*bin/lib/.*\.ps1' })
Assert-Equal 0 $sourcedLibraries.Count 'Skills use the owner command instead of dot sourcing a library'
foreach ($retired in 'legion-repository.ps1', 'legion-channel.ps1', 'legion-account.ps1', 'legion-foundry.ps1', 'legion-app.ps1', 'legion-validate.ps1') {
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $repoRoot "plugins/legion/bin/$retired"))) "$retired stays retired"
}
