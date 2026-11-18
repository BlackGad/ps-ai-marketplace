# Foundry work-PC checklist

Run these checks manually on a work PC. This file records steps, not a completed live test. Use PowerShell 7 from the repository root. Replace the endpoint and generic deployment names with the owner's values locally. Keep organisation details and tokens out of committed reports.

## Prerequisites

- [ ] Read personalisation and notes. Choose unused ids such as `claude-dev`, `copilot-dev`, and `codex-dev`.
- [ ] Check `pwsh`, `az`, and the target CLI are installed. For a missing tool, preview `pwsh -NoProfile -File plugins/ps-ai/bin/ps-ai-install-tool.ps1 -Tool az` (substitute the tool). Ask before adding `-Yes`.
- [ ] On Windows, verify the helper accepts `-Method winget`, `-Method msi`, or `-Method zip`. Missing or failed winget prints the two alternatives and exits 2. Ask for a method before an approved install. MSI/EXE may need admin; ZIP uses user PATH. Claude and Codex use official scripts for `msi` and `zip`; Copilot uses npm when Node is present. See [tools.md](../../plugins/ps-ai/skills/ps-ai-repository/references/tools.md).
- [ ] Check token success without showing a token: `az account get-access-token --resource https://cognitiveservices.azure.com -o none`. Add, discovery, and launch run interactive `az login` once on token failure. A token alone does not prove deployment access.
- [ ] Use an endpoint such as `https://<resource>.cognitiveservices.azure.com`. One agent uses one endpoint. For a test home, pass `-HomeRoot <home>` to account commands and invoke the source runner with `-HomeRoot <home>`; generated wrappers use the normal home.

## Claude: add, launch, and models

First list in PowerShell 7:

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action add -Tool claude -Id claude-dev -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -List
```

- [ ] Confirm `source`, `error`, and the deployment rows. Add lists only `new`. Only models starting with `claude` should appear.
- [ ] If discovery fails or is empty, ask for names from `https://ai.azure.com` → your project → Models + endpoints. Do not infer removal from failure.
- [ ] Present `new`, `gone`, and `kept`. Ask which deployments to keep, aliases, and default. Wait for the owner's answer before running the write below. Substitute the approved values.

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action add -Tool claude -Id claude-dev -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-sonnet-x=sonnet')
```

- [ ] Confirm personalisation holds only the endpoint base. If the pasted URL had `/anthropic/`, confirm that path was trimmed. Confirm wrappers exist under `~/.agents/bin/` and roles start empty.
- [ ] Confirm `~/.agents/accounts/claude-dev/settings.json` has the selected `modelPicker` options and retains unrelated settings. Invalid JSON must stop with `settings.json is not valid JSON; fix or remove it`.
- [ ] Validate after each write: `pwsh -NoProfile -File plugins/ps-ai/bin/ps-ai-validate.ps1 -Kind personalisation -Path "$HOME/.agents/configuration/ps-ai-personalisation.json"`.
- [ ] Repeat the approved add. Expect `skip: account claude-dev (already done)`.
- [ ] Install ps-ai for the account: `pwsh -NoProfile -File install/install.ps1 -Tools claude -ConfigDir "$HOME/.agents/accounts/claude-dev"`.
- [ ] Launch `claude-dev` in a terminal and request a short reply. Confirm it uses Azure login, the selected endpoint, and the default deployment.
- [ ] Open `/model`. Confirm the configured deployment choices work. Check `claude-dev -p --model sonnet "Reply with OK"` when the `sonnet` alias is mapped.

To update, list first:

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action models -Id claude-dev -List
```

- [ ] With management read available, compare `new`, `gone`, and `kept` with Azure and the saved list. If the read fails, `source` is `none` and existing names stay `kept`.
- [ ] Present the groups. Ask for additions, removals, aliases, and default. Wait for the owner's answer. If dropping the default, choose a remaining deployment.

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action models -Id claude-dev -Deployments @('claude-opus-x','claude-haiku-x') -Default claude-opus-x -Aliases @('claude-opus-x=opus','claude-haiku-x=haiku')
```

- [ ] Confirm the full list and picker were replaced with the approved selection. Omitted `-Aliases` keeps aliases on retained names; `-Aliases @()` clears them. Validate, relaunch, and check `/model`.
- [ ] Repeat the identical update. Expect `skip: models claude-dev (no changes)` and unchanged files.

## Copilot: Claude deployments and expiry

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action add -Tool copilot -Id copilot-dev -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -List
```

