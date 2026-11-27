---
name: legion-codex
description: Use when the overseer dispatches Codex CLI work or the owner asks about Codex accounts, resuming work, limits, or Foundry provider configuration.
---

# Codex CLI tool

Follow [owner notes](../legion-personalisation/references/fields.md) before choosing accounts, models or channels.

## Identity and hard rules

Use this tool skill for Codex CLI operations only. Load `legion-personalisation` and its notes first. Pass a model only as the overseer's [model tiers](../legion-overseer/references/task-loop.md#model-tiers) allow. The overseer owns account and task selection and the handoff. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Set `LEGION_ROLE=member` and `LEGION_TASK` only for a member task using [run.md](references/run.md). Never turn an interactive session into member mode.
- Resume only on the same account and in the same repository folder. Never read credential files.
- Ping before declaring an account out of credit; report an absent rate-limit record as unknown.
- Legion runs without a sandbox, with full user rights, so it can use the owner's installed tools; follow the legion safeguards.
- Launch long work in the background and wait for completion rather than polling logs. Capture exit status and report.

## Operations

1. **Run or resume:** use [run.md](references/run.md) for task invocation, report output, and same-account resume.
2. **Limits:** check the account's limits; [limits.md](references/limits.md) explains the readout.
3. **Accounts:** use [accounts.md](references/accounts.md) for this tool's login and Foundry setup; [create.md](../legion-personalisation/references/create.md) covers add, register, rename and remove. Setup installs legion before the owner logs in.
4. **Missing CLI:** setup installs it with the owner's yes; use [install.md](references/install.md) only for a CLI-only install the owner asks for.

## Stop and verification

Stop and report when the account is unconfigured, prompt/report path is missing, a resume would use another account, or the required launch mode cannot be applied. Verify exit status and report after a run, and validate personalisation after account changes. Do not claim exhaustion without a ping result.

## Launcher and plugins

Use the [launcher guide](../legion-personalisation/references/launcher.md) to open an overseer session with the chosen account, channels and repository.
Use [plugins.md](references/plugins.md) for plugin setup, hook trust and optional wiki help.
