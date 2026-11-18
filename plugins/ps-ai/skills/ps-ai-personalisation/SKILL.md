---
name: ps-ai-personalisation
description: Use when any ps-ai skill starts, personalisation is missing or invalid, or the owner asks to set up or change preferences, accounts, channels, projects, notes, or the overseer launcher.
---

# Owner personalisation

## Identity and hard rules

For any agent tool operation, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`. Stop if that tool skill is missing; do not guess commands or capabilities.

This context provider grounds every ps-ai mode. Read `~/.agents/configuration/ps-ai-personalisation.json` **and** `ps-ai-notes.md` before applying another ps-ai skill. In a fixture or alternate home, substitute the supplied home root for `~` and pass `-HomeRoot` to every script that accepts it. [fields.md](references/fields.md) explains the JSON.

- Never read, print, log, or store credentials or token files. Store command paths and configuration folder names only.
- Change personalisation only when the owner requested it. Keep project facts in the repo and personal habits in notes.
- After every JSON change, run `pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind personalisation -Path <home>/.agents/configuration/ps-ai-personalisation.json`.
- Account IDs are unique lowercase hyphenated names that cannot shadow a command on PATH. Register existing wrappers and manage accounts through `ps-ai-account.ps1`; use the matching tool skill for tool details.
- Never install a tool, launch an agent, or open an overseer window without authorization. The session launcher offer asks first; direct launcher invocation is itself a request to launch.

## Use the owner's settings

1. Read and validate existing JSON, then read notes. If JSON is missing, use [create.md](references/create.md); if invalid, show validator issues and make only owner-requested corrections. During setup, create missing notes from [notes-template.md](references/notes-template.md).
2. Resolve the repo id from `.agents/configuration/project.json`. Read `projects.<id>`, or `default` until registration. Follow [projects.md](references/projects.md) at first overseer takeover and for requested cleanup.
3. Choose accounts and channels from JSON. `care: high` reserves an account for overseer work; `cost: paid` requires owner approval. Use the selected tool skill for account and launch details.
4. Put the overseer shim on PATH during setup or when asked to repair it; use [launcher.md](references/launcher.md). The launcher script owns argument merging and terminal invocation.
5. Re-read changed JSON and notes. Validate the final JSON. Check that no secret or client detail entered them.

## Stop and verification

Stop after two failed validation fixes and report the exact issues. If the owner declines to create missing personalisation, continue without ps-ai orchestration. Do not infer a missing account role, channel target, or paid-account approval.

- [ ] JSON and notes were both read, or missing files were handled through the create flow.
- [ ] Every JSON edit was validated and the resulting file re-read.
- [ ] Existing wrappers were registered through `ps-ai-account.ps1`; no secret was handled.
