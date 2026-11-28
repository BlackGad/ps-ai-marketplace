# legion

[![tests](https://github.com/BlackGad/ps-legion-marketplace/actions/workflows/tests.yml/badge.svg?branch=main&event=push)](https://github.com/BlackGad/ps-legion-marketplace/actions/workflows/tests.yml)
[![integration](https://github.com/BlackGad/ps-legion-marketplace/actions/workflows/integration.yml/badge.svg?branch=main&event=push)](https://github.com/BlackGad/ps-legion-marketplace/actions/workflows/integration.yml)
[![release](https://img.shields.io/github/v/release/BlackGad/ps-legion-marketplace)](https://github.com/BlackGad/ps-legion-marketplace/releases)

Long work stalls when one AI session loses context or hits its usage limit. It has no independent reviewer, while your other subscriptions and accounts sit unused. Starting another session means explaining the work again.

legion connects **Claude Code, Codex CLI and Copilot CLI** into a team. An **overseer** session plans and tracks work in your repository, dispatches tasks to **legion members** on other accounts and CLIs, reviews their reports, and records progress in a handoff file. The next session continues from that handoff. You drive the work by talking to your AI tool: answer its questions and approve its proposals.

![A stalled session and idle accounts beside connected accounts that share work, review results, and pass a handoff to the next session.](docs/images/problem-solution.png)

![The owner directs the overseer, which assigns tasks across legion accounts, reviews their reports, and saves a handoff for the next session.](docs/images/overseer-legion.png)

## Install

Windows (PowerShell):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1)))
```

macOS and Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.sh | sh
```

The bootstrap offers to install uv if it is missing, then announces when it starts preparing Legion and asks before installing it for your AI tools. Answer the prompts in the terminal. Windows needs only the built-in PowerShell. Add `-Yes` in PowerShell to skip the install questions. On macOS and Linux, replace `sh` with `sh -s -- --yes`. See [installer options](docs/reference.md#installer-parameters).

## Why mix tools

Different tools and providers give independent reviews another perspective. Without a stated preference, the overseer picks among your eligible accounts by task, capacity and cost, never reviews code with the agent that wrote it, and says which account it chose. Each CLI uses that account's own default model. Preferences you state later are saved in notes and take priority.

## First-time setup

1. **Install.** Run the install command above. In Codex, open `/hooks` once per account and approve the legion hooks.
2. **Add accounts.** Open your AI tool and say “Add a Codex agent called `<name>`” or “Add my existing Claude account from `<account folder>`.” You can also say “summon a minion”. Setup asks only which accounts to add. One yes approves installing legion into the selected accounts. For a new account, setup shows the command that starts the tool on that account's folder; run it once and log in yourself. An existing folder is copied into the account and keeps its settings and login; the original stays as it is.
3. **Start work.** Run `legion` in your repository; it sets up orchestration if needed and reopens the last conversation. Describe what you want done, then say “Continue.” Before the first legion task, the overseer asks once about running without a sandbox and saves your answer in notes. Future sessions continue from the handoff.

Add preferences later in your own words. Say “use Telegram” when you want a channel.

legion keeps settings in `~/.legion/configuration/`, account folders in `~/.legion/agents/`, and the running sessions' registrations in `~/.legion/run/`. The `legion` command is a [uv](https://docs.astral.sh/uv/) tool: setup installs it with `uv tool install` and, with your yes, runs `uv tool update-shell` so uv's tool folder is on your PATH. If the uv tool folder is missing from PATH, `legion status` reports it and setup offers a repair. Repository orchestration files live in `.legion/`.

`legion dismiss` releases a repository again: it removes the legion traces outside `.legion/` and then `.legion/` itself.

`legion status` lists outlanders separately from accounts. An outlander is the owner's default `~/.claude`, `~/.codex`, or `~/.copilot` folder when that tool's stock command is on PATH. Install puts Legion there for first setup and the owner's own work. The optional llm-wiki plugin goes into Legion accounts only.

Repository setup offers [Private (default) or Shared](plugins/legion/skills/legion-repository/SKILL.md#choose-where-notes-live) storage for notes and history.

## What you can do

Open your AI tool and say:

- “Continue.” / “Next milestone.”
- “Add another legion member.”
- “Check limits for `<account name>`.”
- “Change my notification preferences.”
- “Add an Azure Foundry agent.”
- “What was learned elsewhere?”

## Update and uninstall

Say “Update legion” or “Uninstall legion,” or run `legion update` or `legion uninstall`. On Windows, close your Legion session, run `legion update` from a terminal, then reopen Legion. An update started from a registered Windows session refuses before making changes.

One update covers registered accounts and outlanders. Before replacing the command, Legion waits for the MCP servers and `legion run` wrappers registered in its home to exit, with the updater and its ancestors exempt. The bootstrap and macOS/Linux updates show plugin steps, uv's progress, and the result in the terminal. On Windows, the installed `legion` command schedules its own replacement after it exits and gives you the log path. Check `~/.legion/temp/uv-tool.log` for a scheduled update or uninstall result. `legion status` flags failures recorded in the log. Restart your sessions after a successful update and use the handoff to recover stopped members. See [running sessions and recovery](docs/reference.md#running-sessions-and-the-stop-event). If `legion` is unavailable, run the matching one-liner in PowerShell.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Update
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Uninstall
```

Uninstall shows each tool's plugin and marketplace removal steps as they run. A full uninstall waits for registered Legion processes outside the calling session to exit, then schedules removal of the `legion` command. An installed uv stays installed. If the bootstrap downloads uv for uninstall, it uses a temporary copy that remains available to the helper after the bootstrap exits.

> [!IMPORTANT]
> A plain uninstall keeps your settings, notes, account folders and logins. **Purge removes that data after the uv uninstall succeeds** or when the command is already absent. Purge also removes the recorded PATH entries for portable tools Legion installed. It asks separately before deleting a knowledge hub. The coding tools keep their own data and settings.

Run `legion uninstall --purge`, or use this PowerShell one-liner:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Uninstall -Purge
```

## Security

Legion members have your full user rights. They are instructed to stay in their assigned repository, never push or install tools, and report missing tools. These are instructions, not enforced access limits. Use accounts you trust, or leave legion unused. Never share tokens or credentials with an agent.

[Details for maintainers and power users](docs/reference.md).

License: [MIT](LICENSE).
