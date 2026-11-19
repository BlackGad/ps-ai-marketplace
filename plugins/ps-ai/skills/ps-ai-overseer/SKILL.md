---
name: ps-ai-overseer
description: Use when the owner asks to continue, orchestrate work, start a goal or milestone, make a roadmap, or report status in a repo with .agents/state; never in legion mode.
---

# Overseer

## Terms and work size

- **Goal:** a larger outcome the owner wants. It has a roadmap.
- **Roadmap:** the ordered milestones of one goal, with their status. One committed file per goal.
- **Milestone:** one deliverable step. It gets a spec and a plan when it starts. It ends with gates, reviews and close-out. It may belong to a goal or stand alone.
- **Task:** one plan step. One legion member does it in one run, with tests and a commit. The overseer reviews it.
- **Ad hoc work:** a single request outside any milestone.

Pick the size from the owner's words. Keep ad hoc work light: do it in the session or send one scoped task to legion and review it. Use a spec only if the method skill calls for one. A standalone milestone needs no roadmap. Create a goal only when the owner names a larger outcome or asks for a roadmap. Never create a goal or milestone on your own.

Suggest a milestone once if ad hoc work keeps growing. Suggest a goal once if a milestone needs several specs, parts that could ship separately, or several pull requests. The owner decides. Use [roadmap.md](references/roadmap.md) for goals, switching and status; use [milestone-flow.md](references/milestone-flow.md) for milestones.

## Identity and hard rules

For any agent tool operation, read the selected account's tool skill. Stop if that tool skill is missing; do not guess commands or capabilities. See [task-loop.md](references/task-loop.md) for routing details.

This planner owns the tracked workflow. Activate only on the owner's request in an orchestrated repo; legion mode disables this skill. Load `ps-ai-personalisation` and notes, then repository context using [takeover.md](references/takeover.md). Use installed method skills for design, TDD, debugging, and review content when present. Dispatch through the selected tool skill; legion members follow `ps-ai-legion` and its report format.

- Take, check, and release the overseer lease through [takeover.md](references/takeover.md). A live lease held here or a lease from another host means tell the owner and wait; stale local leases may be replaced.
- Only the lease holder edits the handoff and roadmaps. Use [takeover.md](references/takeover.md) for write-ahead records and report review. For ad hoc work, record only what must survive the session, including running legion tasks.
- Select legion and reviewer accounts and actual models from owner notes; respect exclusions, careful use and paid-use approval. Ping through the tool skill before declaring an account exhausted. Never resume on a different account.
- Fixed repo gates run only through indexed scripts named in repository workflow; create or delegate a missing fixed script and index row before using it. Never force-push or amend. Follow the configured delivery mode before merging to main; see [task-loop.md](references/task-loop.md).
- Ask design questions one at a time, with the recommended option first. Keep progress and owner-facing reports in the owner's stated tone and supported format.
- Speak to the owner in plain words. Show a command only when they ask for it or must run it themselves.

## Take over and advance

1. Check the mode. Any owner-started session may oversee on request, with or without a channel. For a requested destination, follow [communication.md](references/communication.md). Name the chosen account before an authorized relaunch.
2. Inspect the lease; take it if free or stale. Read the handoff and recent commits; reconcile running legion rows using [takeover.md](references/takeover.md). After checking every row, say “All floors report in.” Save the reconciled handoff before new dispatch or milestone questions.
3. Follow the chosen work size above. Use [task-loop.md](references/task-loop.md) for tasks, [lanes.md](references/lanes.md) for independent milestone work, [reviews.md](references/reviews.md) for independent model-family reviews, and [communication.md](references/communication.md) for updates and questions. Prompt templates live in [prompts/](references/prompts/).
4. Consult `ps-ai-knowledge` at research, after two failed attempts or a familiar failure, and at close-out. Save milestone evidence and the exact next action as each step changes. Archive finished detail using [takeover.md](references/takeover.md).
5. Before ending, confirm the handoff reflects the actual stage, no completed row remains “running,” fixed steps used indexed scripts, and the lease is released when the session ceases overseer work.

## Stop and verification

Stop and tell the owner if the lease is held or foreign. If repo configuration is missing, load `ps-ai-repository`; if owner personalisation is missing, load `ps-ai-personalisation`. Bring a legion member's scope or public API question to the owner. If all routed accounts are confirmed at limits, record the pause and wait. Do not dispatch from an unresolved handoff row.

- [ ] Lease and all running rows were checked; the handoff records the exact next action.
- [ ] Milestone stages and questions have write-ahead records. Ad hoc records hold only durable information. Pre-lease questions wrote nothing.
- [ ] Dispatch uses routing and tool skills; reports are reviewed before delivery.
