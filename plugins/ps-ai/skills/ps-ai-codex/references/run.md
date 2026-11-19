# Run Codex CLI

Select `<command>` and `<model>` from the account entry. The overseer supplies `<repo>`, `<prompt>`, and `<report>`. For a legion run, set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt>` on that process only:

```sh
PS_AI_ROLE=legion PS_AI_TASK="<prompt>" <command> exec -m <model> -C "<repo>" -o "<report>" - < "<prompt>"
```

Add `--dangerously-bypass-approvals-and-sandbox` only if the repo's configuration explicitly permits no sandbox. Otherwise use the default sandbox. `-o` writes the last response to the report; the task prompt should require the legion report sections. In PowerShell 7, pipe `Get-Content -Raw -LiteralPath <prompt>` into `& <command> exec ... -`; this closes stdin after the prompt. For a background process, redirect stdin from the prompt file and close it after sending, keep stderr in a task log, and wait for process completion, not log polls.

Resume a stopped task from the **same account and folder** with `<command> exec resume --last <follow-up>` when the most recent session is known to be the task. Use its session ID instead of `--last` if another session may have run. `exec resume` has no `-C` option: start it with the repository folder as the working directory. Keep the task environment for a legion resume. Never move a session between `CODEX_HOME` folders.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with account/channel/project flags, use [launcher.md](launcher.md). Install and account login steps stay in [accounts.md](accounts.md).
