# Repository instructions

Shared instructions for every coding agent working in this repository (Claude Code reads them through `CLAUDE.md`). The user's explicit instructions take precedence.

## What this repository is

A plugin marketplace with one plugin, `ps-ai`: orchestration as skills for Claude Code, Codex CLI and Copilot CLI.

| Path | Holds |
| --- | --- |
| `.claude-plugin/`, `.agents/plugins/` | Marketplace manifests (Claude Code and Copilot; Codex) |
| `plugins/ps-ai/skills/` | Skills: `SKILL.md` plus `references/` per skill |
| `plugins/ps-ai/bin/` | PowerShell scripts the skills call |
| `plugins/ps-ai/hooks/` | Session-start hooks for all three tools |
| `plugins/ps-ai/schemas/` | JSON schemas for personalisation and project files |
| `install/` | Installers for the three CLIs and the Windows bootstrap |
| `tests/` | Test files (`*.Tests.ps1`), fakes and fixtures |
| `tools/` | Diagnostics, such as `foundry-probe.ps1` |

## Rules

- **PowerShell 7 only.** Scripts run on Windows, macOS and Linux unless a script says otherwise.
- **Safe to run again.** Every script checks before it acts; a repeat prints `skip: <what> (already done)` and changes nothing.
- **Ask before installing.** Install commands are shown as hints and run only after the owner's yes (`-Yes`).
- **No secrets, no personal data.** Never store or print tokens or keys. Never commit user names, host names, local paths, endpoints, chat ids or account names from a real setup; use neutral examples (`codex-a`, `my-project`, `https://<resource>.cognitiveservices.azure.com`).
- **Skills follow a skill-writing standard:** orchestration in `SKILL.md`, detail in `references/`, trigger-focused descriptions, explicit stop conditions.
- **Minimal diff.** Change only what the task needs.

## Tests

```powershell
pwsh -NoProfile -File tests/run.ps1
```

The last line must be `<n> passed, 0 failed`. Tests never call real `az`, `claude`, `codex`, `copilot`, winget or the network; use the fakes in `tests/` and replace download functions.

## Not committed

- Design specs and implementation plans (`docs/specs/`, `docs/plans/`, `docs/superpowers/`) stay local; they are ignored.
- Scratch, logs, reports and worktrees go in `.agents/temp/` (ignored).

## Git

- Work on a feature branch; `main` changes only through a pull request the owner approves.
- Never force-push or amend.
