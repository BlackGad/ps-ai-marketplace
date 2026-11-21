# Set up, add or remove accounts

1. Start with status: `pwsh -NoProfile -File <plugin>/bin/legion-status.ps1`. It reads only files and shows settings, accounts, commands and channels. Reuse the owner's earlier answers.

2. Ask which agents to add: the tool, an optional account name, and an existing folder or a new one. Adding no accounts yet is valid. A folder the owner already uses keeps its settings and login.

3. Show the plan, then run once with `-Yes` after the owner's one yes. It never changes anything without `-Yes`:

```text
pwsh -NoProfile -File <plugin>/bin/legion-setup.ps1 [-Add @('claude','codex:<existing folder>')] [-Id <name>] [-Yes] [-HomeRoot <home>]
```

   Setup creates missing settings and notes, installs a missing CLI, adds accounts, writes the owner commands and installs ps-ai into every account. For a recorded subscription account whose launchers are both gone, setup uses the stock CLI on PATH to restore them. If that CLI is also missing, the table says `target needed`. A repeat prints `skip:` lines. Finish an earlier setup the same way, without `-Add`.

4. Read the table's last column. `log in: run <id>` is the owner's job: only the owner logs in. For a CLI failure or `installed: open a new terminal`, repeat the add later only for an unrecorded account. For a ps-ai `install failed`, the account is recorded: finish setup without `-Add`. Mention once that `legion help` lists the same steps as short commands.

5. Remove an account with `pwsh -NoProfile -File <plugin>/bin/legion-account.ps1 -Action remove -Id <id>`; its folder is kept. Renaming, registering a shortcut and Foundry use the tool's account guide.

Only Foundry agents ask about models during setup. Do not ask about models for subscription agents, account purposes, worker or reviewer roles, notification timing, channels, or knowledge. Learn preferences later from the owner's words and save them using the [shared memory rule](../SKILL.md#identity-and-hard-rules). Set up a channel only when requested, such as “use Telegram”, through `skills/legion-<kind>/SKILL.md`; stop if missing. The overseer asks about legion access at the [first legion dispatch](../../legion-overseer/references/task-loop.md#first-legion-dispatch). After an account change, move affected repository facts to that repository's workflow and repair prose references in notes; scripts never edit notes. In tests or an alternate home pass `-HomeRoot <temp home>` and fake every external tool.
