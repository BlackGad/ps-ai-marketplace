# Takeover and tracked handoff

Activate only on the owner's request in a repo with `.agents/state`; `PS_AI_ROLE=legion` disables the overseer. Load personalisation and notes, then repo rules, `.agents/configuration/project.json`, `.agents/configuration/workflow.md`, `.agents/scripts/index.md`, the handoff, plan, and relevant spec.

Read `.agents/state/handoff.md`, recent history, `git status`, `git log`, the named plan and spec, and repository rules. The handoff headings are exactly: Branch; Milestone; State; Current task; Legion running; Next action; Open decisions; Postponed; Recent evidence. Only the overseer edits it. Keep it short; archive finished milestone details in `state/history/`.

The lease is `.agents/temp/overseer.lock`. Use `pwsh -NoProfile -File <plugin>/bin/ps-ai-lease.ps1 -Action take|status|release -Repo <repo> -Tool <tool> -Account <id>` for every lease operation; never write or delete the lock directly. The script writes `tool`, `account`, `pid`, `processStartedAt`, `host`, `startedAt` atomically. The default owner is the nearest non-shell ancestor (the long-lived agent CLI session); shell helpers are skipped. Pass `-ProcessId` to override it explicitly. A local PID with the recorded process start time is held; a dead or reused PID, or a legacy lock without that start time, is stale, and a different host is foreign. On held or foreign, tell the owner and wait; a foreign lease is unknown, not automatically stale. On stale, take over: the owner's request to continue already authorizes replacing a stale lease, so do not ask again. Host names compare without case (`HOST-A` and `host-a` are the same machine). Release the lease through the script when overseer work ends. Do not infer legion mode from a lease.

For each `Legion running` row, check in this order:

| Evidence | Action |
| --- | --- |
| Process alive | Wait for completion; do not duplicate the run. |
| Report present | Immediately write `State: reviewing task N report` and `Next action: review report, then indexed gates` before running the gate or another task action. Read `ps-ai-legion/references/report-format.md`, review the report, commit, scope, checks, and questions. Record result; remove the running row. |
| Task commit present, report absent | Review from the commit and plan; record the missing report and result. |
| No report or task commit | Save staged and unstaged tracked work with `git diff --binary HEAD` into a patch under `.agents/temp/`. List untracked files with `git ls-files --others --exclude-standard` and copy them separately under `.agents/temp/`, preserving their relative paths. Record the patch and copy paths in the handoff. Relaunch through the matching tool skill, same account for resume or another routed account with patch and a fresh prompt. In a dry-run scenario, describe the proposed relaunch without executing it; show commands only when requested or when the owner must run them themselves. |

After every row is checked, say **“All floors report in.”** Write the reconciled handoff before new work or a question. At launch time, write the new row with account, task, prompt/report/log paths, base commit, and start time; set next action to `wait for task N, then review` before starting the tool. After completion, record commit/check/report evidence, remove its row, and set the next action. Each milestone step and owner question gets a write-ahead handoff update, written to disk at once and committed with its stage.
