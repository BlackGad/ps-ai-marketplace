---
name: ps-ai-copilot
description: Use when the overseer dispatches Copilot CLI work or the owner asks about Copilot accounts, resuming work, limits, or "update models for <id>" for a Copilot agent.
---

# Copilot CLI tool

Follow [owner notes](../ps-ai-personalisation/references/fields.md) before choosing accounts, models or channels.

## Identity and hard rules

Use this tool skill for Copilot CLI operations only. Load `ps-ai-personalisation` and its notes first; choose the account, role, model, and any paid-account approval there. The overseer owns task selection and the handoff. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Mark only a legion process as a legion task using [run.md](references/run.md).
- Legion runs without a sandbox, with full user rights, so it can use the owner's installed tools; follow the legion safeguards.
- Read-only reviewers require explicit write and shell tool denials. Never let a review modify the frozen checkout.
- Resume only on the same account and folder. Never read credentials.
- Ping before declaring an account out of credit. Copilot has no supported limit readout in this workflow.
- Run long work in the background, wait for completion, and capture the report and exit status; do not poll logs.

## Operations

1. **Run or resume:** follow [run.md](references/run.md) to supply the task and restrict reviewers to read-only access.
2. **Limits:** [limits.md](references/limits.md) describes the quota-error ping and unknown result.
3. **Accounts:** use [accounts.md](references/accounts.md) for account changes, owner login, installation, and validation.
4. **Missing CLI:** follow [install.md](references/install.md) before adding an account or running Copilot CLI.

## Stop and verification

Stop when account/model or report path is missing, a resume would switch accounts, a paid account lacks owner approval, or reviewer tool denials cannot be applied. After a run, inspect exit status and captured report; after account changes, validate personalisation. Do not declare exhaustion without a quota error from that account's ping.

## Launcher and plugins

Use [launcher.md](references/launcher.md) to open an overseer session with the chosen account, channels and repository.
Use [install.md](references/install.md) for ps-ai setup in the selected account and restarting after an update.
