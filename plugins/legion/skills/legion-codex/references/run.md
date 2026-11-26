# Run Codex CLI

Follow [owner notes](../../legion-personalisation/references/fields.md) before account, model or channel choices.
Legion and review runs omit model flags so the CLI uses that account's own default. When notes name a model or allow a tier, follow [model tiers](../../legion-overseer/references/task-loop.md#model-tiers) and add `-m <named-model>` for that run. For Foundry, pass the deployment name using [Foundry routing](../../legion-overseer/references/task-loop.md#foundry-runs). Do not discover models or offer a model list for subscription agents.

Derive `<command>` from the account ID as `<home>/.legion/bin/<id>` on Unix or `<home>/.legion/bin/<id>.cmd` on Windows. The overseer supplies `<repo>`, `<prompt>`, and `<report>`, all within the assigned repository or worktree. Start there and inherit the owner's environment, including user PATH and installed tools. For a legion run, set `LEGION_ROLE=member` and `LEGION_TASK=<prompt>` on that process only. Use the worker profile below.

```sh
LEGION_ROLE=member LEGION_TASK="<prompt>" <command> exec --dangerously-bypass-approvals-and-sandbox -C "<repo>" -o "<report>.last.md" - < "<prompt>"
```

PowerShell 7: set `$command`, `$promptText`, `$repoPath` and `$report` from the assigned task. Keep the same process environment and capture stdout as the report where needed.

```powershell
$promptText | & $command exec --dangerously-bypass-approvals-and-sandbox -C $repoPath -o "${report}.last.md" -
```

Legion always uses this unsandboxed profile so it can edit, run checks, and commit using the real machine setup. Stop if it cannot be applied; do not fall back to a sandbox or provision tools. The legion writes `<report>`; the overseer reads `<report>` and falls back to `<report>.last.md` (the last response saved by `-o`) only when `<report>` is missing. In PowerShell 7, pipe `Get-Content -Raw -LiteralPath <prompt>` into `& <command> exec --dangerously-bypass-approvals-and-sandbox ... -`; this closes stdin after the prompt. For a background process, redirect stdin from the prompt file and close it after sending, keep stderr in a task log, and wait for process completion, not log polls.

Resume a stopped legion task from the **same account and folder** with `<command> exec --dangerously-bypass-approvals-and-sandbox resume --last <follow-up>` when the most recent session is known to be the task. Use its session ID instead of `--last` if another session may have run. `exec resume` has no `-C` option: start it with the repository folder as the working directory. Keep the task environment and unsandboxed profile for a legion resume. Never move a session between `CODEX_HOME` folders.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use [launcher.md](launcher.md). Install and account login steps stay in [accounts.md](accounts.md).

## Keep the session responsive

Codex gets no completion notice, so ending the turn ends the watch. Before waiting, tell the owner in the console and every connected channel that replies will be slower, and why. Then wait in the foreground in chunks of a few minutes on the worker's process id (or on the CI run with a bounded `gh run watch`). Between chunks, read the repository inbox and answer the owner. Repeat until the result is terminal, then collect and act. Never end the turn while a promised result is pending, except at a real owner decision or blocker, recorded in the handoff first. Why and the blocking notice: [Keep the main session responsive](../../legion-overseer/SKILL.md#identity-and-hard-rules).
