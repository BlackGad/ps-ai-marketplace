$testBase = Split-Path $PSScriptRoot -Parent
$repo = Split-Path $testBase -Parent
$skills = Join-Path $repo 'plugins/legion/skills'

foreach ($folder in Get-ChildItem -LiteralPath $skills -Directory) {
    Assert-True ($folder.Name.StartsWith('legion-')) "Skill folder $($folder.Name) starts with legion-"
    Assert-True ($folder.Name -cmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$' -and $folder.Name.Length -le 64) "Skill folder $($folder.Name) is a valid skill name"
    $skillFile = Join-Path $folder.FullName 'SKILL.md'
    $name = [regex]::Match((Get-Content -LiteralPath $skillFile -Raw), '(?m)^name:\s*(\S+)\s*$').Groups[1].Value
    Assert-Equal $folder.Name $name "Skill $($folder.Name) name matches its folder"
}
