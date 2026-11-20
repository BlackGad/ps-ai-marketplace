# Run Claude Code

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.
Legion and review runs omit model flags so the CLI uses that account's own default. When notes name a model or allow a tier, follow [model tiers](../../ps-ai-overseer/references/task-loop.md#model-tiers) and add `--model <named-model>` for that run. For Foundry, pass the deployment name using [Foundry routing](../../ps-ai-overseer/references/task-loop.md#foundry-runs). Do not discover models or offer a model list for subscription agents.

Derive `<command>` from account ID as `<home>/.legion/bin/<id>` on Unix or `<home>/.legion/bin/<id>.cmd` on Windows. The overseer supplies `<repo>`, `<prompt file>`, and `<report>`, all within the assigned repository or worktree. Start there and inherit the owner's environment, including user PATH and installed tools. Use a fresh process for each task; set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt file>` for that process only. Use the worker profile below. From `<repo>`:

```sh
PS_AI_ROLE=legion PS_AI_TASK="<prompt file>" <command> -p --permission-mode bypassPermissions < "<prompt file>" > "<report>"
```

PowerShell 7: set `$command`, `$promptText`, `$repoPath` and `$report` from the assigned task. Keep the same process environment and capture stdout as the report where needed.

```powershell
$promptText | & $command -p --permission-mode bypassPermissions
```

Legion always uses this unsandboxed profile so it can edit, run checks, and commit using the real machine setup. Stop if it cannot be applied; do not fall back to a sandbox or provision tools. PowerShell 7: set those two process environment variables around `Get-Content -Raw -LiteralPath <prompt file> | & <command> -p --permission-mode bypassPermissions > <report>`, then restore their previous values. Piping the file closes stdin when it ends. For a background launch, redirect stdin from the prompt file, stdout to the report, and stderr to a separate task log; close unused stdin and wait for process completion rather than reading the log repeatedly. Do not put credentials in the prompt or log.

To continue a legion task after a question, use the same account and folder with `--resume <session-id> -p --permission-mode bypassPermissions` (or `--continue -p --permission-mode bypassPermissions` only when the latest session is certainly the task session). Preserve the task environment and unsandboxed profile, and append the follow-up response to the report. Never resume a Claude session with another account.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use [launcher.md](launcher.md). Install and account login steps stay in [accounts.md](accounts.md).

## Keep the session responsive

Claude Code offers background shell commands: start long steps (test gates, legion runs, waiting for a limit reset) in the background and read the output when the completion notice arrives. Never poll in a loop; keep foreground steps short so owner messages are answered meanwhile.
