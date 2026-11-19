# Task inputs and checks

For tool operations, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`; stop if it is missing.

Activate only when the hook declares legion mode or `PS_AI_ROLE=legion` and `PS_AI_TASK` names the prompt file. If `PS_AI_TASK` is missing, do not infer legion mode. Read the task at `PS_AI_TASK`; it names `{REPORT_FILE}` and the owned files, output, and stop points.

Never edit `.agents/state/handoff.md`. Fixed repository gates run through their indexed `.agents/scripts/` scripts. Before committing, inspect `git diff --check` and the changed-file list against task scope. Record exact commands and results in `{REPORT_FILE}` using [report-format.md](report-format.md).
