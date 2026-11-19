# Claude overseer launcher

Use the shared [launcher shim](../../ps-ai-personalisation/references/launcher.md) after selecting an account from personalisation:

```text
ps-ai-overseer -Tool claude -Account agent-a -Repo <repo> -DryRun
```

Run without `-DryRun` only when the owner requests the launch. Direct shim invocation is authorization; an offer from another session needs the owner's yes. The account's `command` selects its executable or wrapper. An account wrapper sets `CLAUDE_CONFIG_DIR` to its configured folder; the launcher invokes that wrapper rather than setting the variable itself. `configDir` records the folder; `default` keeps the CLI's default account folder (`~/.claude`). Extra accounts use `~/.agents/accounts/<id>/`. Register the chosen command and folder through [accounts.md](accounts.md).

The shared launcher merges account `agents[].launch.args`, `communication.channels.<name>.launch.claude`, and `projects.<id>.launch.claude` in that order, followed by the tool's interactive arguments and initial prompt. Preserve each array item as one argument and use only flags supported by this CLI.

For example, account `launch.args: ["--verbose"]`, channel `launch: {"claude":["--channels","plugin:telegram@claude-plugins-official"]}`, and project `launch: {"claude":["--verbose"]}` are merged without splitting values. Configure only an installed, owner-selected channel plugin. There are no extra interactive arguments for this tool.

The account's `models.overseer` becomes `--model <model>` unless an account, channel, or project launch array already selects a model explicitly. Explicit model flags take precedence over the role preference.
