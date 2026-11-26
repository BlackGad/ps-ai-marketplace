$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$overseer = Join-Path $root 'plugins/legion/skills/legion-overseer'
$rule = Get-Content (Join-Path $overseer 'references/pending-results.md') -Raw
$skill = Get-Content (Join-Path $overseer 'SKILL.md') -Raw
$task = Get-Content (Join-Path $overseer 'references/task-loop.md') -Raw
$takeover = Get-Content (Join-Path $overseer 'references/takeover.md') -Raw
$communication = Get-Content (Join-Path $overseer 'references/communication.md') -Raw

Assert-True $skill.Contains('references/pending-results.md') 'Overseer loads the pending-result rule'
Assert-True $task.Contains('pending-results.md') 'Task dispatch and review use the same rule'
Assert-True $takeover.Contains('pending-results.md') 'Restart and takeover use the same rule'
Assert-True $communication.Contains('pending-results.md') 'Owner reporting uses the same rule'
foreach ($evidence in @('background worker', 'hosted CI', 'external job', 'Next action', 'owner decision', 'technical blocker', 'connected channel', 'investigat', 'approval', 'lease')) {
    Assert-True ($rule -match [regex]::Escape($evidence)) "Pending-result rule covers $evidence"
}
Assert-True ($rule.Contains('report to the overseer')) 'Workers still report through the overseer'
Assert-True ($rule -match 'session itself is ending') 'Pending result remains in handoff only at session end'
$claude = Get-Content (Join-Path $root 'plugins/legion/skills/legion-claude/references/run.md') -Raw
$codex = Get-Content (Join-Path $root 'plugins/legion/skills/legion-codex/references/run.md') -Raw
$copilot = Get-Content (Join-Path $root 'plugins/legion/skills/legion-copilot/references/run.md') -Raw
foreach ($tool in @('legion-claude', 'legion-codex', 'legion-copilot')) {
    Assert-True ($rule.Contains("../../$tool/references/run.md#keep-the-session-responsive")) "Pending-result rule links the $tool wait section"
}
Assert-True ($codex -match 'no completion notice') 'Codex gets no completion notice'
Assert-True ($codex -match 'chunks of a few minutes') 'Codex waits in the foreground in chunks'
Assert-True ($codex -match 'repository inbox') 'Codex reads the inbox between chunks'
Assert-True ($codex -match 'Before waiting, tell the owner') 'Codex tells the owner before waiting'
Assert-True ($copilot -match 'chunks of a few minutes') 'Copilot uses the chunked wait'
Assert-True ($claude -match 'never ends a turn on a promised result unless a background command') 'Claude never ends a turn without a notifying background command'
Assert-True ($claude -match 'gh run watch') 'Claude watches hosted CI in the background'
