# Foundry agents and winget-free installs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let any ps-ai agent run on an Azure Foundry endpoint (add, launch, update models) and let the tool installer work without winget.

**Architecture:** One shared helper file (`PsAi.Foundry.ps1`) owns endpoint normalisation, the token check and deployment discovery. `ps-ai-account.ps1` uses it to add Foundry agents and update their models; a shared runner (`ps-ai-foundry.ps1`) builds the per-tool launch environment. `ps-ai-install-tool.ps1` gains official msi/zip downloads with hash checks.

**Tech Stack:** PowerShell 7, JSON Schema (`Test-Json -SchemaFile`), the repo's own test runner (`tests/run.ps1` + `tests/Assert.ps1`).

**Spec:** `docs/specs/2026-11-18-ps-ai-foundry-design.md` (extends `docs/specs/2026-11-18-ps-ai-design.md`).

## Global Constraints

- PowerShell 7 is the only runtime; scripts run on Windows, macOS and Linux unless a step says Windows only.
- Every script is safe to run again: a repeat prints `skip: <what> (already done)` or `skip: models <id> (no changes)` and writes nothing.
- No token, key or password is ever written to a file ps-ai keeps or printed; the only token file is Copilot's per-launch providers file in `~/.agents/temp/`, deleted in `finally`.
- No organisation-specific value (endpoint, tenant, account, deployment) in plugin code, tests or docs; tests use `https://res-a.cognitiveservices.azure.com` and deployments `claude-opus-x`, `claude-sonnet-x`, `gpt-x`, `embed-x`.
- Token resource is exactly `https://cognitiveservices.azure.com`.
- Account ids match `^[a-z][a-z0-9-]*$` (existing rule).
- Installs run only after the owner's yes (`-Yes`).
- Skill and reference edits follow the `standards-skill-writing` skill (`<skills>/standards-skill-writing/SKILL.md`).
- Run all tests with `pwsh -NoProfile -File tests/run.ps1`; expected last line `<n> passed, 0 failed`.

## Review Focus

1. Endpoint pasted with a path or trailing slash (`https://res-a.cognitiveservices.azure.com/anthropic/`) must store and use `https://res-a.cognitiveservices.azure.com`. Test: Task 2.
2. `models` when the management read fails must not report any deployment as gone or drop any. Test: Task 3.
3. Copilot exiting with an error must still delete its providers file and return the same exit code. Test: Task 4.
4. An agent `settings.json` / `config.toml` with other keys must keep them; an unreadable `settings.json` stops without overwriting. Test: Task 3.
5. A Foundry agent whose real tool command is missing must fail at launch with `claude is not installed; run ps-ai-install-tool.ps1 -Tool claude`, not a .NET error. Test: Task 4.

---

### Task 1: Personalisation `provider` block

**Files:**
- Modify: `plugins/ps-ai/schemas/personalisation.schema.json` (agent item properties)
- Modify: `plugins/ps-ai/bin/ps-ai-validate.ps1` (add `Get-PsAiProviderIssues`, call it from `Invoke-PsAiValidation`)
- Create: `tests/fixtures/personalisation/valid-foundry.json`, `invalid-foundry-default.json`, `invalid-foundry-alias.json`, `invalid-foundry-kind.json`
- Test: `tests/Validate.Tests.ps1`

**Interfaces:**
- Produces: agent property `provider` = `{ kind: "foundry", endpoint: string (pattern ^https://[^/]+$), default: string, deployments: [{ name: string, model?: string, alias?: "opus"|"sonnet"|"haiku"|"fable" }] (minItems 1) }`, `additionalProperties: false` at both levels; `Get-PsAiProviderIssues -Data <object>` returns issue strings `agents[<i>].provider: ...`.

