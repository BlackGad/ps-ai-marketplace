# Run Codex CLI

Read owner notes before account/model selection, dispatch or limit fallback. Use actual stated models and exclusions, account purposes, careful-use choices and paid-use approval. Re-read after edits. Channel operations route through `skills/ps-ai-<kind>/SKILL.md`; stop if missing.
Derive `<command>` from the account ID as `<home>/.agents/bin/<id>` on Unix or `<home>/.agents/bin/<id>.cmd` on Windows. Choose the actual `<model>` from owner notes. The overseer supplies `<repo>`, `<prompt>`, and `<report>`, all within the assigned repository or worktree. Start there and inherit the owner's environment, including user PATH and installed tools. For a legion run, set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt>` on that process only. Use the worker profile below.

```sh
PS_AI_ROLE=legion PS_AI_TASK="<prompt>" <command> exec --dangerously-bypass-approvals-and-sandbox -m <model> -C "<repo>" -o "<report>" - < "<prompt>"
```

PowerShell 7: set `$command`, `$model`, `$promptText`, `$repoPath` and `$report` from the assigned task. Keep the same process environment and capture stdout as the report where needed.

```powershell
$promptText | & $command exec --dangerously-bypass-approvals-and-sandbox -m $model -C $repoPath -o $report -
```

Legion always uses this unsandboxed profile so it can edit, run checks, and commit using the real machine setup. Stop if it cannot be applied; do not fall back to a sandbox or provision tools. `-o` writes the last response to the report; the task prompt should require the legion report sections. In PowerShell 7, pipe `Get-Content -Raw -LiteralPath <prompt>` into `& <command> exec --dangerously-bypass-approvals-and-sandbox ... -`; this closes stdin after the prompt. For a background process, redirect stdin from the prompt file and close it after sending, keep stderr in a task log, and wait for process completion, not log polls.

Resume a stopped legion task from the **same account and folder** with `<command> exec --dangerously-bypass-approvals-and-sandbox resume --last <follow-up>` when the most recent session is known to be the task. Use its session ID instead of `--last` if another session may have run. `exec resume` has no `-C` option: start it with the repository folder as the working directory. Keep the task environment and unsandboxed profile for a legion resume. Never move a session between `CODEX_HOME` folders.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use [launcher.md](launcher.md). Install and account login steps stay in [accounts.md](accounts.md).
