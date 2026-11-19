# Milestone state machine

Use the terms in [the overseer skill](../SKILL.md#terms-and-work-size). Use `State` in the handoff for the current stage; write each transition to disk at once and commit it with its stage. Save state and close-out history in the owning Git repository using [takeover.md](takeover.md). For a fixed repo step, resolve its script name from the gates named in `workflow.md` and `scripts/index.md`; create/index a missing fixed script before invoking it. Plans and specs live at the paths recorded in `workflow.md`. Give those paths to installed method skills in place of their defaults.

When the owner starts a goal milestone, check the active-milestone rule in [roadmap.md](roadmap.md), set its status to `active`, and commit it with the stage.

| State | Enter when | Action and exit condition |
| --- | --- | --- |
| Research | Owner starts or selects a milestone | Read the goal's roadmap when present, existing specs when present, code, and reuse evidence; consult `ps-ai-knowledge`. Apply the work-size suggestion in the overseer skill; the owner decides. Exit with a research note, scope, task split, and questions. |
| Design questions | Research exposes owner choices | Ask one at a time, recommendation first; record numbered user rulings. Exit when no design question remains. |
| Spec | Research and design questions settled | Use the installed brainstorming method to write the milestone spec at the spec path in `workflow.md`. Without that method, write a short spec from research and owner rulings. Keep it local. Exit only after the owner approves the spec. |
| Plan draft | Owner approved the spec | Use the installed planning method when present and [prompts/plan-skeleton.md](prompts/plan-skeleton.md); include contracts, tests, commit messages, review focus. Use the plan path in `workflow.md` (local, never committed). Answer the method's execution choice with legion through [task-loop.md](task-loop.md), or offer the fallback below when no legion account is usable. Exit with the plan saved. |
| Plan dry-run | Plan saved | One independent read-only dry-run with [prompts/dry-run.md](prompts/dry-run.md). Exit with report. |
| Rulings | Dry-run report exists | Decide bookkeeping; bring design changes to owner. Rewrite and review plan. Exit with the rulings written into the local plan. |
| Tasks | Plan ready | Run [task-loop.md](task-loop.md), or the owner's chosen fallback below. Exit when all task results, reviews, and required task gates are recorded. |
| Milestone gate | Tasks complete | Run indexed milestone scripts once from base. Exit with read results. |
| Gate fixes | Gate fails | Scope a fix using installed debugging/TDD methods; rerun affected gates. Exit when clean. |
| Performance check | Gate clean | Compare named paired runs for time and allocation when the repo has a budget; profile suspicious results. Exit within budget or with explained gap sent to owner. |
| Reviews | Code final | Use [reviews.md](reviews.md) on a frozen commit. Exit when every independent report is verified. |
| Findings to owner | Reports verified | Deduplicate, rank by agreement then severity, present a short table, ask for the fix decision. Exit with owner ruling. |
| Review fixes | Approved findings | Use [prompts/fix.md](prompts/fix.md), one reproducing test per finding; record unreproducible claims. Exit with verified fixes and review. |
| Close-out | Tasks, gates, reviews, fixes complete | Archive milestone evidence in `state/history/`. For a goal milestone, set its roadmap status to `done` and link that history. Propose roadmap changes learned during the milestone; wait for the owner's yes before changing its structure. Standalone milestones skip roadmap edits. Consult/file `ps-ai-knowledge`, clean temp after needed reports are archived, and commit handoff and roadmap edits with the stage. Exit when milestone is closed. |

## Execution choice

Legion runs plan tasks. Check owner routing, exclusions, paid-use approval, and account pings through [task-loop.md](task-loop.md) before deciding no legion account is usable. If none is usable, tell the owner and offer the installed planning method's own execution. Proceed with that method only if the owner chooses it. Keep the milestone's gates, reviews, and close-out. If the owner declines, or no method execution is available, record the pause and exact next action in the handoff and wait. This also applies when legion becomes unavailable during task execution.

Open an investigation with [prompts/investigation.md](prompts/investigation.md) for intermittent failures; do not mark them green by rerunning alone. Report close-out only after every task and gate passed.
