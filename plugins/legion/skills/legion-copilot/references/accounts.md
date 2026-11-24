# Copilot CLI accounts

Follow [owner notes](../../legion-personalisation/references/fields.md) before account, model or channel choices.
Add and adopt through `legion-setup.ps1`, as [create.md](../../legion-personalisation/references/create.md) describes. It suggests `copilot<n>`, accepts a valid custom lowercase hyphenated id that is not a command on PATH, installs a missing `copilot` CLI, creates the wrapper and config folder, and installs legion, all before login. For a new folder only, the owner runs `<id>` in a terminal to log in once; never handle tokens or credential files. Follow the [shared account rules](../../legion-personalisation/references/fields.md#account-setup).

[install.md](install.md) covers a CLI-only install the owner asks for. Register an existing account's program with `legion account register --id <id> --tool copilot --command <path> --config-dir <dir>`; rename with `legion account rename --id <old> --new-id <new>`; remove with `legion account remove --id <id>`. They update channel bindings, keep the config folder and print its location. Ask before changing or deleting that folder.

## Foundry agent

Use this flow instead of the subscription login flow above. One agent uses one endpoint. Copilot Foundry agents support **Claude deployments only**. GPT deployments are out of scope. Use `legion --home <home>` for an alternate home.

Use these commands for a Foundry provider configuration request. Ordinary setup can adopt an existing folder and keep its provider settings. For Foundry only, ask “Standard mapping or choose deployments yourself?” Reuse choices already supplied. Follow [Foundry model mapping](../../legion-personalisation/references/foundry-models.md) for discovery, `-Standard` and unresolved aliases. These examples show explicit choices:

```powershell
legion account add --id <id> --tool copilot --provider foundry --endpoint https://<resource>.cognitiveservices.azure.com --deployment claude-opus-x --deployment claude-sonnet-x --default claude-opus-x
```

Add writes the provider entry and the wrappers. It writes no persistent Copilot provider config. The provider default must name a configured deployment. The runner leaves run-time model selection to the account's CLI default unless owner notes name a model or allow a tier; follow [Foundry routing](../../legion-overseer/references/task-loop.md#foundry-runs). Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For a requested provider configuration change, reuse the supplied settings and apply the complete replacement with:

```powershell
legion account models --id <id> --deployment claude-opus-x --deployment claude-sonnet-x --default claude-opus-x
```

An identical result prints `skip: models <id> (no changes)` and writes nothing. Then run `legion-setup.ps1` and show the owner its plan. It covers every known account, not only this one, so ask for the owner's one yes and run it again with `-Yes` to install legion wherever it is missing.

Launch `<id>`. The wrapper sets `COPILOT_HOME` and points `COPILOT_PROVIDERS_CONFIG` to a per-launch file under `~/.legion/temp/`. This is the approved exception to the no-token-storage rule: Copilot's provider file holds a **fixed bearer token**. The runner creates it with the user profile's Windows permissions, or mode `0600` on other platforms, before writing the token. It deletes the file in `finally` when Copilot exits, including an error exit. Never read or log it.

Each Copilot Foundry launch also removes expired legion provider files left by interrupted runs, using the exact token expiry recorded in their filenames. Fresh and unrelated files are preserved. No fixed token lifetime is assumed.

The runner prints `token valid until HH:mm; after that restart with: <id> --resume` in local time. The token does not refresh during that run. After expiry, exit and restart with `<id> --resume` in the same folder to obtain a fresh token. A missing CLI stops with `copilot is not installed; run legion-install-tool.ps1 -Tool copilot`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `copilot` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
