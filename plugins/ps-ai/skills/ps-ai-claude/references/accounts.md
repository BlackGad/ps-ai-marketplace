# Claude Code accounts

Use the plugin's existing `bin/ps-ai-account.ps1` and the marketplace's remote `install.ps1` with PowerShell 7. Read account IDs from personalisation, suggest `claude<n>` (the next unused number), and accept a valid custom lowercase hyphenated ID. The account script rejects duplicate IDs and command names on PATH.

If `claude` is missing, follow [install.md](install.md) first. Continue with account setup only after the CLI is available.

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-account.ps1 -Action add -Tool claude -Id <id> [-HomeRoot <home>]
```

This creates a wrapper that sets `CLAUDE_CONFIG_DIR`, a config folder, and the personalisation entry. Tell the owner to run `<id>` in a terminal and log in once; never handle tokens or open credential files. Then install ps-ai for that account:

```text
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools claude -ConfigDir <home>/.agents/accounts/<id>
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.agents/configuration/ps-ai-personalisation.json
```

For an existing wrapper, use `-Action register -Id <id> -Tool claude -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`; do not recreate its login. Rename with `-Action rename -Id <old> -NewId <new>`, or remove with `-Action remove -Id <id>`, then validate. The script updates global and project routing references, keeps the config folder, and prints its location. Do not rename or delete that folder without the owner's explicit choice.

## Foundry agent

Use this flow for a Foundry endpoint instead of the subscription login flow above. One agent uses one endpoint. Run these commands in PowerShell 7; use `-HomeRoot <home>` for an alternate home.

First discover without writing agent files:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool claude -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -List
```

The script checks the Azure token and runs interactive `az login` once if needed. It trims any endpoint path and trailing slash. Discovery checks the current subscription, then the login's other subscriptions. Claude sees deployments whose model starts with `claude`.

Present the JSON `source`, `error`, and deployments grouped as `new`, `gone`, and `kept`. Add lists only `new`. If discovery fails or finds no usable deployments, ask the owner to paste names from `https://ai.azure.com` → your project → Models + endpoints. A failed management read is not evidence that a deployment is gone.

Ask which deployments to keep, which Claude aliases to assign, and which deployment is the default. Show the proposed selection and wait for the owner's answer before running `add` without `-List`. The script does not ask for approval itself. After approval, pass the agreed values; these names are examples:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool claude -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-sonnet-x=sonnet')
```

Aliases are optional: `opus`, `sonnet`, `haiku`, or `fable`, each used once. The default must be a selected deployment name. Add writes the provider entry with empty roles, the wrappers, and `modelPicker` in the account's `settings.json`. Other settings remain. Invalid JSON stops with `settings.json is not valid JSON; fix or remove it`. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For "update models for <id>", first list without writing:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -List
```

Show `new`, `gone`, and `kept`. `source: none` keeps existing deployments as `kept`; show the error and ask for names instead of dropping them. Ask which names to add or drop, which aliases to keep or change, and the default. Wait for the owner's answer before writing:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-sonnet-x=sonnet')
```

`models` replaces the full deployment list. Omit `-Aliases` to keep aliases for retained names; pass `-Aliases @()` to clear them. An unchanged result prints `skip: models <id> (no changes)` and writes nothing. Validate personalisation after a write with the command above. Install ps-ai into this account's config folder with the installer command above.

Launch `<id>` in a terminal. The wrapper uses `CLAUDE_CONFIG_DIR`, the Foundry endpoint, default, and alias variables. Claude uses its own Azure token refresh. Use `/model` to select a configured deployment; an alias can be passed as `--model sonnet` when mapped. Keep the same agent and endpoint when resuming. A missing CLI stops with `claude is not installed; run ps-ai-install-tool.ps1 -Tool claude`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `claude` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
