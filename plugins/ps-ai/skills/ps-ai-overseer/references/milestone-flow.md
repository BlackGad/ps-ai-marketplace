# Milestone state machine

Use `State` in the handoff for the current stage; write each transition to disk at once and commit it with its stage. For a fixed repo step, resolve its script name from `project.json.steps` and `scripts/index.md`; create/index a missing fixed script before invoking it. Plans and specs live at `project.json.paths`, not an installed method skill's default path.

| State | Enter when | Action and exit condition |
| --- | --- | --- |
| Research | Prior milestone closed or owner selects one | Read roadmap, spec, code, reuse inventory; consult `ps-ai-knowledge`. Exit with a research note, scope, task split, and questions. |
| Design questions | Research exposes owner choices | Ask one at a time, recommendation first; record numbered user rulings. Exit when no design question remains. |
| Plan draft | Rulings settled | Use installed planning method when present and [prompts/plan-skeleton.md](prompts/plan-skeleton.md); include contracts, tests, commit messages, review focus. Exit with committed plan. |
| Plan dry-run | Plan committed | One independent read-only dry-run with [prompts/dry-run.md](prompts/dry-run.md). Exit with report. |
| Rulings | Dry-run report exists | Decide bookkeeping; bring design changes to owner. Rewrite and review plan. Exit with committed rulings. |
| Tasks | Plan ready | Run [task-loop.md](task-loop.md). Exit when all task reports, reviews, and required task gates are recorded. |
| Milestone gate | Tasks complete | Run indexed milestone scripts once from base. Exit with read results. |
| Gate fixes | Gate fails | Scope a fix using installed debugging/TDD methods; rerun affected gates. Exit when clean. |
| Performance check | Gate clean | Compare named paired runs for time and allocation when the repo has a budget; profile suspicious results. Exit within budget or with explained gap sent to owner. |
| Reviews | Code final | Use [reviews.md](reviews.md) on a frozen commit. Exit when every independent report is verified. |
| Findings to owner | Reports verified | Deduplicate, rank by agreement then severity, present a short table, ask for the fix decision. Exit with owner ruling. |
| Review fixes | Approved findings | Use [prompts/fix.md](prompts/fix.md), one reproducing test per finding; record unreproducible claims. Exit with verified fixes and review. |
| Close-out | Tasks, gates, reviews, fixes complete | Update roadmap, archive evidence, consult/file `ps-ai-knowledge`, clean temp after needed reports are archived, commit handoff. Exit when milestone is closed. |

Open an investigation with [prompts/investigation.md](prompts/investigation.md) for intermittent failures; do not mark them green by rerunning alone. The close-out line **“Everything proceeds according to plan.”** is used only after every task and gate passed.
