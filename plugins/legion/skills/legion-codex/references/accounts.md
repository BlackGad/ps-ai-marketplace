# Codex CLI accounts

Follow [owner notes](../../legion-personalisation/references/fields.md) before account, model or channel choices.
Add and adopt through `legion-setup.ps1`, as [create.md](../../legion-personalisation/references/create.md) describes. It suggests `codex<n>`, accepts a valid custom lowercase hyphenated id that is not a command on PATH, installs a missing `codex` CLI, creates the wrapper and config folder, and installs legion, all before login. For a new folder only, the owner runs `<id>` in a terminal to log in once; never handle tokens or credential files. Follow the [shared account rules](../../legion-personalisation/references/fields.md#account-setup).

[install.md](install.md) covers a CLI-only install the owner asks for. Register an existing wrapper with `-Action register -Id <id> -Tool codex -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`; rename with `-Action rename -Id <old> -NewId <new>`; remove with `-Action remove -Id <id>`. These use `bin/legion-account.ps1`; they update channel bindings, keep the config folder and print its location. Ask before changing or deleting that folder.

## Foundry agent

Codex is **not yet proven against Foundry**. Use this flow when GPT access exists and the owner wants to verify it. It replaces the subscription login flow above. One agent uses one endpoint. Run the commands in PowerShell 7; pass `-HomeRoot <home>` for an alternate home.

Use these commands for a Foundry provider configuration request. Ordinary setup can adopt an existing folder and keep its provider settings. For Foundry only, ask “Standard mapping or choose deployments yourself?” Reuse choices already supplied. Follow [Foundry model mapping](../../legion-personalisation/references/foundry-models.md) for discovery, `-Standard` and unresolved aliases. These examples show explicit choices:

```powershell
& "<plugin>/bin/legion-account.ps1" -Action add -Tool codex -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('gpt-x') -Default gpt-x
```

Add writes the provider entry with wrappers, and the account's `config.toml`. It sets `model`, `model_provider = "legion-foundry"`, `/openai/v1` as the endpoint path, and `wire_api = "responses"`. The auth command uses the full `az` path and the cognitive-services token resource, with `refresh_interval_ms = 1800000`. Other config keys remain. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For a requested provider configuration change, reuse the supplied settings and apply the complete replacement with:

```powershell
& "<plugin>/bin/legion-account.ps1" -Action models -Id '<id>' -Deployments @('gpt-x') -Default gpt-x
```

The default must be selected. An identical result prints `skip: models <id> (no changes)` and writes nothing. Then run `legion-setup.ps1` and show the owner its plan. It covers every known account, not only this one, so ask for the owner's one yes and run it again with `-Yes` to install legion wherever it is missing.

Launch `<id>` in a terminal. The wrapper sets `CODEX_HOME`; the provider config supplies the endpoint and token command. Resume only with the same agent and folder. A missing CLI stops with `codex is not installed; run legion-install-tool.ps1 -Tool codex`. Verify an actual GPT response before reporting this path as working.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `codex` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
