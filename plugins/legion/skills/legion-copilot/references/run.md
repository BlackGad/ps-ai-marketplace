# Run Copilot CLI

Pass a model (`--model <named-model>`) only as [model tiers](../../legion-overseer/references/task-loop.md#model-tiers) allows; for Foundry, pass the deployment name as [Foundry routing](../../legion-overseer/references/task-loop.md#foundry-runs) says.

`<command>` is the [run command](../../legion-overseer/references/task-loop.md#run-command). Read the task prompt from the overseer's file. The prompt, report and logs stay inside the assigned repository or worktree, under `.legion/temp/` for scratch files; never invent a path directly under the system temp folder. If no report path was supplied, keep the `<report>` placeholder and ask the overseer for it. Start there and inherit the owner's environment, including user PATH and installed tools. Use the worker profile below. In the task repo, legion prompt mode is:

```sh
<command> -p "Read and follow the task in <prompt path>." -s --allow-all-tools --deny-tool='shell(git push)' > "<report>.stdout.md"
```

PowerShell 7: set `$legion` (that home's `legion.cmd`), `$account`, `$promptPath`, `$repoPath` and `$report` from the assigned task. Keep the same process environment and capture stdout in `<report>.stdout.md`.

```powershell
$promptText = "Read and follow the task in $promptPath."
& $legion run --account $account -- -p $promptText -s --allow-all-tools '--deny-tool=shell(git push)'
```

For implementation legion work, set `LEGION_ROLE=member` and `LEGION_TASK=<prompt path>` on this process only. `-p` is non-interactive and `--allow-all-tools` permits tools to run automatically without confirmation, including editing, checks, and local commits. Legion uses this profile without a CLI sandbox to see the real machine setup; stop if it cannot be applied and do not provision tools. `--deny-tool='shell(git push)'` takes precedence and blocks that push command, using the exact quoted syntax in help; the legion contract forbids all pushing. `-s` keeps stdout to the final response. The member writes `<report>`; the overseer reads `<report>.stdout.md` only when `<report>` is missing. Pass a one-line prompt naming the prompt file, with the whole argument quoted so paths with spaces stay intact; a `.cmd` command such as `legion.cmd` cuts a multi-line argument at the first line break. The agent reads every line from the named file. From a script, close stdin; a process left waiting on stdin may hang. For long work, launch in the background, capture stdout/stderr separately, and wait for completion.

For a **read-only reviewer** append `--allow-all-tools --deny-tool=write --deny-tool=shell`. Give the frozen repo path and report instructions in the prompt; capture stdout as the report because write is denied. Do not set member mode for a reviewer. If the CLI cannot enforce the denials, stop rather than run the review.

For a legion follow-up after a question, use `--resume=<session-id> -p "<follow-up>" -s --allow-all-tools --deny-tool='shell(git push)'` on the same account and folder. Use the latest-session shortcut only when certain it is the task session. Keep the task environment for legion resumes. Reviewer follow-ups keep the read-only denials above.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use the [launcher guide](../../legion-personalisation/references/launcher.md). Install and account login steps stay in [accounts.md](accounts.md).

## Keep the session responsive

When this tool gives no completion notice, follow the [Codex recipe](../../legion-codex/references/run.md#keep-the-session-responsive). Why and the blocking notice: [Keep the main session responsive](../../legion-overseer/SKILL.md#identity-and-hard-rules).
