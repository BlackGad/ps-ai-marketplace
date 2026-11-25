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
Assert-True ($rule -match 'bounded status waits') 'Live overseer waits in bounded intervals without a wake event'
Assert-True ($rule -match 'session itself is ending') 'Pending result remains in handoff only at session end'
Assert-True ($rule -match 'without pushing') 'Shared mode records CI transitions locally without another CI run'
