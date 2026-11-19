# Run Copilot CLI

Read owner notes before account/model selection, dispatch or limit fallback. Use actual stated models and exclusions, account purposes, careful-use choices and paid-use approval. Re-read after edits. Channel operations route through `skills/ps-ai-<kind>/SKILL.md`; stop if missing.
Derive `<command>` from account ID as `<home>/.agents/bin/<id>` on Unix or `<home>/.agents/bin/<id>.cmd` on Windows. Choose the actual `<model>` from owner notes, and read the task prompt from the overseer's file. For legion, the prompt, report, and logs must be inside the assigned repository or worktree, under `.agents/temp/` for scratch files. Start there and inherit the owner's environment, including user PATH and installed tools. Never invent a path directly under the system temp folder. When only showing commands and no report path was supplied, retain the `<report>` placeholder and ask the overseer to provide it. `tool.json` records the required worker profile in `legionArgs`; supply prompt, model, and paths as shown. In the task repo, legion prompt mode is:

```sh
<command> -p "<prompt text>" --model <model> -s --allow-all-tools --deny-tool='shell(git push)' > "<report>"
```

For implementation legion work, set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt path>` on this process only. `copilot --help` confirms `-p` is non-interactive and `--allow-all-tools` permits tools to run automatically without confirmation, including editing, checks, and local commits. Legion uses this profile without a CLI sandbox to see the real machine setup; stop if it cannot be applied and do not provision tools. `--deny-tool='shell(git push)'` takes precedence and blocks that push command, using the exact quoted syntax in help; the legion contract forbids all pushing. `-s` makes stdout the concise report. Load the prompt file as one argument (PowerShell 7: `Get-Content -Raw -LiteralPath <prompt path>`); preserve its newlines and keep paths with spaces as single arguments. From a script, close stdin; a process left waiting on stdin may hang. For long work, launch in the background, capture stdout/stderr separately, and wait for completion.

For a **read-only reviewer** append `--allow-all-tools --deny-tool=write --deny-tool=shell`. Give the frozen repo path and report instructions in the prompt; capture stdout as the report because write is denied. Do not set legion mode for a reviewer. If the CLI cannot enforce the denials, stop rather than run the review.

For a legion follow-up after a question, use `--resume=<session-id> -p "<follow-up>" -s --allow-all-tools --deny-tool='shell(git push)'` on the same account and folder. Use the latest-session shortcut only when certain it is the task session. Keep the task environment for legion resumes. Reviewer follow-ups keep the read-only denials above.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use [launcher.md](launcher.md). Install and account login steps stay in [accounts.md](accounts.md).
