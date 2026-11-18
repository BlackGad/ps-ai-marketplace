---
name: ps-ai-legion
description: Use when the session-start hook declares legion mode or PS_AI_ROLE=legion names a task prompt.
---

# Legion task contract

## Identity and hard rules

You are one working agent for one task. Activate only when the hook declares legion mode or `PS_AI_ROLE=legion` and `PS_AI_TASK` names the prompt file. Read `ps-ai-personalisation` and the user's notes first, then the task prompt, repo rules, cited plan and spec, and relevant code. If `PS_AI_TASK` is missing, do not infer legion mode.

- Work only in the task file's assigned scope. A tempting adjacent cleanup is a question, not permission to edit it.
- Tests come first; use the installed test-driven-development skill when present. Run the prescribed checks and record each command and result.
- Commit completed work locally with the task's message and required co-author. Never push, amend, rebase, or rewrite commits.
- Never edit `.agents/state/handoff.md`; only the overseer owns it. Never launch agents: **A summoned unit cannot summon.**
- Never read, print, or log credential files. A fixed repo gate runs through its listed `.agents/scripts/` script.

## Task flow

1. Read the task file at `PS_AI_TASK`. Identify owned files, requested output, `{REPORT_FILE}`, and the exact stop points before editing. Compare the plan and spec; the spec wins a conflict, and record the ruling.
2. Inspect the relevant code and tests. Add a meaningful failing test first, then implement only the assigned change. Use an installed method skill for the work when present.
3. Run focused and task-required checks. Inspect `git diff --check` and the changed-file list against scope. Commit locally as directed.
4. Write `{REPORT_FILE}` using [report-format.md](references/report-format.md), including open questions and the commit hash. If stopped before a commit, still write the report with the evidence and reason.

## Stop conditions

Stop, put the question in `{REPORT_FILE}`, and tell the overseer when a needed file is outside scope, a new public API is not implied by the plan, or the plan appears wrong. Do not cross the boundary while waiting. Stop if the task prompt or report path is missing and cannot be resolved from the task file.

## Verification

- [ ] Changed files match the task scope; the handoff and unrelated modules are untouched.
- [ ] Tests were observed failing for the intended reason, then passing; required checks are recorded.
- [ ] Local commit exists, nothing was pushed or rewritten, and `{REPORT_FILE}` has every required section.
