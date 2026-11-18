---
name: ps-ai-copilot
description: Use when the overseer dispatches Copilot CLI work or the owner asks about Copilot accounts, resuming work, limits, or "update models for <id>" for a Copilot agent.
---

# Copilot CLI tool

## Identity and hard rules

Use this tool skill for Copilot CLI commands only. Load `ps-ai-personalisation` and its notes first; choose the account, role, model, and any `cost: paid` approval there. The overseer owns task selection and the handoff.

- Set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt path>` only for a legion process.
- Read-only reviewers require explicit write and shell tool denials. Never let a review modify the frozen checkout.
- Resume only on the same account and folder. Never read credentials.
- Ping before declaring an account out of credit. Copilot has no supported limit readout in this workflow.
- Run long work in the background, wait for completion, and capture the report and exit status; do not poll logs.

## Operations

1. **Run or resume:** [run.md](references/run.md) gives prompt mode and the read-only reviewer flags.
2. **Limits:** [limits.md](references/limits.md) describes the quota-error ping and unknown result.
3. **Accounts:** [accounts.md](references/accounts.md) gives `ps-ai-account.ps1`, `COPILOT_HOME`, owner login, installation, and validation.
4. **Missing CLI:** follow [install.md](references/install.md) before adding an account or running Copilot CLI.

## Stop and verification

Stop when account/model or report path is missing, a resume would switch accounts, a paid account lacks owner approval, or reviewer tool denials cannot be applied. After a run, inspect exit status and captured report; after account changes, validate personalisation. Do not declare exhaustion without a quota error from that account's ping.
