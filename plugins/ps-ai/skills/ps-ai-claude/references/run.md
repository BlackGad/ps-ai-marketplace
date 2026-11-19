# Run Claude Code

Choose `<command>` and `<model>` from the selected account's personalisation entry. The overseer supplies `<repo>`, `<prompt file>`, and `<report>`. Use a fresh process for each task; set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt file>` for that process only. From `<repo>`:

```sh
PS_AI_ROLE=legion PS_AI_TASK="<prompt file>" <command> -p --model <model> < "<prompt file>" > "<report>"
```

PowerShell 7: set those two process environment variables around `Get-Content -Raw -LiteralPath <prompt file> | & <command> -p --model <model> > <report>`, then restore their previous values. Piping the file closes stdin when it ends. For a background launch, redirect stdin from the prompt file, stdout to the report, and stderr to a separate task log; close unused stdin and wait for process completion rather than reading the log repeatedly. Do not put credentials in the prompt or log.

To continue after a question, use the same account and folder with `--resume <session-id> -p` (or `--continue -p` only when the latest session is certainly the task session). Preserve the task environment and append the follow-up response to the report. Never resume a Claude session with another account.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with account/channel/project flags, use [launcher.md](launcher.md). Install and account login steps stay in [accounts.md](accounts.md).
