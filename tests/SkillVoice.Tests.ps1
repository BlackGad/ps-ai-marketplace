$repo = Split-Path $PSScriptRoot -Parent
$skills = Join-Path $repo 'plugins/ps-ai/skills'
foreach ($file in Get-ChildItem $skills -Filter SKILL.md -File -Recurse) {
    $content = Get-Content $file.FullName -Raw
    Assert-True ($content -notmatch '(?i)\b(pwsh|irm) ') "$($file.Directory.Name) keeps command lines in references"
}
