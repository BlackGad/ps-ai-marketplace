$root = Split-Path $PSScriptRoot -Parent
$skills = Join-Path $root 'plugins/ps-ai/skills'

function Get-SkillLines {
    param([string]$Relative)
    return @(Get-Content (Join-Path $skills $Relative)).Count
}

function Get-SkillText {
    param([string]$Relative)
    return Get-Content (Join-Path $skills $Relative) -Raw
}

$caps = [ordered]@{
    'ps-ai-personalisation/references/create.md'   = 20
    'ps-ai-claude/references/accounts.md'          = 45
    'ps-ai-codex/references/accounts.md'           = 45
    'ps-ai-copilot/references/accounts.md'         = 45
    'ps-ai-personalisation/references/launcher.md' = 10
    'ps-ai-repository/SKILL.md'                    = 35
    'ps-ai-repository/references/setup.md'         = 20
    'ps-ai-telegram/references/connect.md'         = 10
    'ps-ai-personalisation/SKILL.md'               = 40
}
foreach ($file in $caps.Keys) {
    $lines = Get-SkillLines $file
    Assert-True ($lines -le $caps[$file]) "$file has $lines lines, the cap is $($caps[$file])"
}

# Personalisation SKILL.md loads before every flow, so it is not counted per flow.
$flows = [ordered]@{
    'first setup' = @(90, @('ps-ai-personalisation/references/create.md', 'ps-ai-personalisation/references/fields.md'))
    'add claude account' = @(90, @('ps-ai-personalisation/references/create.md', 'ps-ai-claude/SKILL.md', 'ps-ai-claude/references/accounts.md'))
    'add codex account' = @(90, @('ps-ai-personalisation/references/create.md', 'ps-ai-codex/SKILL.md', 'ps-ai-codex/references/accounts.md'))
    'add copilot account' = @(90, @('ps-ai-personalisation/references/create.md', 'ps-ai-copilot/SKILL.md', 'ps-ai-copilot/references/accounts.md'))
    'remove account' = @(60, @('ps-ai-personalisation/references/create.md'))
    'repository' = @(80, @('ps-ai-repository/SKILL.md', 'ps-ai-repository/references/setup.md'))
    'launch' = @(60, @('ps-ai-personalisation/references/launcher.md'))
    'telegram' = @(90, @('ps-ai-telegram/SKILL.md', 'ps-ai-telegram/references/connect.md', 'ps-ai-telegram/references/install.md'))
    'status' = @(20, @())
}
foreach ($name in $flows.Keys) {
    $total = 0
    foreach ($file in $flows[$name][1]) { $total += Get-SkillLines $file }
    Assert-True ($total -le $flows[$name][0]) "$name flow reads $total lines, the cap is $($flows[$name][0])"
}

$owned = @(
    'ps-ai-personalisation/SKILL.md', 'ps-ai-personalisation/references/create.md',
    'ps-ai-personalisation/references/fields.md', 'ps-ai-personalisation/references/launcher.md',
    'ps-ai-claude/references/accounts.md', 'ps-ai-codex/references/accounts.md', 'ps-ai-copilot/references/accounts.md',
    'ps-ai-claude/SKILL.md', 'ps-ai-codex/SKILL.md', 'ps-ai-copilot/SKILL.md',
    'ps-ai-repository/SKILL.md', 'ps-ai-repository/references/setup.md',
    'ps-ai-telegram/references/connect.md', 'ps-ai-telegram/references/install.md',
    'ps-ai-overseer/references/communication.md'
)
$text = ($owned | ForEach-Object { Get-SkillText $_ }) -join "`n"
foreach ($gone in @('registered in owner personalisation', 'Validate afterward', "use the installer only after the owner's login step")) {
    Assert-True (-not $text.Contains($gone)) "'$gone' is gone"
}
Assert-True ($text -notmatch '\birm\b') 'the remote irm installer is gone from the skill text'

$personalisation = Get-SkillText 'ps-ai-personalisation/SKILL.md'
foreach ($rule in @('exactly one question per message', 'Save preferences, rulings and lessons that must persist in shared ps-ai files', 'independent channels with the same priority', 'first acknowledge it there at once')) {
    Assert-True $personalisation.Contains($rule) "personalisation keeps '$rule'"
}
Assert-True ((Get-SkillText 'ps-ai-personalisation/references/fields.md').Contains('Only the owner logs in')) 'fields.md keeps owner-only login'
foreach ($tool in @('claude', 'codex', 'copilot')) {
    Assert-True ((Get-SkillText "ps-ai-$tool/references/accounts.md").Contains('## Foundry agent')) "$tool keeps its Foundry section"
}
