# ps-ai: Azure Foundry agents and offline-friendly installs

Status: approved in conversation on 2026-11-18. Extends `2026-11-18-ps-ai-design.md`; every rule there still holds (every script is safe to run again, installs only after a yes, no secrets in files ps-ai keeps).

## 1. Goal

An agent can run on an Azure Foundry endpoint as well as on a subscription. The owner pastes the endpoint; ps-ai finds the deployments, generates the wrapper and keeps the model list easy to update. Several agents of one tool may differ by subscription or endpoint (`claude`, `claude-dev`, `claude-npd`).

The tool installer also works where winget is missing or blocked, from official vendor downloads.

## 2. Rules

- **One agent is one endpoint**, for every tool. Models switch inside the agent; endpoints never switch inside a session.
- **Azure access is only the `az` login.** ps-ai never checks account names, resources or permissions. Whatever the signed-in account can reach is what works.
- **No secrets at rest in ps-ai files.** Tokens come from `az account get-access-token --resource https://cognitiveservices.azure.com` at launch. The only file that holds a token is Copilot's per-launch provider file (section 6), deleted when Copilot exits.
- **Nothing organisation-specific in the plugin.** Endpoints and deployment names live only in the owner's personalisation.

## 3. Confirmed facts (probe on a work PC, 2026-11-18)

| Fact | Evidence |
| --- | --- |
| Management read (`az cognitiveservices account list` + `deployment list`) lists deployments with model names | worked with the right account, also when the resource was in another subscription than the current one |
| Endpoint read (`GET /openai/deployments`, `GET /openai/v1/models`) fails without extra data permissions | 401 `PermissionDenied` for every account tried |
| Expired, revoked or missing login fails at the token step | `AADSTS50173`, "No subscription found" |
| Anthropic endpoint `<endpoint>/anthropic/v1/messages` accepts `Authorization: Bearer <entra token>`, rejects `x-api-key` | 200 / 401 |
| Claude Code with `CLAUDE_CODE_USE_FOUNDRY=1` + `ANTHROPIC_FOUNDRY_BASE_URL` works and refreshes its own Azure token | `claude -p` answered |
| Claude alias mapping works (`ANTHROPIC_DEFAULT_SONNET_MODEL` + `--model sonnet`) | `claude -p --model sonnet` answered |
| Copilot `COPILOT_PROVIDER_API_KEY_COMMAND` with type `anthropic` sends `x-api-key` and fails | HTTP 401 from Copilot |
| Copilot type `anthropic` with a fixed bearer token works | `copilot -p` answered |
| Entra token lifetime | 64-89 minutes |
| Codex provider `[model_providers.<id>.auth]` command re-runs on an interval and after 401 (Codex 0.118+) | docs and openai/codex#16288; **not proven against Foundry** (no GPT permission on the probed endpoint) |

## 4. Personalisation

An agent entry gets an optional `provider` block. Without it the agent is a subscription agent, exactly as today.

```json
{
  "id": "claude-dev", "tool": "claude", "command": "~/.agents/bin/claude-dev",
  "configDir": "~/.agents/accounts/claude-dev", "roles": ["legion"],
  "provider": {
    "kind": "foundry",
    "endpoint": "https://<resource>.cognitiveservices.azure.com",
    "default": "claude-opus-5-5-2",
    "deployments": [
      { "name": "claude-opus-5-5-2", "model": "claude-opus-5-5", "alias": "opus" },
      { "name": "claude-sonnet-5-5", "model": "claude-sonnet-5-5", "alias": "sonnet" },
      { "name": "claude-haiku-5-5", "model": "claude-haiku-5-5", "alias": "haiku" }
    ]
  }
}
```

- `kind`: enum, only `foundry` now.
- `endpoint`: `https://` scheme and host only; ps-ai trims any path (`/anthropic`, `/openai/...`) and trailing slash the owner pastes.
- `deployments`: at least one; `name` unique; `model` optional (filled when the management read knows it); `alias` optional, one of `opus`, `sonnet`, `haiku`, `fable`, each alias used at most once, Claude agents only.
- `default`: must be one of the deployment names.
- Schema validation rejects a `provider` with any other shape; a semantic check enforces the alias, uniqueness and default rules.

## 5. Adding and updating

`ps-ai-account.ps1` gets two inputs and one action:

- `add -Id <id> -Tool <tool> -Provider foundry -Endpoint <url>`
- `models -Id <id>` (update the model list of an existing Foundry agent)

Both use one deployment-discovery helper:

1. `az` missing: stop with the installer hint (`ps-ai-install-tool.ps1 -Tool az`).
2. Token check (`az account get-access-token`). On failure run `az login` once (interactive), then check again; a second failure stops with the `az` error text.
3. Management read over every subscription of the login (`az account list`), matching the account whose name equals the endpoint's first host label. Result: deployment name + model name.
4. Tool filter: Claude and Copilot see deployments whose model name starts with `claude`; Codex sees `gpt`. Other models (embeddings, audio, rerank) never show.
5. If the read fails or finds nothing: ask the owner to paste deployment names, with the hint "https://ai.azure.com → your project → Models + endpoints".

`add` then asks which deployments to keep, their aliases (Claude) and the default; writes the entry; creates the wrapper (section 6). Running `add` again with the same id, tool, provider and endpoint prints `skip: account <id> (already done)`.

