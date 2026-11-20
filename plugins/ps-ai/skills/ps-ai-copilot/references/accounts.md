# Copilot CLI accounts

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.
Add and adopt through `ps-ai-setup.ps1`, as [create.md](../../ps-ai-personalisation/references/create.md) describes. It suggests `copilot<n>`, accepts a valid custom lowercase hyphenated id that is not a command on PATH, installs a missing `copilot` CLI, creates the wrapper and config folder, and installs ps-ai, all before login. For a new folder only, the owner runs `<id>` in a terminal to log in once; never handle tokens or credential files. Follow the [shared account rules](../../ps-ai-personalisation/references/fields.md#account-setup).

[install.md](install.md) covers a CLI-only install the owner asks for. Register an existing wrapper with `-Action register -Id <id> -Tool copilot -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`; rename with `-Action rename -Id <old> -NewId <new>`; remove with `-Action remove -Id <id>`. These use `bin/ps-ai-account.ps1`; they update channel bindings, keep the config folder and print its location. Ask before changing or deleting that folder.

## Foundry agent

Use this flow instead of the subscription login flow above. One agent uses one endpoint. Copilot Foundry agents support **Claude deployments only**. GPT deployments are out of scope. Run these commands in PowerShell 7; pass `-HomeRoot <home>` for an alternate home.

Use these commands for a Foundry provider configuration request. Ordinary setup can adopt an existing folder and keep its provider settings. For Foundry only, ask “Standard mapping or choose deployments yourself?” Reuse choices already supplied. Follow [Foundry model mapping](../../ps-ai-personalisation/references/foundry-models.md) for discovery, `-Standard` and unresolved aliases. These examples show explicit choices:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool copilot -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x
```

Add writes the provider entry and the wrappers. It writes no persistent Copilot provider config. The provider default must name a configured deployment. The runner leaves run-time model selection to the account's CLI default unless owner notes name a model or allow a tier; follow [Foundry routing](../../ps-ai-overseer/references/task-loop.md#foundry-runs). Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For a requested provider configuration change, reuse the supplied settings and apply the complete replacement with:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x
```

An identical result prints `skip: models <id> (no changes)` and writes nothing. Then run `ps-ai-setup.ps1 -Yes` to install ps-ai into this account's folder.

Launch `<id>`. The wrapper sets `COPILOT_HOME` and points `COPILOT_PROVIDERS_CONFIG` to a per-launch file under `~/.legion/temp/`. This is the approved exception to the no-token-storage rule: Copilot's provider file holds a **fixed bearer token**. The runner creates it with access restricted to the current Windows user, or mode `0600` on other platforms, before writing the token. It deletes the file in `finally` when Copilot exits, including an error exit. Never read or log it.

Each Copilot Foundry launch also removes expired ps-ai provider files left by interrupted runs, using the exact token expiry recorded in their filenames. Fresh and unrelated files are preserved. No fixed token lifetime is assumed.

The runner prints `token valid until HH:mm; after that restart with: <id> --resume` in local time. The token does not refresh during that run. After expiry, exit and restart with `<id> --resume` in the same folder to obtain a fresh token. A missing CLI stops with `copilot is not installed; run ps-ai-install-tool.ps1 -Tool copilot`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `copilot` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
