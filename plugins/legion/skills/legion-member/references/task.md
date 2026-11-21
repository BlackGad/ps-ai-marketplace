# Task inputs and checks

For tool operations, read `skills/legion-<agent.tool>/SKILL.md` using the selected account's `agent.tool`; stop if it is missing.

Activate only when the hook declares member mode or `LEGION_ROLE=member` and `LEGION_TASK` names the prompt file. If `LEGION_TASK` is missing, do not infer member mode. Read the task at `LEGION_TASK`; it names `{REPORT_FILE}` and the owned files, output, and stop points.

## Machine and folder safeguards

Legion runs without the CLI sandbox and inherits the owner's installed SDKs, tools, and user PATH. It can edit, run checks, and commit with full user rights. These instructions are safeguards, not an operating-system access boundary.

- Never download or install an SDK, runtime, package manager, or tool, including a portable copy inside the repo. Do not fetch a replacement or change the machine setup to make a check pass.
- If a required tool is missing or the wrong version, stop the task and report the tool, required version, observed version or absence, and blocked check. Do not install it yourself; the overseer asks the owner how to proceed.
- Keep task file access, edits, reports, logs, and check output inside the assigned repository or worktree and within the assigned scope. Read installed skills and owner settings/notes as required, and use installed tools in place; never modify those locations or other folders. If task inputs are outside the worktree or a check needs to write elsewhere, stop and report it. The overseer must prepare local inputs or resolve the check before another run.
- Commit only locally. Never push through any command or service, and never amend, rebase, or rewrite commits.

In a Private worktree, the overseer supplies read-only copies of `.legion/configuration/` and `.legion/scripts/`. Run indexed checks from those copies. If a script or rule needs changing, stop and report it; the overseer makes that change through the main tree. Shared mode needs no copy.

Never edit `.legion/state/handoff.md`. Fixed repository gates run through their indexed `.legion/scripts/` scripts. Before committing, inspect `git diff --check` and the changed-file list against task scope. Record exact commands and results in `{REPORT_FILE}` using [report-format.md](report-format.md).
