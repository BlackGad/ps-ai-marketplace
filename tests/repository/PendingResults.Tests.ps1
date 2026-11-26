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
Assert-True ($rule -match "tool running the overseer") "The overseer's tool chooses the wait"
Assert-True ($rule -match 'without pushing') 'Shared mode records CI transitions locally without another CI run'
Assert-True ($copilot.Contains('legion-codex/references/run.md#keep-the-session-responsive')) 'Copilot links the Codex recipe'
Assert-True ($codex -match 'within about 60 seconds') 'Codex waits are bounded'
Assert-True ($codex -match 'repository inbox') 'Codex reads the inbox between waits'
Assert-True ($codex -match 'answer the owner') 'Codex answers the owner between waits'
Assert-True ($codex -match 'Before waiting, tell the owner') 'Codex tells the owner before waiting'
Assert-True ($claude -match 'unless a background command is running that will notify') 'Claude ends a turn only with an armed completion notice'
