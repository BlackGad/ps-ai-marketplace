$repo = Split-Path $PSScriptRoot -Parent
$skills = Join-Path $repo 'plugins/ps-ai/skills'

foreach ($folder in Get-ChildItem -LiteralPath $skills -Directory) {
    Assert-True ($folder.Name.StartsWith('legion-')) "Skill folder $($folder.Name) starts with legion-"
    Assert-True ($folder.Name -cmatch '^[a-z][a-z0-9]*(-[a-z0-9]+)*$' -and $folder.Name.Length -le 64) "Skill folder $($folder.Name) is a valid skill name"
    $skillFile = Join-Path $folder.FullName 'SKILL.md'
    $name = [regex]::Match((Get-Content -LiteralPath $skillFile -Raw), '(?m)^name:\s*(\S+)\s*$').Groups[1].Value
    Assert-Equal $folder.Name $name "Skill $($folder.Name) name matches its folder"
}

# Old names are built from pieces so this file does not mention them. Owner file names such as
# ps-ai-personalisation.json are not skill names and are renamed separately.
$oldSkills = 'claude', 'codex', 'copilot', 'knowledge', 'legion', 'overseer', 'personalisation', 'repository', 'telegram', 'update'
$oldPattern = ('ps-ai-(' + ($oldSkills -join '|') + ')(?!\.json)') + '|' + 'bin/ps-ai-'
$leftovers = @()
foreach ($file in (& git -C $repo ls-files)) {
    if ($file -eq 'CHANGELOG.md' -or $file -eq 'tests/SkillNames.Tests.ps1') { continue }
    $path = Join-Path $repo $file
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
    $bytes = [IO.File]::ReadAllBytes($path)
    if ($bytes -contains 0) { continue }
    $text = [Text.Encoding]::UTF8.GetString($bytes)
    $lines = $text -split "`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        # The retired owner commands keep their names until they are removed.
        if ($lines[$i] -match 'ps-ai-(setup|status)') { continue }
        if ($lines[$i] -match $oldPattern) { $leftovers += "${file}:$($i + 1)" }
    }
}
Assert-Equal @() $leftovers "No old skill or script names remain: $($leftovers -join ', ')"
