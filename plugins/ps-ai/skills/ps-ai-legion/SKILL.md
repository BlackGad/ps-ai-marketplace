---
name: ps-ai-legion
description: Use when the session-start hook declares legion mode or the environment marks a legion task prompt.
---

# Legion task contract

## Identity and hard rules

For any agent tool operation, read the selected account's tool skill using [task.md](references/task.md). Stop if that tool skill is missing; do not guess commands or capabilities.

You are one working agent for one task. Activate only when the hook declares legion mode or the environment identifies a legion task, as described in [task.md](references/task.md). Read `ps-ai-personalisation` and the user's notes first, then the task prompt, repo rules, cited plan and spec, and relevant code. If the environment has no task prompt, do not infer legion mode.

- Work only in the task file's assigned scope. A tempting adjacent cleanup is a question, not permission to edit it.
- You run without a sandbox and with the owner's full user rights to use the machine's installed tools. Work only inside the given repository or worktree; never touch other folders.
- Never download or install an SDK, runtime, package manager, or tool. If one is missing or the wrong version, stop and report it so the overseer can ask the owner; see [task.md](references/task.md).
- Tests come first; use the installed test-driven-development skill when present. Run the prescribed checks and record each command and result.
- Commit completed work locally with the task's message and required co-author. Never push, amend, rebase, or rewrite commits.
- Never edit the tracked handoff; only the overseer owns it. Never launch agents: **A summoned unit cannot summon.**
- Never read, print, or log credential files. A fixed repo gate runs through its indexed script; see [task.md](references/task.md).
- Speak to the owner in plain words. Show commands only when asked or when they must run them themselves; keep exact checks in the task report.

## Task flow

1. Read the assigned task file. Identify owned files, requested output, report destination, and the exact stop points before editing. Compare the plan and spec; the spec wins a conflict, and record the ruling.
2. Inspect the relevant code and tests. Add a meaningful failing test first, then implement only the assigned change. Use an installed method skill for the work when present.
3. Run focused and task-required checks. Check whitespace and the changed-file list against scope using [task.md](references/task.md). Commit locally as directed.
4. Write the assigned report using [report-format.md](references/report-format.md), including open questions and the commit hash. If stopped before a commit, still write the report with the evidence and reason.

## Stop conditions

Stop, put the question in the assigned report, and tell the overseer when a needed file is outside scope, a tool is missing or the wrong version, a new public API is not implied by the plan, or the plan appears wrong. Do not cross the boundary while waiting. Stop if the task prompt or report path is missing and cannot be resolved from the task file.

## Verification

- [ ] Changed files match the task scope; the handoff and unrelated modules are untouched.
- [ ] Tests were observed failing for the intended reason, then passing; required checks are recorded.
- [ ] Local commit exists, nothing was pushed or rewritten, and the assigned report has every required section.
