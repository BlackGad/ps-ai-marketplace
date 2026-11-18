# Codex CLI accounts

Use the plugin's `bin/ps-ai-account.ps1`. Read existing IDs, suggest `codex<n>` (next unused number), and accept a custom valid ID such as `codex-client`. Do not put a client name into a wiki label. The script rejects duplicate IDs and command names on PATH.

If `codex` is missing, follow [install.md](install.md) first. Continue with account setup only after the CLI is available.

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-account.ps1 -Action add -Tool codex -Id <id> [-HomeRoot <home>]
```

This creates the `CODEX_HOME` wrapper, config folder, and personalisation entry. Tell the owner to run `<id>` in a terminal and log in once; never read tokens. Then install ps-ai into that account's config folder and validate:

```text
pwsh -NoProfile -File <marketplace>/install/install.ps1 -Tools codex -ConfigDir <home>/.agents/accounts/<id>
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.agents/configuration/ps-ai-personalisation.json
```

Register an existing wrapper with `-Action register -Id <id> -Tool codex -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`. Rename with `-Action rename -Id <old> -NewId <new>`, or remove with `-Action remove -Id <id>`, then validate. The script updates global and project routing, keeps the config folder, and prints its location. Ask before changing or deleting that folder.

## Foundry agent

Codex is **not yet proven against Foundry**. Use this flow when GPT access exists and the owner wants to verify it. It replaces the subscription login flow above. One agent uses one endpoint. Run the commands in PowerShell 7; pass `-HomeRoot <home>` for an alternate home.

First discover without writing agent files:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool codex -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -List
```

The script checks the Azure token and runs interactive `az login` once if needed. It trims endpoint paths and trailing slashes. Discovery checks the current subscription, then other subscriptions, and filters model names to `gpt`.

Present the JSON `source`, `error`, and `new`, `gone`, `kept` groups. Add has only `new`. If discovery fails or finds no usable deployments, ask for names from `https://ai.azure.com` → your project → Models + endpoints. A failed read does not show that a deployment is gone.

Ask which GPT deployments to keep and which is the default. Aliases are for Claude agents only. Show the selection and wait for the owner's answer before `add` without `-List`; the script does not ask for approval. Then pass the approved values:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool codex -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('gpt-x') -Default gpt-x
```

Add writes the provider entry with empty roles, wrappers, and the account's `config.toml`. It sets `model`, `model_provider = "ps-ai-foundry"`, `/openai/v1` as the endpoint path, and `wire_api = "responses"`. The auth command uses the full `az` path and the cognitive-services token resource, with `refresh_interval_ms = 1800000`. Other config keys remain. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For "update models for <id>", first list without writing:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -List
```

Show `new`, `gone`, and `kept`. With `source: none`, existing deployments remain `kept`; show the error and ask for names. Ask which names to add or drop and which is the default. Wait for the owner's answer before writing the complete replacement list:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -Deployments @('gpt-x') -Default gpt-x
```

The default must be selected. An identical result prints `skip: models <id> (no changes)` and writes nothing. Validate personalisation and install ps-ai into this account's config folder with the commands above.

Launch `<id>` in a terminal. The wrapper sets `CODEX_HOME`; the provider config supplies the endpoint and token command. Resume only with the same agent and folder. A missing CLI stops with `codex is not installed; run ps-ai-install-tool.ps1 -Tool codex`. Verify an actual GPT response before reporting this path as working.
