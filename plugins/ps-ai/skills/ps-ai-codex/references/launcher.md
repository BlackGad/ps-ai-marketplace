# Codex overseer launcher

Use the shared [launcher shim](../../ps-ai-personalisation/references/launcher.md) after selecting an account from personalisation:

```text
ps-ai-overseer -Tool codex -Account agent-a -Repo <repo> -DryRun
```

Run without `-DryRun` only when the owner requests the launch. Direct shim invocation is authorization; an offer from another session needs the owner's yes. The account's `command` selects its executable or wrapper. An account wrapper sets `CODEX_HOME` to its configured folder; the launcher invokes that wrapper rather than setting the variable itself. `configDir` records the folder; `default` keeps the CLI's default account folder (`~/.codex`). Extra accounts use `~/.agents/accounts/<id>/`. Register the chosen command and folder through [accounts.md](accounts.md).

The shared launcher merges account `agents[].launch.args`, `communication.channels.<name>.launch.codex`, and `projects.<id>.launch.codex` in that order, followed by the tool's interactive arguments and initial prompt. Preserve each array item as one argument and use only flags supported by this CLI.

Account and project argument arrays may contain owner-selected model flags such as `["--model","<model>"]`. There are no extra interactive arguments for this tool. Preserve the configured sandbox; see [run.md](run.md). Hook trust is described in [plugins.md](plugins.md).
