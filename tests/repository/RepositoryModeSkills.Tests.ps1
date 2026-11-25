$testBase = Split-Path $PSScriptRoot -Parent
$root = Split-Path $testBase -Parent
$skill = Join-Path $root 'plugins/legion/skills/legion-repository'
$setupText = Get-Content (Join-Path $skill 'references/setup.md') -Raw
Assert-True ($setupText.Contains('legion repository setup --repo <repo> [--mode shared] [--gate')) 'Setup uses the owner command and named options'
Assert-True (-not $setupText.Contains('pwsh -NoProfile -File <plugin>')) 'Setup reaches Python through the owner command'
foreach ($reference in @('references/layout.md', 'references/setup.md')) {
    $text = Get-Content (Join-Path $skill $reference) -Raw
    Assert-True ($text -match '\.legion/\.git` folder or file means Private') "$reference detects both forms of Private history"
    Assert-True ($text.Contains('git ls-files .legion')) "$reference checks tracking before selecting Shared"
    Assert-True ($text -match '(?i)otherwise.*tracked.*Shared|otherwise.*git ls-files \.legion.*tracked.*Shared') "$reference requires tracked files for Shared"
}
foreach ($reference in @('SKILL.md', 'references/layout.md', 'references/setup.md')) {
    $text = Get-Content (Join-Path $skill $reference) -Raw
    Assert-True ($text -match 'If neither.*setup is not finished: ask the owner the setup choice again, with Private as the default, and complete it') "$reference completes an unfinished setup after asking again"
    Assert-True (-not $text.Contains('Otherwise the layout is Shared')) "$reference never guesses Shared from absent history"
}
