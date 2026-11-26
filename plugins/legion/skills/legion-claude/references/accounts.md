# Claude Code accounts

Follow [owner notes](../../legion-personalisation/references/fields.md) before account, model or channel choices.
Add and adopt through `legion add`, as [create.md](../../legion-personalisation/references/create.md) describes. It suggests `claude<n>`, accepts a valid custom lowercase hyphenated id that is not a command on PATH, installs a missing `claude` CLI, creates the config folder, and installs legion, all before login. Setup also adds the allow rules from `allowRules` in `tool.json` to each account's `settings.json`, so the overseer can start members without a prompt. For a new folder only, the owner starts it with `legion --account <id>` (or chooses it in `legion pick`) in a repository to log in once; never handle tokens or credential files. Follow the [shared account rules](../../legion-personalisation/references/fields.md#account-setup).

[install.md](install.md) covers a CLI-only install the owner asks for. Register an existing account's program with `legion account register --id <id> --tool claude --command <path> --config-dir <dir>`; rename with `legion account rename --id <old> --new-id <new>`; remove with `legion account remove --id <id>`. They update channel bindings, keep the config folder and print its location. Ask before changing or deleting that folder.

## Foundry agent

Use this flow for a Foundry endpoint instead of the subscription login flow above. One agent uses one endpoint. Use `legion --home <home>` for an alternate home.

Use these commands for a Foundry provider configuration request. Ordinary setup can adopt an existing folder and keep its provider settings. For Foundry only, ask “Standard mapping or choose deployments yourself?” Reuse choices already supplied. Follow [Foundry model mapping](../../legion-personalisation/references/foundry-models.md) for discovery, `--standard` and unresolved aliases. These examples show explicit choices:

```powershell
legion account add --id <id> --tool claude --provider foundry --endpoint https://<resource>.cognitiveservices.azure.com --deployment claude-opus-x --deployment claude-sonnet-x --default claude-opus-x --alias claude-opus-x=opus --alias claude-sonnet-x=sonnet
```

Aliases are optional: `opus`, `sonnet`, `haiku`, or `fable`, each used once. The default must be a selected deployment name. Add writes the provider entry, and `modelPicker` in the account's `settings.json`. Other settings remain. Invalid JSON stops with `settings.json is not valid JSON; fix or remove it`. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For a requested provider configuration change, reuse the supplied settings and apply the complete replacement with:

```powershell
legion account models --id <id> --deployment claude-opus-x --deployment claude-sonnet-x --default claude-opus-x --alias claude-opus-x=opus --alias claude-sonnet-x=sonnet
```

`models` replaces the full deployment list. Omit `--alias` to keep aliases for retained names; pass `--alias ''` to clear them. An unchanged result prints `skip: models <id> (no changes)` and writes nothing. Then run `legion setup` and show the owner its plan. It covers every known account, not only this one, so ask for the owner's one yes and run it again with `--yes` to install legion wherever it is missing.

Start it with `legion --account <id>` or `legion pick`. Legion sets `CLAUDE_CONFIG_DIR`, the Foundry endpoint, default, and alias variables. Claude uses its own Azure token refresh. Pass a model flag only when owner notes name a model or allow a tier for the run; follow [Foundry routing](../../legion-overseer/references/task-loop.md#foundry-runs). Keep the same agent and endpoint when resuming. A missing CLI stops with `claude is not installed; run legion tool install --tool claude`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `claude` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
