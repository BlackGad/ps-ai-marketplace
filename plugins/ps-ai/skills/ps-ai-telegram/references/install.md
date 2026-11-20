# Installation

Only Claude is verified as a supported tool. Read its tool skill. Check what is ready without starting a CLI: `pwsh -NoProfile -File <plugin>/bin/ps-ai-channel.ps1 -Action check -Kind telegram -Accounts <ids>` reports Bun and the Telegram plugin folder for each account. Never inspect credential files.

Deduplicate setup by kind/account, and installation by normalized config folder. Preview only missing work. One owner yes covers the shown helper and plugin actions. Decline makes no changes. Repeat completed work prints `skip: <what> (already done)`.

Approved missing Bun uses the existing helper:

```powershell
pwsh -NoProfile -File <plugin>/bin/ps-ai-install-tool.ps1 -Tool bun -Yes
```

Windows offers winget or the official vendor-verified installer. Never install a package manager implicitly.

Inside the chosen Claude account, after approval:

```text
/plugin install telegram@claude-plugins-official
```

The CLI owns plugin updates. Root ps-ai install/update/refresh never sets up channels. Uninstall retains channel plugins and state.

Sources: [official plugin](https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/telegram/README.md), [Bun installation](https://bun.com/docs/installation). Inspect the connected session's actual tool definitions before using them. Source review does not prove a live connection.
