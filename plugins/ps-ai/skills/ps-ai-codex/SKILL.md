---
name: ps-ai-codex
description: Use when the overseer dispatches Codex CLI work or the owner asks about Codex accounts, resuming work, limits, or "update models for <id>" for a Codex agent.
---

# Codex CLI tool

## Identity and hard rules

Use this tool skill for Codex CLI commands only. Load `ps-ai-personalisation` and its notes first; choose the account, role, and model there. The overseer owns task selection and the handoff.

- Set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt path>` for a legion run only. Never set them for an interactive session.
- Resume only on the same account and in the same repository folder. Never read credential files.
- Ping before declaring an account out of credit; report an absent rate-limit record as unknown.
- Keep the configured sandbox and approval boundaries; see [run.md](references/run.md) before changing them.
- Launch long work in the background and wait for completion rather than polling logs. Capture exit status and report.

## Operations

1. **Run or resume:** use [run.md](references/run.md) for task invocation, report output, and same-account resume.
2. **Limits:** use [limits.md](references/limits.md) for a short ping and the selected account's limit records.
3. **Accounts:** use [accounts.md](references/accounts.md) for `ps-ai-account.ps1`, `CODEX_HOME`, owner login, installation, and validation.
4. **Missing CLI:** follow [install.md](references/install.md) before adding an account or running Codex CLI.

## Stop and verification

Stop and report when the account or model is unconfigured, prompt/report path is missing, a resume would use another account, or bypass permission is unclear. Verify exit status and report after a run, and validate personalisation after account changes. Do not claim exhaustion without a ping result.

## Launcher and plugins

Use [launcher.md](references/launcher.md) for account, channel, project, and interactive-launch arguments.
Use [plugins.md](references/plugins.md) for manual plugin commands and optional wiki hints.