- [ ] Confirm only Claude deployments appear. Copilot GPT deployments are out of scope.
- [ ] Present `new`, `gone`, and `kept`, ask which Claude deployments and default to save, and wait for the owner's answer. Copilot has no alias mappings.

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action add -Tool copilot -Id copilot-dev -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('claude-opus-x','claude-sonnet-x') -Default claude-opus-x
```

- [ ] Validate personalisation. Install ps-ai with `pwsh -NoProfile -File install/install.ps1 -Tools copilot -ConfigDir "$HOME/.agents/accounts/copilot-dev"`.
- [ ] Launch `copilot-dev`, select a Claude deployment, and request a short reply. The runner stores but does not select `provider.default`.
- [ ] Confirm the local-time notice: `token valid until HH:mm; after that restart with: copilot-dev --resume`.
- [ ] Confirm a providers file exists under `~/.agents/temp/` during the run by checking its filename only. Do not open, copy, or log its contents. It holds a fixed bearer token.
- [ ] Keep the session until expiry. Confirm it needs a fresh token. Exit, then run `copilot-dev --resume` in the same folder. Confirm a later expiry and a successful reply.
- [ ] After normal exit, confirm that run's providers file is deleted. Repeat with an error exit and confirm cleanup and the returned tool exit code.
- [ ] For a model update, run `-Action models -Id copilot-dev -List`, present the groups, ask, then run `-Action models -Id copilot-dev -Deployments @('claude-opus-x') -Default claude-opus-x` only after the answer. Validate afterwards.

## Codex: when GPT access exists

Codex is **not yet proven against Foundry**. Leave these checks pending until a GPT deployment is accessible.

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action add -Tool codex -Id codex-dev -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -List
```

- [ ] Confirm only models starting with `gpt` appear. Present `new`, `gone`, and `kept`, ask which names and default to save, and wait for the owner's answer.

```powershell
& ./plugins/ps-ai/bin/ps-ai-account.ps1 -Action add -Tool codex -Id codex-dev -Provider foundry -Endpoint "https://<resource>.cognitiveservices.azure.com" -Deployments @('gpt-x') -Default gpt-x
```

- [ ] Validate. Confirm `config.toml` preserves unrelated keys and sets `model_provider = "ps-ai-foundry"`, `base_url = "https://<resource>.cognitiveservices.azure.com/openai/v1"`, and `wire_api = "responses"`. Auth must use the full `az` path, the cognitive-services resource, and `refresh_interval_ms = 1800000`.
- [ ] Install ps-ai with `pwsh -NoProfile -File install/install.ps1 -Tools codex -ConfigDir "$HOME/.agents/accounts/codex-dev"`. Launch `codex-dev` and request a short GPT reply. Record success or the exact error without tokens or organisation details.
- [ ] For updates, run `-Action models -Id codex-dev -List`, present the groups, ask, then pass the full approved `-Deployments` and `-Default`. Validate afterwards.

## Diagnostic probe

The probe never logs in or changes persistent settings. It reads Azure metadata and makes tiny inference requests for supplied or discovered deployments even without `-Ping`. It prints resource, subscription, and tenant details, so keep raw output local. `-Ping` also starts installed coding CLIs; run it only when authorized.

```powershell
pwsh -NoProfile -File tools/foundry-probe.ps1 -Endpoint "https://<resource>.cognitiveservices.azure.com" -ClaudeDeployment claude-opus-x
pwsh -NoProfile -File tools/foundry-probe.ps1 -Endpoint "https://<resource>.cognitiveservices.azure.com" -ClaudeDeployment claude-opus-x -GptDeployment gpt-x -Ping
```

- [ ] Compare token, management discovery, endpoint reads, and inference results. Endpoint-list permission errors do not prove inference is unavailable.
- [ ] Use `-GptDeployment` only when GPT access exists. The probe's Copilot GPT checks are diagnostic; they do not enable Copilot Foundry GPT support.
- [ ] Note that the probe caps other-subscription searches at 20; the plugin helper searches the login's subscription list. Probe Copilot pings use environment variables, while the runner uses a per-launch providers file.
- [ ] Repeat under the relevant Azure login states: missing or invalid login, login without deployment access, and working access. Change login as the owner; the probe does not do it.
- [ ] Record sanitized results locally. The fresh-agent skill check and its `2026-11-18-foundry-skills.md` report belong to the orchestrator's separate Task 6 step 4.
