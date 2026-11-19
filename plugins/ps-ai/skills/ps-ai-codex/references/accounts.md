# Codex CLI accounts

Follow [owner notes](../../ps-ai-personalisation/references/fields.md) before account, model or channel choices.
Use the plugin's `bin/ps-ai-account.ps1`. Read existing IDs, suggest `codex<n>` (next unused number), and accept a custom valid ID such as `codex-client`. Do not put a client name into a wiki label. The script rejects duplicate IDs and command names on PATH.

If `codex` is missing, follow [install.md](install.md) first. Continue with account setup only after the CLI is available.

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-account.ps1 -Action add -Tool codex -Id <id> [-ConfigDir <existing folder>] [-HomeRoot <home>]
```

This creates the `CODEX_HOME` wrapper, config folder, and personalisation entry. Make sure `<home>/.legion/bin` is on the user PATH (add it once if missing; never in tests). For a new folder only, tell the owner to run `<id>` in a terminal and log in once; never read tokens. Then install ps-ai into that account's config folder and validate:

```text
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools codex -ConfigDir <account folder> -Yes
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.legion/configuration/ps-ai-personalisation.json
```

To check from the system temp folder, run `codex plugin list` with `CODEX_HOME` set to the account's recorded folder (never guess paths); ps-ai is installed when `ps-ai@ps-ai-marketplace` is listed and enabled.

To adopt a signed-in folder, pass `-ConfigDir <existing folder>` to `add`. Follow the [shared account rules](../../ps-ai-personalisation/references/fields.md#account-setup) for retained logins, installation approval and incomplete work.

Register an existing wrapper with `-Action register -Id <id> -Tool codex -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`. Rename with `-Action rename -Id <old> -NewId <new>`, or remove with `-Action remove -Id <id>`, then validate. The script updates exact channel account bindings, keeps the config folder, and prints its location. Ask before changing or deleting that folder.

## Foundry agent

Codex is **not yet proven against Foundry**. Use this flow when GPT access exists and the owner wants to verify it. It replaces the subscription login flow above. One agent uses one endpoint. Run the commands in PowerShell 7; pass `-HomeRoot <home>` for an alternate home.

Use these commands for a Foundry provider configuration request. Ordinary setup can adopt an existing folder and keep its provider settings. For Foundry only, ask “Standard mapping or choose deployments yourself?” Reuse choices already supplied. Follow [Foundry model mapping](../../ps-ai-personalisation/references/foundry-models.md) for discovery, `-Standard` and unresolved aliases. These examples show explicit choices:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool codex -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('gpt-x') -Default gpt-x
```

Add writes the provider entry with wrappers, and the account's `config.toml`. It sets `model`, `model_provider = "ps-ai-foundry"`, `/openai/v1` as the endpoint path, and `wire_api = "responses"`. The auth command uses the full `az` path and the cognitive-services token resource, with `refresh_interval_ms = 1800000`. Other config keys remain. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For a requested provider configuration change, reuse the supplied settings and apply the complete replacement with:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -Deployments @('gpt-x') -Default gpt-x
```

The default must be selected. An identical result prints `skip: models <id> (no changes)` and writes nothing. Validate personalisation and install ps-ai into this account's config folder with the commands above.

Launch `<id>` in a terminal. The wrapper sets `CODEX_HOME`; the provider config supplies the endpoint and token command. Resume only with the same agent and folder. A missing CLI stops with `codex is not installed; run ps-ai-install-tool.ps1 -Tool codex`. Verify an actual GPT response before reporting this path as working.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `codex` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
