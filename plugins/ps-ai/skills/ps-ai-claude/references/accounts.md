# Claude Code accounts

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.
Use the plugin's existing `bin/ps-ai-account.ps1` and the marketplace's remote `install.ps1` with PowerShell 7. Read account IDs from personalisation, suggest `claude<n>` (the next unused number), and accept a valid custom lowercase hyphenated ID. The account script rejects duplicate IDs and command names on PATH.

If `claude` is missing, follow [install.md](install.md) first. Continue with account setup only after the CLI is available.

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-account.ps1 -Action add -Tool claude -Id <id> [-ConfigDir <existing folder>] [-HomeRoot <home>]
```

This creates a wrapper that sets `CLAUDE_CONFIG_DIR`, a config folder, and the personalisation entry. For a new folder only, tell the owner to run `<id>` in a terminal and log in once; never handle tokens or open credential files. Then install ps-ai for that account:

```text
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools claude -ConfigDir <account folder> -Yes
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.agents/configuration/ps-ai-personalisation.json
```

To check from the system temp folder, run `claude plugin list --json` with `CLAUDE_CONFIG_DIR` set to the account's recorded folder (never guess paths); ps-ai is installed when `ps-ai@ps-ai-marketplace` is listed and enabled.

To adopt a signed-in folder, pass `-ConfigDir <existing folder>` to `add`. Follow the [shared account rules](../../ps-ai-personalisation/references/fields.md#account-setup) for retained logins, installation approval and incomplete work.

For an existing wrapper, use `-Action register -Id <id> -Tool claude -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`; do not recreate its login. Rename with `-Action rename -Id <old> -NewId <new>`, or remove with `-Action remove -Id <id>`, then validate. The script updates exact channel account bindings, keeps the config folder, and prints its location. Do not rename or delete that folder without the owner's explicit choice.

## Foundry agent

Use this flow for a Foundry endpoint instead of the subscription login flow above. One agent uses one endpoint. Run these commands in PowerShell 7; use `-HomeRoot <home>` for an alternate home.

Use these commands only for an explicit Foundry provider configuration request. Ordinary setup can adopt an existing folder and keep its provider settings. Use the endpoint, deployments, default and any aliases already supplied by the owner. Do not discover models, present model lists or ask model questions. Leave a provider change unfinished if required values are missing. These example values stand for the owner-supplied provider settings:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool claude -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-sonnet-x=sonnet')
```

Aliases are optional: `opus`, `sonnet`, `haiku`, or `fable`, each used once. The default must be a selected deployment name. Add writes the provider entry with the wrappers, and `modelPicker` in the account's `settings.json`. Other settings remain. Invalid JSON stops with `settings.json is not valid JSON; fix or remove it`. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For a requested provider configuration change, reuse the supplied settings and apply the complete replacement with:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-sonnet-x=sonnet')
```

`models` replaces the full deployment list. Omit `-Aliases` to keep aliases for retained names; pass `-Aliases @()` to clear them. An unchanged result prints `skip: models <id> (no changes)` and writes nothing. Validate personalisation after a write with the command above. Install ps-ai into this account's config folder with the installer command above.

Launch `<id>` in a terminal. The wrapper uses `CLAUDE_CONFIG_DIR`, the Foundry endpoint, default, and alias variables. Claude uses its own Azure token refresh. Pass a model flag or mapped alias only when owner notes name one for the run. Keep the same agent and endpoint when resuming. A missing CLI stops with `claude is not installed; run ps-ai-install-tool.ps1 -Tool claude`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `claude` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
