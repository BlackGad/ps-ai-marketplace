# Run Claude Code

Pass a model (`--model <named-model>`) only as [model tiers](../../legion-overseer/references/task-loop.md#model-tiers) allows; for Foundry, pass the deployment name as [Foundry routing](../../legion-overseer/references/task-loop.md#foundry-runs) says.

`<command>` is the [run command](../../legion-overseer/references/task-loop.md#run-command). The overseer supplies `<repo>`, `<prompt file>`, and `<report>`, all within the assigned repository or worktree. Start there and inherit the owner's environment, including user PATH and installed tools. Use a fresh process for each task; set `LEGION_ROLE=member` and `LEGION_TASK=<prompt file>` for that process only. Use the worker profile below. From `<repo>`:

```sh
LEGION_ROLE=member LEGION_TASK="<prompt file>" <command> -p --permission-mode bypassPermissions --strict-mcp-config < "<prompt file>" > "<report>.stdout.md"
```

PowerShell 7: set `$legion` (that home's `legion.cmd`), `$account`, `$promptText`, `$repoPath` and `$report` from the assigned task. Keep the same process environment and capture stdout in `<report>.stdout.md`.

```powershell
$promptText | & $legion run --account $account -- -p --permission-mode bypassPermissions --strict-mcp-config
```

`--strict-mcp-config` (with no `--mcp-config`) makes the run load no MCP servers: only the overseer connects channels, and a legion run must never start a channel plugin or any other MCP server, or two programs poll one bot and the run swallows the owner's messages.

Legion always uses this unsandboxed profile so it can edit, run checks, and commit using the real machine setup. Stop if it cannot be applied; do not fall back to a sandbox or provision tools. The member writes `<report>`; stdout goes to `<report>.stdout.md`, which the overseer reads only when `<report>` is missing. For a background launch, redirect stdin from the prompt file, stdout to `<report>.stdout.md`, and stderr to a separate task log; close unused stdin and wait for process completion rather than reading the log repeatedly. Do not put credentials in the prompt or log.

To continue a legion task after a question, use the same account and folder with `--resume <session-id> -p --permission-mode bypassPermissions --strict-mcp-config` (or `--continue -p --permission-mode bypassPermissions --strict-mcp-config` only when the latest session is certainly the task session). Preserve the task environment and unsandboxed profile, and append its stdout to `<report>.stdout.md`. Never resume a Claude session with another account.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use the [launcher guide](../../legion-personalisation/references/launcher.md). Install and account login steps stay in [accounts.md](accounts.md).

## Keep the session responsive

Claude Code offers background shell commands: start long steps in the background and read the output when the completion notice arrives. Why and the blocking notice: [Keep the main session responsive](../../legion-overseer/SKILL.md#identity-and-hard-rules).

The overseer never ends a turn on a promised result unless a background command is running that will notify on completion for that result. If the result has no process (hosted CI), start a background command that waits for its terminal state, for example `gh run watch <id> --exit-status`, and read the result when notified.
