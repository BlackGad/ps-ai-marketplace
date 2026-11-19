---
name: ps-ai-repository
description: Use when the owner asks to set up or migrate orchestration in a repository, the overseer finds no .legion/configuration, or a fixed repository step lacks a listed script.
---

# Repository orchestration setup

## Identity and hard rules

For any agent tool operation, read the selected account's tool skill using [setup.md](references/setup.md). Stop if that tool skill is missing; do not guess commands or capabilities.

This planner creates and updates repository facts. Load `ps-ai-personalisation` and its notes first. Use the existing repository rules and preserve all unrelated orchestration files, including installed skills and plugins. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Never overwrite an existing orchestration file without showing its diff. Read before editing and make the smallest change.
- Turn each fixed gate, build, benchmark, or cleanup into an indexed script named in repository workflow. Call that script instead of rebuilding its commands. Use [setup.md](references/setup.md) for script and scratch locations.
- Scripts must check current state first. Run each state-changing script twice; the second run must succeed, report completed work as skipped, and change nothing. See [setup.md](references/setup.md) for the output format.
- Keep script format metadata in project settings. Keep repository choices in workflow. Keep personal preferences in notes and account/channel data in owner settings.
- Keep the [rules block](references/rules-file-lines.md) in workflow for Private. Add it to the repo's rules file only for Shared. Private setup never edits tracked repo files. Method skills control how work is done when installed.
- Never move tracked files during migration without presenting the plan and waiting for owner approval.

## Choose where notes live

Offer these once for a fresh setup. Put Private first and recommend it:

- **Private (default):** Orchestration notes, the handoff and history stay on this PC in `.legion/`, with their own Git history. Nothing appears in the repo or on GitHub. To keep them on other machines, you can later push `.legion/` to a private repo.
- **Shared:** Orchestration notes are committed with the code. Teammates and other machines see them. Use this for private or team repos.

For an existing setup, retain its mode. See [layout.md](references/layout.md) for detection and ignore rules. Do not add a settings field.

## Create or update

1. Read the repo rules file, ignore rules, existing scripts, docs layout, and orchestration files. Ask which rules file is authoritative if unclear. Create a missing named rules file only for Shared. Read [layout.md](references/layout.md).
   Check Git and repository host, then offer missing tools through [tools.md](references/tools.md).
2. For a fresh setup, offer the modes above. Create project configuration, workflow, script index, handoff, history, local docs, and scratch space using [setup.md](references/setup.md) and its templates. Apply the chosen mode's ignore rules in [layout.md](references/layout.md).
3. For existing fixed steps, add a narrow indexed script that calls an existing root script where appropriate; preserve the original entry point. Use only the designated scratch location and apply [layout.md](references/layout.md)'s ignore list without broadening existing ignores. Follow [setup.md](references/setup.md).
4. Keep repository choices in workflow. Put the rules block in workflow for Private or the named rules file for Shared. Validate and commit setup using [setup.md](references/setup.md).

5. For an existing layout, use [migrate.md](references/migrate.md): map it, show diffs, ask before moving tracked files, and update links only after approval. Do not recreate sound files from scratch.
6. Re-read the produced layout, rules, index, and configuration. Confirm every configured step resolves to an indexed script and ignores match the chosen mode. Private must leave tracked repo files unchanged.

## Stop and verification

Stop and load `ps-ai-personalisation` if it is missing. Stop and ask which rules file to use if no file is identified. Present a migration plan and wait if tracked files must move. Do not run an unindexed fixed step.

- [ ] Layout, project schema, rules block, and script index match the references; ignores and Git history match the chosen mode in [layout.md](references/layout.md).
- [ ] Existing orchestration files and root scripts are preserved; diffs were shown before overwriting.
- [ ] Project id is registered in owner personalisation, with both configuration files validated.
