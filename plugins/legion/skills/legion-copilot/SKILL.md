---
name: legion-copilot
description: Use when the overseer dispatches Copilot CLI work or the owner asks about Copilot accounts, resuming work, limits, or Foundry provider configuration.
---

# Copilot CLI tool

Follow [owner notes](../legion-personalisation/references/fields.md) before choosing accounts, models or channels.

## Identity and hard rules

Use this tool skill for Copilot CLI operations only. Load `legion-personalisation` and its notes first. Use the account's CLI default model unless notes name a model or allow a tier for this run; follow the overseer's [model guidance](../legion-overseer/references/task-loop.md#model-tiers). Respect any paid-account approval in notes. The overseer owns account and task selection and the handoff. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Set `LEGION_ROLE=member` and `LEGION_TASK` only for a member task using [run.md](references/run.md).
- Legion runs without a sandbox, with full user rights, so it can use the owner's installed tools; follow the legion safeguards.
- Read-only reviewers require explicit write and shell tool denials. Never let a review modify the frozen checkout.
- Resume only on the same account and folder. Never read credentials.
- Ping before declaring an account out of credit. Copilot has no supported limit readout in this workflow.
- Run long work in the background, wait for completion, and capture the report and exit status; do not poll logs.

## Operations

1. **Run or resume:** follow [run.md](references/run.md) to supply the task and restrict reviewers to read-only access.
2. **Limits:** run `legion limits <id>`; [limits.md](references/limits.md) explains the readout.
3. **Accounts:** use [accounts.md](references/accounts.md) for account changes; setup installs legion before the owner logs in.
4. **Missing CLI:** setup installs it with the owner's yes; use [install.md](references/install.md) only for a CLI-only install the owner asks for.

## Stop and verification

Stop when the account or report path is missing, a resume would switch accounts, a paid account lacks owner approval, or reviewer tool denials cannot be applied. After a run, inspect exit status and captured report; after account changes, validate personalisation. Do not declare exhaustion without a quota error from that account's ping.

## Launcher and plugins

Use [launcher.md](references/launcher.md) to open an overseer session with the chosen account, channels and repository.
Use [install.md](references/install.md) for legion setup in the selected account and restarting after an update.
