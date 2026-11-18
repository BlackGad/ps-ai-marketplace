---
name: ps-ai-claude
description: Use when the overseer dispatches Claude Code work or the owner asks about Claude accounts, resuming work, limits, or "update models for <id>" for a Claude agent.
---

# Claude Code tool

## Identity and hard rules

Use this tool skill for Claude Code commands only. Load `ps-ai-personalisation` and its notes first; select the configured Claude account, role, and model there. The overseer chooses the task and writes the handoff; this skill only runs the chosen tool.

- Set `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt path>` only for a legion process. Do not turn an interactive session into legion mode.
- Resume only with the same account, config directory, and repository folder. Never read credential files.
- Ping before declaring an account out of credit. Do not infer limits from a failed long run alone.
- Run long work in a background process and wait for its completion event or process exit; do not poll its logs. Capture the report and exit status.
- Keep fixed repository checks in listed `.agents/scripts/` scripts. Do not install tools without owner approval.

## Operations

1. **Run or resume:** read [run.md](references/run.md). Print mode takes the task prompt on stdin and writes its response to the report path. Keep the task environment on that process only.
2. **Limits:** read [limits.md](references/limits.md). Use a short Haiku ping and interpret the `rate_limit_event` windows.
3. **Accounts:** read [accounts.md](references/accounts.md). Add, register, rename, or remove via `ps-ai-account.ps1`; use the installer only after the owner's login step for a new account.
4. **Missing CLI:** follow [install.md](references/install.md) before adding an account or running Claude Code.

## Stop and verification

Stop and report when the account is missing from personalisation, the task prompt or report path is unknown, or a resume would switch accounts. After a run, check its exit status and report file; after an account change, validate personalisation. Do not claim exhaustion without a ping result.
