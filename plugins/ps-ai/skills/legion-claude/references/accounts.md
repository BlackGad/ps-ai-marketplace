# Claude Code accounts

Follow [owner notes](../../legion-personalisation/references/fields.md) before account, model or channel choices.
Add and adopt through `legion-setup.ps1`, as [create.md](../../legion-personalisation/references/create.md) describes. It suggests `claude<n>`, accepts a valid custom lowercase hyphenated id that is not a command on PATH, installs a missing `claude` CLI, creates the wrapper and config folder, and installs ps-ai, all before login. For a new folder only, the owner runs `<id>` in a terminal to log in once; never handle tokens or credential files. Follow the [shared account rules](../../legion-personalisation/references/fields.md#account-setup).

[install.md](install.md) covers a CLI-only install the owner asks for. Register an existing wrapper with `-Action register -Id <id> -Tool claude -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`; rename with `-Action rename -Id <old> -NewId <new>`; remove with `-Action remove -Id <id>`. These use `bin/legion-account.ps1`; they update channel bindings, keep the config folder and print its location. Ask before changing or deleting that folder.

## Foundry agent

Use this flow for a Foundry endpoint instead of the subscription login flow above. One agent uses one endpoint. Run these commands in PowerShell 7; use `-HomeRoot <home>` for an alternate home.

Use these commands for a Foundry provider configuration request. Ordinary setup can adopt an existing folder and keep its provider settings. For Foundry only, ask “Standard mapping or choose deployments yourself?” Reuse choices already supplied. Follow [Foundry model mapping](../../legion-personalisation/references/foundry-models.md) for discovery, `-Standard` and unresolved aliases. These examples show explicit choices:

```powershell
& "<plugin>/bin/legion-account.ps1" -Action add -Tool claude -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-sonnet-x=sonnet')
```

Aliases are optional: `opus`, `sonnet`, `haiku`, or `fable`, each used once. The default must be a selected deployment name. Add writes the provider entry with the wrappers, and `modelPicker` in the account's `settings.json`. Other settings remain. Invalid JSON stops with `settings.json is not valid JSON; fix or remove it`. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For a requested provider configuration change, reuse the supplied settings and apply the complete replacement with:

```powershell
& "<plugin>/bin/legion-account.ps1" -Action models -Id '<id>' -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-sonnet-x=sonnet')
```

`models` replaces the full deployment list. Omit `-Aliases` to keep aliases for retained names; pass `-Aliases @()` to clear them. An unchanged result prints `skip: models <id> (no changes)` and writes nothing. Then run `legion-setup.ps1` and show the owner its plan. It covers every known account, not only this one, so ask for the owner's one yes and run it again with `-Yes` to install ps-ai wherever it is missing.

Launch `<id>` in a terminal. The wrapper uses `CLAUDE_CONFIG_DIR`, the Foundry endpoint, default, and alias variables. Claude uses its own Azure token refresh. Pass a model flag only when owner notes name a model or allow a tier for the run; follow [Foundry routing](../../legion-overseer/references/task-loop.md#foundry-runs). Keep the same agent and endpoint when resuming. A missing CLI stops with `claude is not installed; run legion-install-tool.ps1 -Tool claude`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `claude` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