- [ ] **Step 1: Write failing tests** in `tests/Validate.Tests.ps1`:
  - `valid-foundry.json` (valid-owner plus agent `claude-dev` with the spec's example provider, test values) → no issues.
  - `invalid-foundry-default.json` (default not in deployments) → issue `agents[<i>].provider: default 'x' is not a deployment`.
  - `invalid-foundry-alias.json` (alias `sonnet` twice) → `agents[<i>].provider: alias 'sonnet' used twice`; also a codex agent with an alias → `agents[<i>].provider: aliases are for claude agents only`; duplicate deployment name → `agents[<i>].provider: duplicate deployment 'x'`.
  - `invalid-foundry-kind.json` (`kind: "bedrock"`) → schema issue (non-empty issue list).
- [ ] **Step 2: Run** `pwsh -NoProfile -File tests/run.ps1` → `FAIL Validate.Tests.ps1`.
- [ ] **Step 3: Implement** the schema block (with `description` on every property, like the rest of the schema) and `Get-PsAiProviderIssues`.
- [ ] **Step 4: Run tests** → all pass.
- [ ] **Step 5: Commit** `feat: personalisation provider block for Foundry agents`.

### Task 2: Foundry helper and fake `az`

**Files:**
- Create: `plugins/ps-ai/bin/PsAi.Foundry.ps1`
- Create: `tests/fixtures/fake-az/az.ps1` (fake `az`), `tests/FakeAz.ps1` (test helper)
- Test: `tests/Foundry.Tests.ps1`

**Interfaces:**
- Produces (in `PsAi.Foundry.ps1`):
  - `ConvertTo-FoundryEndpoint -Url <string>` → `string` (`https://host`; throws `endpoint must start with https://` otherwise).
  - `Get-FoundryResourceName -Endpoint <string>` → first host label.
  - `Test-FoundryToken [-Login]` → `@{ Ok = bool; Error = string }`; with `-Login`, a failed check runs `az login` once and checks again.
  - `Get-FoundryToken` → `@{ Token = string; ExpiresOn = DateTimeOffset }` (throws with the `az` error text).
  - `Get-FoundryDeployments -Endpoint <string> -Tool <claude|codex|copilot>` → `@{ Source = 'management'|'none'; Error = string; Deployments = @(@{ name; model }) }`; searches the current subscription, then every id from `az account list --query [].id -o tsv`; tool filter: model name starts with `claude` for claude/copilot, `gpt` for codex.
- Fake `az`: `tests/fixtures/fake-az/az.ps1` reads `$env:PS_AI_FAKE_AZ` (path to JSON `{ "<key>": { "exit": int, "stdout": string } }`); key = arguments joined by single spaces with every `-o <v>`, `--output <v>` and `--query <v>` pair removed; missing key → exit 1 and `fake az: no answer for <key>` on stderr. It appends each key to `$env:PS_AI_FAKE_AZ_LOG`. `tests/FakeAz.ps1` exports `Use-FakeAz -Answers <hashtable>` (writes the JSON, prepends the fake folder to `PATH`, sets both variables) and `Get-FakeAzCalls`.

- [ ] **Step 1: Write failing tests** in `tests/Foundry.Tests.ps1`:
  - `ConvertTo-FoundryEndpoint 'https://res-a.cognitiveservices.azure.com/anthropic/'` → `https://res-a.cognitiveservices.azure.com`; `http://x` throws.
  - Token ok; token fails then `-Login` → calls `login` once, second check result returned; token fails without `-Login` → no `login` call.
  - Discovery in the current subscription: two claude, one gpt, one embedding deployment → claude tool sees 2, codex sees 1, `Source = 'management'`.
  - Resource only in the second subscription (`cognitiveservices account list --subscription sub-2`) → found.
  - Account list fails → `Source = 'none'`, `Error` holds the fake stderr text, `Deployments` empty.
- [ ] **Step 2: Run tests** → `FAIL Foundry.Tests.ps1`.
- [ ] **Step 3: Implement** `PsAi.Foundry.ps1` and the fake.
- [ ] **Step 4: Run tests** → all pass.
- [ ] **Step 5: Commit** `feat: Foundry endpoint, token and deployment discovery helpers`.

### Task 3: Add Foundry agents and update models

**Files:**
- Modify: `plugins/ps-ai/bin/ps-ai-account.ps1`
- Create: `plugins/ps-ai/bin/ps-ai-foundry.ps1` (stub with `-NoRun` support; launch logic in Task 4)
- Test: `tests/AccountFoundry.Tests.ps1`

**Interfaces:**
- Consumes: Task 2 functions; Task 1 schema.
- Produces:
  - New parameters: `-Provider foundry`, `-Endpoint`, `-Deployments string[]`, `-Default string`, `-Aliases string[]` (`name=alias`), `-List` switch; new action `models`.
  - `add -Provider foundry -List` and `models -List` print the discovery result as JSON (`{ source, error, deployments: [{ name, model, state }] }`, `state` = `new`|`gone`|`kept`; `add` has only `new`) and change nothing.
  - `add -Provider foundry` without `-List` requires `-Deployments` and `-Default`; writes the agent (`command ~/.agents/bin/<id>`, `configDir ~/.agents/accounts/<id>`, `roles []`, `provider`), copies `ps-ai-foundry.ps1` to `~/.agents/bin/` when content differs, writes wrappers that run `pwsh -NoProfile -File <home>/.agents/bin/ps-ai-foundry.ps1 -Agent <id>` with all arguments, then `Write-FoundryToolConfig`.
  - `models -Id <id> -Deployments ... -Default ... [-Aliases ...]` replaces the agent's deployment list; `model` values come from discovery when known; identical result → `skip: models <id> (no changes)`.
  - `Write-FoundryToolConfig -Agent <object> -HomeRoot <string>` (in `ps-ai-account.ps1`): Claude → `<configDir>/settings.json` key `modelPicker = { replaceBuiltInOptions: true, options: [{ model: <name>, label: <name> }] }`, other keys kept, unreadable file → throw `settings.json is not valid JSON; fix or remove it` without writing; Codex → `<configDir>/config.toml` keys of spec section 6 (replace the `model`, `model_provider` lines and the `[model_providers.ps-ai-foundry]` / `.auth` tables; keep everything else); Copilot → nothing.
  - `add` repeated with same id, tool, provider kind and endpoint → `skip: account <id> (already done)`.

- [ ] **Step 1: Write failing tests** (fake `az`, temp home as in `Account.Tests.ps1`):
  - `add -Id claude-dev -Tool claude -Provider foundry -Endpoint https://res-a.cognitiveservices.azure.com/anthropic -List` → JSON with the 2 claude deployments, `source management`; personalisation unchanged.
  - `add ... -Deployments claude-opus-x,claude-sonnet-x -Default claude-opus-x -Aliases claude-opus-x=opus,claude-sonnet-x=sonnet` → entry with normalised endpoint, models filled, validates; wrapper files exist; `settings.json` has 2 picker rows; repeat → skip.
  - Existing `settings.json` with `{"theme":"dark"}` keeps `theme`; existing `config.toml` with `approval_policy = "never"` keeps it; `settings.json` containing `{bad` → throws the message above and file unchanged.
  - Codex add writes `base_url = "https://res-a.cognitiveservices.azure.com/openai/v1"` and `command` = `(Get-Command az).Source`.
  - `models -List` after the fake gains `claude-haiku-x` and loses `claude-sonnet-x` → states `new`, `gone`, `kept`.
  - `models -List` with failing account list → no `gone` entries, `source none`.
  - `models` with the same deployments → `skip: models claude-dev (no changes)`, file bytes unchanged.
  - `models` with a default not in `-Deployments` → throws `default 'x' is not one of -Deployments`.
- [ ] **Step 2: Run tests** → `FAIL AccountFoundry.Tests.ps1`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests** → all pass (including the existing `Account.Tests.ps1`).
- [ ] **Step 5: Commit** `feat: add Foundry agents and update their models`.

### Task 4: Foundry runner

**Files:**
- Modify: `plugins/ps-ai/bin/ps-ai-foundry.ps1`
- Create: `tests/fixtures/fake-tools/claude.ps1`, `copilot.ps1`, `codex.ps1` (write their environment and arguments as JSON to `$env:PS_AI_FAKE_TOOL_LOG`, exit with `$env:PS_AI_FAKE_TOOL_EXIT` or 0)
- Test: `tests/FoundryRunner.Tests.ps1`

**Interfaces:**
- Consumes: Task 2 `Get-FoundryToken`, `Test-FoundryToken -Login`; Task 1 agent shape.
- Produces: `ps-ai-foundry.ps1 -Agent <id> [-HomeRoot <path>] [-NoRun] <tool args>`; `Get-FoundryLaunch -Agent <object> -HomeRoot <string> [-Token <object>]` → `@{ Set = hashtable; Clear = string[]; ProvidersFile = string or $null; ProvidersJson = string or $null; Notice = string or $null }`. Real tool resolved as `Get-Command <tool> -CommandType Application,ExternalScript` skipping the ps-ai wrapper folder; `.ps1` shims run through the current `pwsh`.
  - Claude: `Set` = spec section 6 variables plus `CLAUDE_CONFIG_DIR`; `Clear` = the spec's ten names.
  - Copilot: `Set` = `COPILOT_HOME`, `COPILOT_PROVIDERS_CONFIG`; providers JSON = one provider `{ name: "ps-ai-foundry", type: "anthropic", baseUrl: "<endpoint>/anthropic", bearerToken, headers: { "anthropic-version": "2023-06-01" } }` and one model per deployment `{ id: <name>, provider: "ps-ai-foundry", modelId: <model or name>, wireModel: <name> }`; `Notice` = `token valid until HH:mm; after that restart with: <id> --resume` (local time).
  - Codex: `Set` = `CODEX_HOME` only (config written by Task 3).

- [ ] **Step 1: Write failing tests:**
  - Claude launch: fake log shows `CLAUDE_CODE_USE_FOUNDRY=1`, base URL `.../anthropic`, `ANTHROPIC_MODEL=claude-opus-x`, `ANTHROPIC_DEFAULT_OPUS_MODEL=claude-opus-x`; `CLAUDE_CODE_USE_BEDROCK` set in the parent is absent in the child; arguments `-p hi` passed through.
  - Copilot launch: providers file existed during the run (fake copies it to the log), contains no token in the test output, and is gone afterwards; with `PS_AI_FAKE_TOOL_EXIT=3` runner exits 3 and the file is gone.
  - Copilot notice printed with the fake expiry time.
  - Token failure after login → exit 1 with the `az` error text; tool not started.
  - Tool missing (PATH without the fake tool) → exit 1 with `claude is not installed; run ps-ai-install-tool.ps1 -Tool claude`.
  - Unknown agent id → `unknown account 'x'`; subscription agent (no provider) → `account 'x' is not a Foundry agent`.
- [ ] **Step 2: Run tests** → `FAIL FoundryRunner.Tests.ps1`.
- [ ] **Step 3: Implement.**
- [ ] **Step 4: Run tests** → all pass.
- [ ] **Step 5: Commit** `feat: Foundry runner for Claude, Copilot and Codex agents`.

### Task 5: Installer without winget

**Files:**
- Modify: `plugins/ps-ai/bin/ps-ai-install-tool.ps1`
- Modify: `plugins/ps-ai/skills/ps-ai-repository/references/tools.md` (source table)
- Test: `tests/InstallTool.Tests.ps1`

**Interfaces:**
- Produces: parameter `-Method winget|msi|zip`; `Get-ToolDownload -Tool <tool> -Method <msi|zip>` → `@{ Url; Hash (sha256 hex); Kind = 'msi'|'exe'|'zip'|'7z-sfx'|'script'; Arguments = string[]; PathFolder = string (relative folder inside the zip) }`, resolving the latest release from the official source; `Invoke-ToolDownload -Url -OutFile` (the only network call, so tests replace it); `Test-DownloadHash -Path -Expected` → bool; `Install-ToolZip -Tool -Archive -PathFolder` → unpacks to `~/.agents/tools/<tool>/`, adds `<that>/<PathFolder>` to the user PATH once.
  - Without `-Method` on Windows: winget present and exit 0 → done; winget missing or non-zero → print `winget is not available; choose -Method msi (official installer, needs admin) or -Method zip (user folder, no admin)` and exit 2.
  - Claude and Codex: both methods run the official `install.ps1`. Copilot: npm when Node is present.

- [ ] **Step 1: Verify sources.** For glab and Copilot zips download the latest Windows zip into `.agents/temp/install-check/`, list where the executable sits, delete the folder; confirm glab installer silent flags from its release notes or installer `/?`; record every URL pattern, hash source and folder in `references/tools.md` (the research notes: winget → msi|zip, GitHub `digest`, Node `SHASUMS256.txt`, Claude `manifest.json`, PowerShell 7.7 has no MSI so msi uses the newest 7.6.x).
- [ ] **Step 2: Write failing tests** (replace `Invoke-ToolDownload` and winget after dot-sourcing with `-NoRun`): winget missing → exit 2 with the message; `-Method zip` for gh with a local zip whose hash matches → unpacked, PATH entry added once on two runs (user PATH read/write go through `Get-UserPath`/`Set-UserPath` so tests use a variable); hash mismatch → download deleted and throw `hash mismatch for gh download`; installed tool → `skip: gh already installed (...)`.
- [ ] **Step 3: Run tests** → fail. **Step 4: Implement.** **Step 5: Run tests** → pass.
- [ ] **Step 6: Commit** `feat: install tools without winget from official msi or zip`.

### Task 6: Skills, docs and manual checklist

**Files:**
- Modify: `plugins/ps-ai/skills/ps-ai-claude/references/accounts.md`, `limits.md`; same two in `ps-ai-copilot` and `ps-ai-codex`; `plugins/ps-ai/skills/ps-ai-personalisation/references/fields.md`; `README.md` (one Foundry paragraph, tools/foundry-probe.ps1 mention)
- Create: `docs/verification/2026-11-18-foundry-checklist.md`

- [ ] **Step 1:** Load `standards-skill-writing`; these are reference-file edits, so keep each `SKILL.md` unchanged unless a trigger phrase is missing ("update models for <id>" must route to the tool skill — add it to the description of the three tool skills only if absent).
- [ ] **Step 2:** `accounts.md`: "Foundry agent" section — add (`-List`, present deployments, ask keep/alias/default, then `add` with parameters), update models (`models -List`, show new/gone/kept, ask, then `models`), launch, Copilot expiry and `--resume`; Codex marked "not yet proven against Foundry"; Copilot GPT out of scope. `limits.md`: Foundry check is `az account get-access-token` success. `fields.md`: the `provider` block.
- [ ] **Step 3:** Checklist file: work-PC steps for Claude add / launch / `/model` / `models` update, Copilot add / launch / expiry / `--resume`, Codex (when GPT access exists), and `tools/foundry-probe.ps1` usage.
- [ ] **Step 4:** Baseline/guided check per `standards-skill-writing`: ask a fresh agent (no ps-ai context beyond the plugin) "add a Foundry Claude agent for https://res-a.cognitiveservices.azure.com" in a temp home with the fake `az`; record whether it uses `-List` first and asks before `add`, in `docs/verification/2026-11-18-foundry-skills.md`.
- [ ] **Step 5:** Run all tests → pass. Commit `docs: Foundry agents in tool skills and checklist`.
