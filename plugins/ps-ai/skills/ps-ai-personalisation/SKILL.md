---
name: ps-ai-personalisation
description: Use when any ps-ai skill starts, personalisation is missing or invalid, or the owner asks to set up or change preferences, accounts, channels, projects, notes, or the overseer launcher.
---

# Owner personalisation

## Identity and hard rules

For any agent tool operation, read the selected account's tool skill using [fields.md](references/fields.md). Stop if that tool skill is missing; do not guess commands or capabilities.

This context provider grounds every ps-ai mode. Read both the owner's settings and notes before applying another ps-ai skill. Use [fields.md](references/fields.md) for their locations and validation, and [create.md](references/create.md) for an alternate home. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Never read, print, log, or store credentials or token files. Store command paths and configuration folder names only.
- Change personalisation only when the owner requested it. Keep project facts in the repo and personal habits in notes.
- Validate settings after every change using [fields.md](references/fields.md).
- Use unique account names that do not conflict with installed commands. Register existing account shortcuts and manage accounts through the matching tool skill; see [fields.md](references/fields.md) for naming rules.
- Never install a tool, launch an agent, or open an overseer window without authorization. The session launcher offer asks first; direct launcher invocation is itself a request to launch.

## Use the owner's settings

1. Read and validate existing settings, then read notes. If settings are missing, use [create.md](references/create.md); if invalid, explain the validation issues and make only owner-requested corrections. During setup, create missing notes from [notes-template.md](references/notes-template.md).
2. Find the repository's project entry, using defaults until registration. Follow [projects.md](references/projects.md) at first overseer takeover and for requested cleanup.
3. Choose accounts and channels from settings. Reserve accounts marked for careful use for overseer work; paid accounts require owner approval. Use the selected tool skill for account and launch details.
4. Make the overseer launcher available during setup or when asked to repair it; use [launcher.md](references/launcher.md). Let the launcher combine settings and open the terminal.
5. Re-read changed settings and notes. Validate the final settings. Check that no secret or client detail entered them.

## Stop and verification

Stop after two failed validation fixes and report the exact issues. If the owner declines to create missing personalisation, continue without ps-ai orchestration. Do not infer a missing account role, channel target, or paid-account approval.

- [ ] Settings and notes were both read, or missing files were handled through the create flow.
- [ ] Every settings edit was validated and the resulting file re-read.
- [ ] Existing account shortcuts were registered through the selected tool skill; no secret was handled.
