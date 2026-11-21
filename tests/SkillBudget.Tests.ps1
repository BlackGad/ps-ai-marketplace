$root = Split-Path $PSScriptRoot -Parent
$skills = Join-Path $root 'plugins/legion/skills'

function Get-SkillLines {
    param([string]$Relative)
    return @(Get-Content (Join-Path $skills $Relative)).Count
}

function Get-SkillText {
    param([string]$Relative)
    return Get-Content (Join-Path $skills $Relative) -Raw
}

$caps = [ordered]@{
    'legion-personalisation/references/create.md'   = 20
    'legion-claude/references/accounts.md'          = 45
    'legion-codex/references/accounts.md'           = 45
    'legion-copilot/references/accounts.md'         = 45
    'legion-personalisation/references/launcher.md' = 10
    'legion-repository/SKILL.md'                    = 35
    'legion-repository/references/setup.md'         = 20
    'legion-telegram/references/connect.md'         = 10
    'legion-personalisation/SKILL.md'               = 40
}
foreach ($file in $caps.Keys) {
    $lines = Get-SkillLines $file
    Assert-True ($lines -le $caps[$file]) "$file has $lines lines, the cap is $($caps[$file])"
}

# Personalisation SKILL.md loads before every flow, so it is not counted per flow.
$flows = [ordered]@{
    'first setup' = @(90, @('legion-personalisation/references/create.md', 'legion-personalisation/references/fields.md'))
    'add claude account' = @(130, @('legion-personalisation/references/create.md', 'legion-personalisation/references/fields.md', 'legion-claude/SKILL.md', 'legion-claude/references/accounts.md'))
    'add codex account' = @(130, @('legion-personalisation/references/create.md', 'legion-personalisation/references/fields.md', 'legion-codex/SKILL.md', 'legion-codex/references/accounts.md'))
    'add copilot account' = @(130, @('legion-personalisation/references/create.md', 'legion-personalisation/references/fields.md', 'legion-copilot/SKILL.md', 'legion-copilot/references/accounts.md'))
    'remove account' = @(60, @('legion-personalisation/references/create.md'))
    'repository' = @(80, @('legion-repository/SKILL.md', 'legion-repository/references/setup.md'))
    'launch' = @(60, @('legion-personalisation/references/launcher.md'))
    'telegram' = @(90, @('legion-telegram/SKILL.md', 'legion-telegram/references/connect.md', 'legion-telegram/references/install.md'))
    'status' = @(20, @())
}
foreach ($name in $flows.Keys) {
    $total = 0
    foreach ($file in $flows[$name][1]) { $total += Get-SkillLines $file }
    Assert-True ($total -le $flows[$name][0]) "$name flow reads $total lines, the cap is $($flows[$name][0])"
}

$owned = @(
    'legion-personalisation/SKILL.md', 'legion-personalisation/references/create.md',
    'legion-personalisation/references/fields.md', 'legion-personalisation/references/launcher.md',
    'legion-claude/references/accounts.md', 'legion-codex/references/accounts.md', 'legion-copilot/references/accounts.md',
    'legion-claude/SKILL.md', 'legion-codex/SKILL.md', 'legion-copilot/SKILL.md',
    'legion-repository/SKILL.md', 'legion-repository/references/setup.md',
    'legion-telegram/references/connect.md', 'legion-telegram/references/install.md',
    'legion-overseer/references/communication.md'
)
$text = ($owned | ForEach-Object { Get-SkillText $_ }) -join "`n"
$create = Get-SkillText 'legion-personalisation/references/create.md'
Assert-True ($create.Contains('unrecorded account') -and $create.Contains('without `-Add`')) 'K10 retries distinguish unrecorded accounts from plugin install failures'
Assert-True (-not $create.Contains('For `install failed` or `installed: open a new terminal`')) 'K10 plugin failures never repeat an unnamed add'
foreach ($gone in @('registered in owner personalisation', 'Validate afterward', "use the installer only after the owner's login step")) {
    Assert-True (-not $text.Contains($gone)) "'$gone' is gone"
}
Assert-True ($text -notmatch '\birm\b') 'the remote irm installer is gone from the skill text'

$personalisation = Get-SkillText 'legion-personalisation/SKILL.md'
foreach ($rule in @('exactly one question per message', 'Save preferences, rulings and lessons that must persist in shared legion files', 'independent channels with the same priority', 'first acknowledge it there at once')) {
    Assert-True $personalisation.Contains($rule) "personalisation keeps '$rule'"
}
Assert-True ((Get-SkillText 'legion-overseer/SKILL.md').Contains('will not respond for a while')) 'overseer announces unresponsive periods'
Assert-True ((Get-SkillText 'legion-overseer/SKILL.md').Contains('Keep the main session responsive')) 'overseer keeps the responsive-session rule'
Assert-True ((Get-SkillText 'legion-personalisation/references/fields.md').Contains('Only the owner logs in')) 'fields.md keeps owner-only login'
foreach ($tool in @('claude', 'codex', 'copilot')) {
    Assert-True ((Get-SkillText "legion-$tool/references/accounts.md").Contains('## Foundry agent')) "$tool keeps its Foundry section"
}

$tracked = @(git -C $root ls-files plugins README.md docs/reference.md) | Where-Object { $_ -notmatch '\.(png|jpg|ico)$' }
foreach ($old in @('legion start\b', 'legion repo\b', '-SourceRef')) {
    $hits = @($tracked | Where-Object { (Get-Content (Join-Path $root $_) -Raw) -match $old })
    Assert-True ($hits.Count -eq 0) "NoRemovedVerbs: '$old' is gone ($($hits -join ', '))"
}
