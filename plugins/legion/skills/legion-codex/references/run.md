# Run Codex CLI

Pass a model (`-m <named-model>`) only as [model tiers](../../legion-overseer/references/task-loop.md#model-tiers) allows; for Foundry, pass the deployment name as [Foundry routing](../../legion-overseer/references/task-loop.md#foundry-runs) says.

`<command>` is the [run command](../../legion-overseer/references/task-loop.md#run-command). The overseer supplies `<repo>`, `<prompt>`, and `<report>`, all within the assigned repository or worktree. Start there and inherit the owner's environment, including user PATH and installed tools. For a legion run, set `LEGION_ROLE=member` and `LEGION_TASK=<prompt>` on that process only. Use the worker profile below.

```sh
LEGION_ROLE=member LEGION_TASK="<prompt>" <command> exec --dangerously-bypass-approvals-and-sandbox -C "<repo>" -o "<report>.last.md" - < "<prompt>"
```

PowerShell 7: set `$legion` (that home's `legion.cmd`), `$account`, `$promptText`, `$repoPath` and `$report` from the assigned task. Keep the same process environment and capture stdout as the report where needed.

```powershell
$promptText | & $legion run --account $account -- exec --dangerously-bypass-approvals-and-sandbox -C $repoPath -o "${report}.last.md" -
```

Legion always uses this unsandboxed profile so it can edit, run checks, and commit using the real machine setup. Stop if it cannot be applied; do not fall back to a sandbox or provision tools. The legion writes `<report>`; the overseer reads `<report>` and falls back to `<report>.last.md` (the last response saved by `-o`) only when `<report>` is missing. For a background process, redirect stdin from the prompt file and close it after sending, keep stderr in a task log, and wait for process completion, not log polls.

Resume a stopped legion task from the **same account and folder** with `<command> exec --dangerously-bypass-approvals-and-sandbox resume --last <follow-up>` when the most recent session is known to be the task. Use its session ID instead of `--last` if another session may have run. `exec resume` has no `-C` option: start it with the repository folder as the working directory. Keep the task environment and unsandboxed profile for a legion resume. Never move a session between `CODEX_HOME` folders.

Tool-enforced read-only reviewer dispatch is unsupported by this adapter: no verified fresh-run or resume recipe is supplied. Stop before launching a reviewer or reviewer follow-up through this tool. A read-only prompt does not enforce access restrictions; do not reuse the legion recipe for reviews. Tell the overseer to select a routed tool with a documented enforced reviewer recipe, or ask the owner how to proceed if none is available.

For interactive overseer launches with explicit account/model/argument choices and selected channels, use the [launcher guide](../../legion-personalisation/references/launcher.md). Install and account login steps stay in [accounts.md](accounts.md).

## Keep the session responsive

Codex gets no completion notice, so ending the turn ends the watch. Before waiting, tell the owner in the console and every connected channel that replies will be slower, and why. Then wait in the foreground, each wait returning within about 60 seconds. Prefer waiting on the same execution session with a timeout. To recover from a process id alone, use a timed wait (`Wait-Process -Id <pid> -Timeout 60` on Windows) or a bounded liveness check (`kill -0 <pid>`, then a short sleep, on POSIX). For CI, read it the way the repository is configured, with a timeout; on GitHub Actions, for example, `gh run watch <id> --exit-status` under a 60-second timeout. A timeout means still pending: read the repository inbox, answer the owner on the console and connected channels, then resume waiting until the result is terminal; then collect and act. These bounded waits are the allowed exception to "never poll in a loop". Never end the turn while a promised result is pending, except at a real owner decision or blocker, recorded in the handoff first (if the lease was lost, follow the takeover rule instead). Why and the blocking notice: [Keep the main session responsive](../../legion-overseer/SKILL.md#identity-and-hard-rules).

## Taking the overseer lease

Shell commands under the Codex app-server run below a long-lived `codex app-server` daemon, not below your session, so `legion lease take` refuses to guess. Pass `--process-id` with the interactive Codex session's process id: on Windows run `Get-CimInstance Win32_Process -Filter "Name='codex.exe'" | Select ProcessId,CommandLine` and pick the `codex.exe` whose command line has no `app-server`; on Linux and macOS run `ps -eo pid,command | grep '[c]odex'` and pick the one without `app-server`. If several Codex sessions run, pick the one started from this terminal or whose command line resumes this thread id; if it is still unclear, ask the owner for the pid. Reuse the same pid for `legion lease release --process-id`.
