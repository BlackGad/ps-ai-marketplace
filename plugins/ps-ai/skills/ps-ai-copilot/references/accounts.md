# Copilot CLI accounts

Use `bin/ps-ai-account.ps1` from the plugin. Read existing IDs, suggest `copilot<n>` (next unused number), and accept a valid custom lowercase hyphenated ID. The script rejects collisions.

If `copilot` is missing, follow [install.md](install.md) first. Continue with account setup only after the CLI is available.

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-account.ps1 -Action add -Tool copilot -Id <id> [-HomeRoot <home>]
```

This creates a wrapper that sets `COPILOT_HOME`, the account config folder, and the personalisation entry. Tell the owner to run `<id>` in a terminal and log in once; never handle credentials. Then install and validate:

```text
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools copilot -ConfigDir <home>/.agents/accounts/<id>
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.agents/configuration/ps-ai-personalisation.json
```

Register an existing wrapper with `-Action register -Id <id> -Tool copilot -Command <wrapper> -ConfigDir <dir> -HomeRoot <home>`. Rename with `-Action rename -Id <old> -NewId <new>`, or remove with `-Action remove -Id <id>`, then validate. Global and project routing references are updated; the script keeps and reports the config folder. Ask before changing or deleting that folder.

## Foundry agent

Use this flow instead of the subscription login flow above. One agent uses one endpoint. Copilot Foundry agents support **Claude deployments only**. GPT deployments are out of scope. Run these commands in PowerShell 7; pass `-HomeRoot <home>` for an alternate home.

First discover without writing agent files:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool copilot -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -List
```

The script checks the Azure token and runs interactive `az login` once if needed. It trims endpoint paths and trailing slashes. Discovery checks the current subscription, then other subscriptions, and filters model names to `claude`.

Present the JSON `source`, `error`, and `new`, `gone`, `kept` groups. Add has only `new`. If discovery fails or finds no usable deployments, ask for names from `https://ai.azure.com` → your project → Models + endpoints. Do not treat a failed read as evidence of removal.

Ask which Claude deployments to keep and which is the default. Copilot has no Claude alias mappings. Show the selection and wait for the owner's answer before `add` without `-List`; the script does not ask for approval. Then pass the approved values:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action add -Tool copilot -Id '<id>' -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x
```

Add writes the provider entry with empty roles and the wrappers. It writes no persistent Copilot provider config. The default must be selected, but the runner does not select it at launch; select the desired model in Copilot. Repeating the same id, tool, provider, and endpoint prints `skip: account <id> (already done)`.

For "update models for <id>", first list without writing:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -List
```

Show `new`, `gone`, and `kept`. With `source: none`, existing names remain `kept`; show the error and ask for names. Ask which deployments to add or drop and which is the default. Wait for the owner's answer before saving the complete replacement list:

```powershell
& "<plugin>/bin/ps-ai-account.ps1" -Action models -Id '<id>' -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x
```

An identical result prints `skip: models <id> (no changes)` and writes nothing. Validate personalisation and install ps-ai into the account config folder with the commands above.

Launch `<id>`. The wrapper sets `COPILOT_HOME` and points `COPILOT_PROVIDERS_CONFIG` to a per-launch file under `~/.agents/temp/`. This is the approved exception to the no-token-storage rule: Copilot's provider file holds a **fixed bearer token**. The runner creates it with access restricted to the current Windows user, or mode `0600` on other platforms, before writing the token. It deletes the file in `finally` when Copilot exits, including an error exit. Never read or log it.

Each Copilot Foundry launch also removes expired ps-ai provider files left by interrupted runs, using the exact token expiry recorded in their filenames. Fresh and unrelated files are preserved. No fixed token lifetime is assumed.

The runner prints `token valid until HH:mm; after that restart with: <id> --resume` in local time. The token does not refresh during that run. After expiry, exit and restart with `<id> --resume` in the same folder to obtain a fresh token. A missing CLI stops with `copilot is not installed; run ps-ai-install-tool.ps1 -Tool copilot`.

Account selection and launch-field examples are in [launcher.md](launcher.md). The base `copilot` executable may be the `command` for a separately named account such as `agent-a`; account ids must not shadow commands on PATH.
