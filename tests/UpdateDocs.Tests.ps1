$repo = Split-Path $PSScriptRoot -Parent
$readme = Get-Content (Join-Path $repo 'README.md') -Raw
Assert-True (-not ($readme -match '--plugin-dir|local path|Local sources|local sources')) 'README promotes GitHub source only'
$skill = Get-Content (Join-Path $repo 'plugins/ps-ai/skills/ps-ai-overseer/SKILL.md') -Raw
Assert-True ($skill.Contains('check ps-ai updates') -and $skill.Contains('update ps-ai')) 'Overseer routes both update phrases'
Assert-True ($skill.Contains('ps-ai-update.ps1 -Check -Force')) 'Overseer forces explicit check'
Assert-True ($skill -match "owner.s yes" -and $skill -match 'restart.*session' -and $skill.Contains('resume')) 'Update requires yes then restart or resume'
$codexPlugins = Get-Content (Join-Path $repo 'plugins/ps-ai/skills/ps-ai-codex/references/plugins.md') -Raw
Assert-True ($codexPlugins -match 'After updating ps-ai.*resume the session') 'Selected tool owns Codex resume guidance'
