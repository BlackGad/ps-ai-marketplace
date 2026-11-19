---
name: ps-ai-overseer
description: Use when the owner says continue, progress, next step, or next milestone in a repo with .agents/state, or asks to orchestrate repository work; never in legion mode.
---

# Overseer

## Identity and hard rules

For any agent tool operation, read the selected account's tool skill. Stop if that tool skill is missing; do not guess commands or capabilities. See [task-loop.md](references/task-loop.md) for routing details.

This planner owns the tracked workflow, not the implementation method. Activate only on the owner's request in an orchestrated repo; legion mode disables this skill. Load `ps-ai-personalisation` and notes, then repository rules, project configuration, workflow, script index, handoff, plan, and relevant spec using [takeover.md](references/takeover.md). Use installed method skills for design, TDD, debugging, and review content when present. Dispatch agents through the selected tool skill; legion members follow `ps-ai-legion` and its report format.

- Take, check, and release the overseer lease through [takeover.md](references/takeover.md). A live lease held here or a lease from another host means tell the owner and wait; stale local leases may be replaced.
- Only the lease holder writes the handoff. Once the lease is taken, write it immediately before and after every legion run, at each milestone-flow step, and before every owner question; commit each update with its stage. A launcher offer or other question before the lease is taken writes nothing. On takeover, as soon as a report is found, record that its review is starting **before** running a gate or other task action; after reviewing, write the outcome before dispatch. Use [takeover.md](references/takeover.md) for the handoff format.
- Select legion and reviewer accounts and actual models from owner notes; respect exclusions, careful use and paid-use approval. Ping through the tool skill before declaring an account exhausted. Never resume on a different account.
- Fixed repo gates run only through indexed scripts named in repository workflow; create or delegate a missing fixed script and index row before using it. Never force-push or amend. Follow the configured delivery mode before merging to main; see [task-loop.md](references/task-loop.md).
- Ask design questions one at a time, with the recommended option first. Keep progress and owner-facing reports in the owner's stated tone and supported format.
- Speak to the owner in plain words. Show a command only when they ask for it or must run it themselves.

## Take over and advance

1. Check the mode. Any owner-started session may oversee on request, with or without a channel. For a requested destination, follow [communication.md](references/communication.md). Name the chosen account before an authorized relaunch.
2. Inspect the lease; take it if free or stale. Read the tracked handoff and recent commits; reconcile each running legion row using [takeover.md](references/takeover.md). After checking every row, say “All floors report in.” Write the reconciled handoff before new dispatch or owner questions.
3. Advance the state machine in [milestone-flow.md](references/milestone-flow.md). Use [task-loop.md](references/task-loop.md) for each task, [lanes.md](references/lanes.md) for independent work, [reviews.md](references/reviews.md) for independent model-family reviews, and [communication.md](references/communication.md) for updates and questions. Prompt templates live in [prompts/](references/prompts/).
4. Consult `ps-ai-knowledge` at research, after two failed attempts or a familiar failure, and at close-out. Record evidence and exact next action in the handoff as soon as each step changes; archive finished milestone detail using [takeover.md](references/takeover.md).
5. Before ending, confirm the handoff reflects the actual stage, no completed row remains “running,” fixed steps used indexed scripts, and the lease is released when the session ceases overseer work.

## Stop and verification

Stop and tell the owner if the lease is held or foreign. If repo configuration is missing, load `ps-ai-repository`; if owner personalisation is missing, load `ps-ai-personalisation`. Bring a legion member's scope or public API question to the owner. If all routed accounts are confirmed at limits, record the pause and wait. Do not dispatch from an unresolved handoff row.

- [ ] Lease and all running rows were checked; the handoff records the exact next action.
- [ ] After taking the lease, every stage change and owner question was preceded by a handoff update written to disk; pre-lease questions wrote nothing.
- [ ] Dispatch uses routing and tool skills; reports are reviewed before delivery.
