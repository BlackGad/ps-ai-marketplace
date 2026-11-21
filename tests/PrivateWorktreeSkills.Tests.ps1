$root = Split-Path $PSScriptRoot -Parent
$skills = Join-Path $root 'plugins/ps-ai/skills'
$lanes = Get-Content (Join-Path $skills 'legion-overseer/references/lanes.md') -Raw
Assert-True ($lanes.Contains('a new lane or review worktree has no `.legion/`')) 'Private lane and review checkouts need local setup'
Assert-True ($lanes -match 'Before dispatch.*copies.*\.legion/configuration/.*\.legion/scripts/.*main tree.*same paths in the worktree') 'Overseer copies configuration and indexed scripts before dispatch'
Assert-True ($lanes.Contains('read-only; script or rules changes go through the main tree')) 'Private copies cannot diverge through worker edits'
Assert-True ($lanes.Contains('Shared mode needs no copy')) 'Shared checkouts already contain the setup'
Assert-True ($lanes -match 'shares `info/exclude`.*copies and scratch ignored') 'Private copies stay excluded across worktrees'
foreach ($reference in @('reviews.md', 'task-loop.md')) {
    $text = Get-Content (Join-Path $skills "legion-overseer/references/$reference") -Raw
    Assert-True ($text -match 'Before dispatch.*configuration and scripts.*\[lanes.md\]\(lanes.md\).*Private copies') "$reference uses the worktree preparation rule"
}
$task = Get-Content (Join-Path $skills 'legion-member/references/task.md') -Raw
Assert-True ($task -match 'Private worktree.*read-only copies.*\.legion/configuration/.*\.legion/scripts/') 'Worker knows where Private workflow and gates come from'
Assert-True ($task.Contains('Run indexed checks from those copies')) 'Worker can run the supplied gates'
Assert-True ($task -match 'script or rule needs changing, stop and report.*main tree') 'Worker sends script and rule changes to the overseer'
