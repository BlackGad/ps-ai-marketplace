# Installation

Claude is the tool that sets a bot up and pairs it; read its tool skill. Codex-only setup is not supported yet: the bot is set up and paired once on a Claude account, and Codex then uses it (see Codex below). Check what is ready without starting a CLI: `legion channel check --kind telegram --account <id>...` reports Bun and the Telegram plugin folder for each account. Never inspect credential files.

Deduplicate setup by kind/account, and installation by normalized config folder. Preview only missing work. One owner yes covers the shown helper and plugin actions. Decline makes no changes. Repeat completed work prints `skip: <what> (already done)`.

Approved missing Bun uses the existing helper:

```powershell
pwsh -NoProfile -File <plugin>/bin/legion-install-tool.ps1 -Tool bun -Yes
```

Windows offers winget or the official vendor-verified installer. Never install a package manager implicitly.

Inside the chosen Claude account, after approval:

```text
/plugin install telegram@claude-plugins-official
```

The CLI owns plugin updates. Root legion install/update/refresh never sets up channels. Uninstall retains channel plugins and state.

## Codex

Codex uses the same bot folder, already paired on Claude with `/telegram:access`; Codex does no pairing. The Codex overseer launch starts a bridge that needs uv. If uv is missing, ask the owner before installing it (`legion-install-tool.ps1 -Tool uv -Yes`); without uv the launch still works but Telegram messages do not arrive. Only one program may poll a bot: stop the Claude overseer that uses the same channel first.

Sources: [official plugin](https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/telegram/README.md), [Bun installation](https://bun.com/docs/installation). Inspect the connected session's actual tool definitions before using them. Source review does not prove a live connection.
