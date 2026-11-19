$repo = Split-Path $PSScriptRoot -Parent
$readme = Get-Content (Join-Path $repo 'README.md') -Raw
Assert-True (-not ($readme -match '--plugin-dir|local path|Local sources|local sources')) 'README promotes GitHub source only'
$overseer = Get-Content (Join-Path $repo 'plugins/ps-ai/skills/ps-ai-overseer/SKILL.md') -Raw
Assert-True ($overseer -notmatch 'Plugin updates|check ps-ai updates|update ps-ai|ps-ai-update') 'Overseer handles orchestration only'
$updateDirectory = Join-Path $repo 'plugins/ps-ai/skills/ps-ai-update'
Assert-True (Test-Path (Join-Path $updateDirectory 'SKILL.md')) 'Updates have their own skill'
$skill = Get-Content (Join-Path $updateDirectory 'SKILL.md') -Raw
Assert-True ($skill -match '(?m)^description: Use when.*updates.*update ps-ai.*newer ps-ai.*never in legion mode') 'Update skill owns owner and session-notice triggers'
Assert-True ($skill -match '(?i)check' -and $skill -match 'installed and available versions') 'Update flow checks and explains both versions'
Assert-True ($skill -match "owner.s yes" -and $skill -match 'restart.*session' -and $skill.Contains('resume')) 'Update requires yes then restart or resume'
Assert-True ($skill.Contains('references/commands.md') -and $skill -notmatch 'ps-ai-update\.ps1|-Check|-Force|scriptblock') 'Update commands stay in reference'
$commands = Get-Content (Join-Path $updateDirectory 'references/commands.md') -Raw
Assert-True ($commands.Contains('ps-ai-update.ps1 -Check -Force')) 'Explicit update check bypasses cache'
Assert-True ($commands.Contains('scriptblock') -and $commands.Contains('install.ps1))) -Update')) 'Update reference retains GitHub script-block command'
$codexPlugins = Get-Content (Join-Path $repo 'plugins/ps-ai/skills/ps-ai-codex/references/plugins.md') -Raw
Assert-True ($codexPlugins -match 'After updating ps-ai.*resume the session') 'Selected tool owns Codex resume guidance'
