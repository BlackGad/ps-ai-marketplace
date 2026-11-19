# Copilot overseer launcher

Use the shared [launcher shim](../../ps-ai-personalisation/references/launcher.md) after selecting an account from personalisation:

```text
ps-ai-overseer -Tool copilot -Account agent-a -Repo <repo> -DryRun
```

Run without `-DryRun` only when the owner requests the launch. Direct shim invocation is authorization; an offer from another session needs the owner's yes. The account's `command` selects its executable or wrapper. An account wrapper sets `COPILOT_HOME` to its configured folder; the launcher invokes that wrapper rather than setting the variable itself. `configDir` records the folder; `default` keeps the CLI's default account folder (`~/.copilot`). Extra accounts use `~/.agents/accounts/<id>/`. Register the chosen command and folder through [accounts.md](accounts.md).

The shared launcher merges account `agents[].launch.args`, `communication.channels.<name>.launch.copilot`, and `projects.<id>.launch.copilot` in that order, followed by the tool's interactive arguments and initial prompt. Preserve each array item as one argument and use only flags supported by this CLI.

Account and project argument arrays may contain owner-selected model flags such as `["--model","<model>"]`. The descriptor appends `-i` after merged flags and before the initial prompt. Read-only review restrictions remain in [run.md](run.md).

The account's `models.overseer` becomes `--model <model>` unless an account, channel, or project launch array already selects a model explicitly. Explicit model flags take precedence over the role preference.
