# Goals and roadmaps

Use the terms and work sizes in [the overseer skill](../SKILL.md#terms-and-work-size). A goal or milestone starts only at the owner's request. Several goals may be open. At most one milestone across all goals and standalone work may be active. Keep one overseer lease for the repo. Parallel lanes stay inside that milestone.

## Create a roadmap

1. Start when the owner names a larger outcome or asks for a roadmap.
2. Brainstorm only the split: milestones, their order, and observable done-criteria. Use the installed brainstorming method's decomposition when present. Leave milestone details and specs until that milestone starts.
3. Show the proposed roadmap. Wait for the owner's yes before writing it. Use [roadmap-template.md](../../legion-repository/references/roadmap-template.md), then commit the file.
4. Ask whether to start the first milestone now. Follow [milestone-flow.md](milestone-flow.md) only if the owner chooses to start it.

## File rules

Store one committed file per goal at `.legion/state/roadmap/<goal-id>.md`. Use the owning Git repository from [takeover.md](takeover.md), including when reading creation history. Use lowercase hyphenated ids. The folder listing is the index; add no index file. A missing or empty folder is normal. Spec and plan paths still come from `workflow.md` and stay local.

Milestone statuses are `planned`, `active`, `paused`, `done`, and `dropped`. Before making a milestone active, check all roadmaps and the handoff for another active milestone. Paused work or no current work may leave none active.

Only the lease holder edits roadmap files. Edit them to create an approved goal, set status as work moves, or link a closed milestone's history. Commit each edit with its stage. Adding, reordering, renaming, or dropping milestones needs the owner's yes. Close-out may propose changes; approval comes before those edits.

## Resume or switch

“Continue” resumes the goal and milestone named in the handoff. Load its roadmap when it has a goal. For ad hoc work, resume only the durable work recorded there.

For “work on <goal>”, park the current milestone first:

1. Let running legion tasks finish and review them through [takeover.md](takeover.md). Save the review outcomes before switching.
2. Record the current stage, task, evidence, and exact next action in the handoff. Preserve these resume details in `state/history/` before replacing the current handoff. Link that history from `Postponed` in the new handoff, with the goal id or standalone milestone name. Keep earlier resume links.
3. Set the old milestone to `paused` in its roadmap. For a standalone milestone, record the pause in handoff/history. Commit the pause and resume details.
4. Change the handoff's current goal and milestone. Restore its saved details when resuming paused work. Set the selected milestone to `active` and commit the stage. Start a new milestone only at the owner's request.

With nothing current and several open goals, ask which to work on. Recommend a goal with a paused milestone first, then the oldest goal with planned milestones. Use Git history of roadmap creation for age; add no date field. Never pick silently.

## Report status

For “where are we” or a status request, read the roadmap folder and handoff. Show each open goal and all its milestone statuses. A goal is open while it has planned, active, or paused work. Then name the current milestone, its stage, and current task from the handoff. With no goals, report only the current standalone milestone or ad hoc work. Do not invent structure for the report.
