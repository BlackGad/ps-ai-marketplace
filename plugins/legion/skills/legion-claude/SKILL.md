---
name: legion-claude
description: Use when the overseer dispatches Claude Code work or the owner asks about Claude accounts, resuming work, limits, or Foundry provider configuration.
---

# Claude Code tool

Follow [owner notes](../legion-personalisation/references/fields.md) before choosing accounts, models or channels.

## Identity and hard rules

Use this tool skill for Claude Code operations only. Load `legion-personalisation` and its notes first. Use the account's CLI default model unless notes name a model or allow a tier for this run; follow the overseer's [model guidance](../legion-overseer/references/task-loop.md#model-tiers). The overseer chooses the account and task and writes the handoff; this skill only runs the chosen tool. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Set `LEGION_ROLE=member` and `LEGION_TASK` only for a member task using [run.md](references/run.md). Do not turn an interactive session into member mode.
- Legion runs without a sandbox, with full user rights, so it can use the owner's installed tools; follow the legion safeguards.
- Resume only with the same account, config directory, and repository folder. Never read credential files.
- Ping before declaring an account out of credit. Do not infer limits from a failed long run alone.
- Run long work in a background process and wait for its completion event or process exit; do not poll its logs. Capture the report and exit status.
- Keep fixed repository checks in the repository's script index. Do not install tools without owner approval.

## Operations

1. **Run or resume:** read [run.md](references/run.md). Supply the task prompt and capture the response in its report. Keep the task environment on that process only.
2. **Limits:** read [limits.md](references/limits.md). Ping the selected account before interpreting its limits.
3. **Accounts:** read [accounts.md](references/accounts.md) to add, register, rename, or remove accounts. Setup installs legion before the owner logs in.
4. **Missing CLI:** setup installs it with the owner's yes; use [install.md](references/install.md) only for a CLI-only install the owner asks for.

## Stop and verification

Stop and report when the account is missing from personalisation, the task prompt or report path is unknown, or a resume would switch accounts. After a run, check its exit status and report file; after an account change, validate personalisation. Do not claim exhaustion without a ping result.

## Launcher and plugins

Use [launcher.md](references/launcher.md) to open an overseer session with the chosen account, channels and repository.
Use [plugins.md](references/plugins.md) for plugin setup, restarting after an update, and optional wiki help.
