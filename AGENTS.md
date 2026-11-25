# Repository instructions

Shared instructions for every coding agent working in this repository (Claude Code reads them through `CLAUDE.md`). The user's explicit instructions take precedence.

## What this repository is

A plugin marketplace with one plugin, `legion`: orchestration as skills for Claude Code, Codex CLI and Copilot CLI.

| Path | Holds |
| --- | --- |
| `.claude-plugin/`, `.agents/plugins/` | Marketplace manifests (Claude Code and Copilot; Codex) |
| `plugins/legion/skills/` | Skills: `SKILL.md` plus `references/` per skill |
| `plugins/legion/src/legion/` | Python CLI; project and lockfile in `plugins/legion/`, tests in `tests/python/` |
| `plugins/legion/hooks/` | Session-start hooks for all three tools |
| `plugins/legion/schemas/` | JSON schemas for personalisation and project files |
| `install.ps1`, `install.sh` | Root bootstraps: they only obtain uv, then run the Python `legion install` with the same options; `install.ps1` runs on Windows PowerShell 5.1 and 7 |
| `docs/reference.md` | Installer options, CLI guides and technical details |
| `tests/` | Test files (`*.Tests.ps1`), fakes and fixtures |
| `tools/` | Maintenance scripts, such as `update-tools-index.ps1` |

## Rules

A settings field exists only if a script reads it. Everything else is a plain-words preference in the owner's `legion-notes.md`, which agents read. Do not add a property for each decision.

- **Legion runs in Python.** PowerShell remains only in the Windows bootstrap `install.ps1` (5.1 and 7), the test runner and the `tools/` maintenance scripts (PowerShell 7, Windows, macOS and Linux).
- **Safe to run again.** Every script checks before it acts; a repeat prints `skip: <what> (already done)` and changes nothing.
- **Ask before installing.** Install commands are shown as hints and run only after the owner's yes (`-Yes`).
- **No secrets, no personal data.** Never store or print tokens or keys. Never commit user names, host names, local paths, endpoints, chat ids or account names from a real setup; use neutral examples (`codex-a`, `my-project`, `https://<resource>.cognitiveservices.azure.com`).
- **Readable and simple code is a must (KISS).** Write code the next person can read without explanation: plain control flow, clear names, no clever tricks, no abstraction without a real second use.
- **DRY is desired.** Keep one home for each rule, format or list and reuse it, unless repeating it is simpler to read.
- **Minimal diff.** Change only what the task needs.
- Compare paths by resolving links with `resolve_directory` and `same_path` in `plugins/legion/src/legion/_home.py` (PowerShell tests: `Resolve-LegionDirectoryPath` in `tests/lib/paths.ps1`), then using the OS comparer; keep deliberate link-refusal checks lexical.
- Skills talk to the owner in plain words. `SKILL.md` holds the flow and the conversation; commands, script paths and flags go in `references/`.

## Release

Versions and the changelog are made by the release workflow. Task branches and pull requests never change `version` in the three `plugin.json` files and never edit `CHANGELOG.md`. The release workflow keeps one release pull request open; the owner merges it to tag `vX.Y.Z` and publish the GitHub Release. The overseer may add a short "What is new" summary to the GitHub Release notes after the tag is published, and never edits the release pull request body.

## Tests

```powershell
pwsh -NoProfile -File tests/run.ps1
```

Run a single file with `pwsh -NoProfile -File tests/run.ps1 -Name <file>` (wildcards allowed), never directly.

The last line must be `<n> passed, 0 failed`. Tests never call real `az`, `claude`, `codex`, `copilot`, winget or the network; use the fakes in `tests/` and replace download functions.

CI runs the same command on Windows, macOS and Linux, and runs the integration suite (`tests/integration/run.py`) on every pull request; both are required checks.

Python uses uv only (Python >=3.12), with code style from ps-poetry: the repository's `ruff.toml` and standard-mode `pyrightconfig.json`. From the repository root, set `UV_PROJECT_ENVIRONMENT` to a folder outside the plugin cache, for example `.agents/temp/python/env` (ignored scratch), then use `uv run --project plugins/legion --frozen --group dev` followed by `ruff check plugins/legion/src tests/python`, `ruff format --check plugins/legion/src tests/python`, `pyright`, or `pytest --rootdir=. -c plugins/legion/pyproject.toml`. Before pytest, set `LEGION_TEST_PWSH` to the absolute pwsh path, for example `(Get-Command pwsh).Source`. Keep environments outside the plugin cache; the PowerShell test runner stays PowerShell-only.

## Not committed

- Design specs, implementation plans and verification notes (`docs/specs/`, `docs/plans/`, `docs/superpowers/`, `docs/verification/`) are temporary working documents; they stay local and are ignored.
- Scratch, logs, reports and worktrees go in `.agents/temp/` (ignored).

## Git

- Work on a feature branch; `main` changes only through a pull request the owner approves.
- Never force-push or amend.
- Commit messages and pull request titles are conventional commit subjects (`feat: ...`, `fix(install): ...`, `docs: ...`, `chore: ...`). The squash merge uses the pull request title as the commit on `main`, and the release workflow builds the changelog from it.
- Add no `Co-Authored-By` trailer for any agent or tool, and no "Generated with" footer in pull request descriptions.
