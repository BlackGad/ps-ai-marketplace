# Set up, add or remove accounts

1. Start with the `status` tool on the plugin's `legion` MCP server; if it fails to start, use `legion status --json`. It reads settings, accounts, commands and channels. Follow the [read tools guide](../../legion-overseer/references/read-tools.md) for limits selection and side effects. Members never call these tools. Reuse the owner's earlier answers.

2. Ask which agents to add: the tool, an optional account name, and an existing folder or a new one. Adding no accounts yet is valid. A folder the owner already uses keeps its settings and login.

3. Show the plan, then run once with `--yes` after the owner's one yes. Without `--yes` it only prints the plan (an owner at a terminal is asked `Apply? [Y/n]`):

```text
legion setup [--yes]
legion add <tool> [<existing folder>] [--id <name>] [--yes]
```

   Setup creates missing settings and notes, installs a missing CLI, adds accounts, writes the owner commands and installs legion into every account. A recorded subscription account without its own program starts with the stock CLI on PATH; if that CLI is missing, setup offers to install it. A repeat prints `skip:` lines. Finish an earlier setup the same way, with `legion setup`. Owner settings live in `~/.legion/configuration/personalisation.json` and notes in `notes.md` beside it. The same yes adds the bin folder to the Windows user PATH. On macOS and Linux it appends `# Added by legion` and `export PATH="$HOME/.legion/bin:$PATH"` once to the profile selected by `$SHELL`: `~/.zshrc` for zsh, `~/.bashrc` for bash, otherwise `~/.profile`. The plan names that file before consent. A repeat prints `skip: shell profile PATH (already done)`; purge removes the recorded line and marker, keeping every other byte. Open a new terminal if needed.

4. Read the table's last column. `log in: run legion --account <id>` is the owner's job: only the owner logs in. For a CLI failure or `installed: open a new terminal`, repeat the add later only for an unrecorded account. For a legion `install failed`, the account is recorded: finish setup with `legion setup`. Mention once that `legion help` lists the same steps as short commands.

5. Remove an account with `legion remove --id <id>`; its folder is kept. Renaming, registering a shortcut and Foundry use the tool's account guide.

Only Foundry agents ask about models during setup. Do not ask about models for subscription agents, account purposes, worker or reviewer roles, notification timing, channels, or knowledge. Learn preferences later from the owner's words and save them using the [shared memory rule](../SKILL.md#identity-and-hard-rules). Set up a channel only when requested, such as “use Telegram”, through `skills/legion-<kind>/SKILL.md`; stop if missing. The overseer asks about legion access at the [first legion dispatch](../../legion-overseer/references/task-loop.md#first-legion-dispatch). After an account change, move affected repository facts to that repository's workflow and repair prose references in notes; scripts never edit notes. In tests or an alternate home run `legion --home <temp home> setup` and fake every external tool.
