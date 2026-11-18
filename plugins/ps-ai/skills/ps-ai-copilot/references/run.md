# Run Copilot CLI

Choose `<command>` and `<model>` from personalisation, and read the task prompt from the overseer's file. The overseer must supply `<report>`; for scratch reports it belongs under the repo's `.agents/temp/` or the explicitly approved fixture root. Never invent a path directly under the system temp folder. When only showing commands and no report path was supplied, retain the `<report>` placeholder and ask the overseer to provide it. In the task repo, prompt mode is:

```sh
<command> -p "<prompt text>" --model <model> -s --allow-all-tools --deny-tool='shell(git push)' > "<report>"
```

For implementation legion work, set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt path>` on this process only. `--allow-all-tools` permits editing and shell use; `--deny-tool='shell(git push)'` takes precedence and blocks pushing, using the exact quoted syntax in `copilot --help`. `-s` makes stdout the concise report. Load the prompt file as one argument (PowerShell 7: `Get-Content -Raw -LiteralPath <prompt path>`); preserve its newlines and keep paths with spaces as single arguments. From a script, close stdin; a process left waiting on stdin may hang. For long work, launch in the background, capture stdout/stderr separately, and wait for completion.

For a **read-only reviewer** append `--allow-all-tools --deny-tool=write --deny-tool=shell`. Give the frozen repo path and report instructions in the prompt; capture stdout as the report because write is denied. Do not set legion mode for a reviewer. If the CLI cannot enforce the denials, stop rather than run the review.

For a legion follow-up after a question, use `--resume=<session-id> -p "<follow-up>" -s --allow-all-tools --deny-tool='shell(git push)'` on the same account and folder. Use the latest-session shortcut only when certain it is the task session. Keep the task environment for legion resumes. Reviewer follow-ups keep the read-only denials above.
