# Run Claude Code

Read owner notes before account/model selection, dispatch or limit fallback. Use actual stated models and exclusions, account purposes, careful-use choices and paid-use approval. Re-read after edits. Channel operations route through `skills/ps-ai-<kind>/SKILL.md`; stop if missing.
Derive `<command>` from account ID as `<home>/.agents/bin/<id>` on Unix or `<home>/.agents/bin/<id>.cmd` on Windows. Choose the actual `<model>` from owner notes. The overseer supplies `<repo>`, `<prompt file>`, and `<report>`, all within the assigned repository or worktree. Start there and inherit the owner's environment, including user PATH and installed tools. Use a fresh process for each task; set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt file>` for that process only. `tool.json` records the required worker profile in `legionArgs`; supply model, paths, and prompt as shown. From `<repo>`:

```sh
PS_AI_ROLE=legion PS_AI_TASK="<prompt file>" <command> -p --permission-mode bypassPermissions --model <model> < "<prompt file>" > "<report>"
```

Legion always uses this unsandboxed profile so it can edit, run checks, and commit using the real machine setup. Stop if it cannot be applied; do not fall back to a sandbox or provision tools. PowerShell 7: set those two process environment variables around `Get-Content -Raw -LiteralPath <prompt file> | & <command> -p --permission-mode bypassPermissions --model <model> > <report>`, then restore their previous values. Piping the file closes stdin when it ends. For a background launch, redirect stdin from the prompt file, stdout to the report, and stderr to a separate task log; close unused stdin and wait for process completion rather than reading the log repeatedly. Do not put credentials in the prompt or log.

To continue a legion task after a question, use the same account and folder with `--resume <session-id> -p --permission-mode bypassPermissions` (or `--continue -p --permission-mode bypassPermissions` only when the latest session is certainly the task session). Preserve the task environment and unsandboxed profile, and append the follow-up response to the report. Never resume a Claude session with another account.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use [launcher.md](launcher.md). Install and account login steps stay in [accounts.md](accounts.md).
