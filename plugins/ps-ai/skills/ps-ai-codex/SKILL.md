---
name: ps-ai-codex
description: Use when the overseer dispatches Codex CLI work or the owner asks about Codex accounts, resuming work, limits, or "update models for <id>" for a Codex agent.
---

# Codex CLI tool

Read the owner's notes before choosing accounts or models. Respect stated exclusions and spending choices. Re-read after edits. Use the selected channel kind's skill for channel work.

## Identity and hard rules

Use this tool skill for Codex CLI operations only. Load `ps-ai-personalisation` and its notes first; choose the account, role, and model there. The overseer owns task selection and the handoff. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Mark only a legion run as a legion task using [run.md](references/run.md). Never turn an interactive session into legion mode.
- Resume only on the same account and in the same repository folder. Never read credential files.
- Ping before declaring an account out of credit; report an absent rate-limit record as unknown.
- Legion runs without a sandbox, with full user rights, so it can use the owner's installed tools; follow the legion safeguards.
- Launch long work in the background and wait for completion rather than polling logs. Capture exit status and report.

## Operations

1. **Run or resume:** use [run.md](references/run.md) for task invocation, report output, and same-account resume.
2. **Limits:** use [limits.md](references/limits.md) for a short ping and the selected account's limit records.
3. **Accounts:** use [accounts.md](references/accounts.md) for account changes, owner login, installation, and validation.
4. **Missing CLI:** follow [install.md](references/install.md) before adding an account or running Codex CLI.

## Stop and verification

Stop and report when the account or model is unconfigured, prompt/report path is missing, a resume would use another account, or the required launch mode cannot be applied. Verify exit status and report after a run, and validate personalisation after account changes. Do not claim exhaustion without a ping result.

## Launcher and plugins

Use [launcher.md](references/launcher.md) to open an overseer session with the chosen account, channels and repository.
Use [plugins.md](references/plugins.md) for plugin setup, resuming after an update, and optional wiki help.