`models` shows three groups: **new** (in Azure, not in the agent), **gone** (in the agent, not in Azure; only when the management read worked) and **kept**. The owner adds, drops, re-aliases or picks a new default (required when the default is gone). It saves and regenerates the agent's files. No difference and no owner change prints `skip: models <id> (no changes)` and writes nothing.

The skill-facing interactive part (asking, picking) is done by the agent through the tool skills; the script takes the decisions as parameters (`-Deployments`, `-Default`, `-Aliases`) so it stays testable and non-interactive. A `-List` switch prints the discovery result as JSON for the agent to present.

`rename` and `remove` work unchanged on Foundry agents.

## 6. Wrapper and runner

`add` copies one shared runner to `~/.agents/bin/ps-ai-foundry.ps1` (overwritten only when its content differs) and writes the agent wrapper `~/.agents/bin/<id>` (sh) and `<id>.cmd`, which call `pwsh -NoProfile -File ~/.agents/bin/ps-ai-foundry.ps1 -Agent <id> <args>`. The runner reads personalisation for the agent, does the token check of section 5 step 2, and starts the tool with the tool's own config folder (`configDir`) and the variables below set for the child process only. It returns the tool's exit code and restores nothing global.

**Claude**
- Set `CLAUDE_CODE_USE_FOUNDRY=1`, `ANTHROPIC_FOUNDRY_BASE_URL=<endpoint>/anthropic`, `ANTHROPIC_MODEL=<default>`, `ANTHROPIC_DEFAULT_<ALIAS>_MODEL` per alias.
- Clear `ANTHROPIC_FOUNDRY_RESOURCE`, `ANTHROPIC_FOUNDRY_API_KEY`, `ANTHROPIC_FOUNDRY_AUTH_TOKEN`, `ANTHROPIC_SMALL_FAST_MODEL`, `CLAUDE_CODE_USE_BEDROCK`, `CLAUDE_CODE_USE_VERTEX`, `CLAUDE_CODE_USE_ANTHROPIC_AWS`, `CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD`, `CLAUDE_CODE_USE_MANTLE`, `CLAUDE_CODE_USE_GATEWAY`.
- `add`/`models` write `modelPicker` (`options`: one row per deployment, `replaceBuiltInOptions: true`) into `<configDir>/settings.json`, merging with any other keys already there.

**Copilot**
- Write a per-launch providers file in `~/.agents/temp/` (one provider, type `anthropic`, `baseUrl <endpoint>/anthropic`, `bearerToken`, header `anthropic-version: 2023-06-01`; one model per deployment), point `COPILOT_PROVIDERS_CONFIG` at it, delete it when Copilot exits (also on Ctrl+C, through `finally`).
- Print `token valid until HH:MM; after that restart with: <id> --resume`.
- Copilot GPT deployments through Foundry are out of scope until proven (probe result was inconclusive).

**Codex**
- `add`/`models` write `<configDir>/config.toml` keys `model`, `model_provider = "ps-ai-foundry"` and `[model_providers.ps-ai-foundry]` with `base_url = "<endpoint>/openai/v1"`, `wire_api = "responses"` and `[model_providers.ps-ai-foundry.auth]` (`command` = full `az` path, `args` = the token command with `--query accessToken -o tsv`, `refresh_interval_ms = 1800000`). Other keys in the file are kept.
- The Codex skill marks this path "not yet proven against Foundry".

## 7. Skills

- `ps-ai-claude`, `ps-ai-copilot`, `ps-ai-codex` `references/accounts.md`: a "Foundry agent" section: add, update models ("update models for <id>"), token expiry note (Copilot), limits check = token check.
- `references/limits.md`: Foundry agents have no subscription window; the check is `az account get-access-token` success.
- `ps-ai-personalisation` `references/fields.md`: the `provider` block.

## 8. Installer without winget

`ps-ai-install-tool.ps1` gets `-Method winget|msi|zip` (Windows only). Without it: winget when it is present and works; when winget is missing or exits with an error, the script asks the agent to ask the owner (prints both options and stops), unless `-Method` is given.

- **msi**: official MSI/EXE from the vendor, silent flags, needs admin. Git uses `/CURRENTUSER` (no admin).
- **zip**: official zip into `~/.agents/tools/<tool>/`, the tool's executable folder added to the user PATH (once). No admin.
- Every download is checked against the vendor's SHA-256 (GitHub release asset `digest`, Node `SHASUMS256.txt`, Claude `manifest.json`). A mismatch deletes the download and stops.
- Claude and Codex use their official `install.ps1` for both methods (no admin). Copilot prefers npm when Node is present.
- An installed tool is skipped as today.
- Download sources and silent flags are listed in `plugins/ps-ai/skills/ps-ai-repository/references/tools.md`; entries not yet verified (glab flags, glab and Copilot zip layout, MSI per-user properties) are checked by unpacking in `.agents/temp` during implementation before they are written down.

## 9. Verification

- Unit tests with a fake `az` on PATH (returns canned JSON per command line) and fake tool executables that print their environment: discovery (management ok, other subscription, failure → paste fallback, tool filter), `add` idempotence, `models` diff (new, gone, kept, default gone, no change), runner environment per tool, Copilot file deleted after exit, Codex and Claude settings merge keeping other keys, schema and semantic validation, installer method choice and hash mismatch (local file server or fake download function).
- Manual work-PC checklist in `docs/verification/`: add a Claude Foundry agent, launch, `/model` switch, `models` update; Copilot Foundry agent launch and `--resume` after expiry. Diagnostics use `tools/foundry-probe.ps1` (the probe from the design, kept in the repo without organisation data).
