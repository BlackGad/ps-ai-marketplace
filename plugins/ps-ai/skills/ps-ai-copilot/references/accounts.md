# Copilot CLI accounts

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.
Use `bin/ps-ai-account.ps1` from the plugin. Read existing IDs, suggest `copilot<n>` (next unused number), and accept a valid custom lowercase hyphenated ID. The script rejects collisions.

If `copilot` is missing, follow [install.md](install.md) first. Continue with account setup only after the CLI is available.

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-account.ps1 -Action add -Tool copilot -Id <id> [-ConfigDir <existing folder>] [-HomeRoot <home>]
```

This creates a wrapper that sets `COPILOT_HOME`, the account config folder, and the personalisation entry. Make sure `<home>/.legion/bin` is on the user PATH (add it once if missing; never in tests). For a new folder only, tell the owner to run `<id>` in a terminal and log in once; never handle credentials. Then install and validate:

```text
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools copilot -ConfigDir <account folder> -Yes
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.legion/configuration/ps-ai-personalisation.json
```

To check from the system temp folder, run `copilot plugin list` with `COPILOT_HOME` set to the account's recorded folder (never guess paths); ps-ai is installed when `ps-ai@ps-ai-marketplace` is listed and enabled.

To adopt a signed-in folder, pass `-ConfigDir <existing folder>` to `add`. For an adopted or registered folder, add `-Update` to the installer command: it installs ps-ai if missing and otherwise brings an older copy current, which a plain install reports as already done. Follow the [shared account rules](../../ps-ai-personalisation/references/fields.md#account-setup) for retained logins, installation approval and incomplete work.

Register an existing wrapper with `-Action register -Id <id> -Tool copilot -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`. Rename with `-Action rename -Id <old> -NewId <new>`, or remove with `-Action remove -Id <id>`, then validate. Exact channel account bindings are updated; the script keeps and reports the config folder. Ask before changing or deleting that folder.

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

An identical result prints `skip: models <id> (no changes)` and writes nothing. Validate personalisation and install ps-ai into the account config folder with the commands above.

Launch `<id>`. The wrapper sets `COPILOT_HOME` and points `COPILOT_PROVIDERS_CONFIG` to a per-launch file under `~/.legion/temp/`. This is the approved exception to the no-token-storage rule: Copilot's provider file holds a **fixed bearer token**. The runner creates it with access restricted to the current Windows user, or mode `0600` on other platforms, before writing the token. It deletes the file in `finally` when Copilot exits, including an error exit. Never read or log it.

Each Copilot Foundry launch also removes expired ps-ai provider files left by interrupted runs, using the exact token expiry recorded in their filenames. Fresh and unrelated files are preserved. No fixed token lifetime is assumed.

The runner prints `token valid until HH:mm; after that restart with: <id> --resume` in local time. The token does not refresh during that run. After expiry, exit and restart with `<id> --resume` in the same folder to obtain a fresh token. A missing CLI stops with `copilot is not installed; run ps-ai-install-tool.ps1 -Tool copilot`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `copilot` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
