---
name: ps-ai-repository
description: Use when the owner asks to set up or migrate orchestration in a repository, the overseer finds no .agents/configuration, or a fixed repository step lacks a listed script.
---

# Repository orchestration setup

## Identity and hard rules

For any agent tool operation, read the selected account's tool skill using [setup.md](references/setup.md). Stop if that tool skill is missing; do not guess commands or capabilities.

This planner creates and updates shared repository facts. Load `ps-ai-personalisation` and its notes first. Use the existing repository rules and preserve all unrelated orchestration files, including installed skills and plugins. Speak to the owner in plain words; show commands only when asked or when they must run them themselves.

- Never overwrite an existing orchestration file without showing its diff. Read before editing and make the smallest change.
- Turn each fixed gate, build, benchmark, or cleanup into an indexed script named in project configuration. Call that script instead of rebuilding its commands. Use [setup.md](references/setup.md) for script and scratch locations.
- Scripts must check current state first. Run each state-changing script twice; the second run must succeed, report completed work as skipped, and change nothing. See [setup.md](references/setup.md) for the output format.
- Keep repository facts in project configuration and personal accounts and channels in the owner's settings. Use the configured plan and spec locations.
- Put the exact [rules-file-lines.md](references/rules-file-lines.md) block in the repo's rules file. It sets ps-ai mode, legion delegation, path, and fixed-step precedence over installed method skills. Method skills control how work is done when installed.
- Never move tracked files during migration without presenting the plan and waiting for owner approval.

## Create or update

1. Read the repo rules file, ignore rules, existing scripts, docs layout, and orchestration files. If the owner supplied a rules filename that does not yet exist, create it; otherwise ask which file is authoritative. Read [layout.md](references/layout.md).
   Check Git and repository host, then offer missing tools through [tools.md](references/tools.md).
2. For a fresh repo, create project configuration, workflow, script index, handoff, history, and ignored scratch space using [setup.md](references/setup.md) and its templates.
3. For existing fixed steps, add a narrow indexed script that calls an existing root script where appropriate; preserve the original entry point. Use only the designated scratch location and add its precise ignore rule without broadening existing ignores. Follow [setup.md](references/setup.md).
4. Add the rules block to the named rules file. Register the project id in owner personalisation through [projects.md](../ps-ai-personalisation/references/projects.md), using the owner's notification answer. Validate project configuration using [setup.md](references/setup.md) and validate personalisation after its edit.
5. For an existing layout, use [migrate.md](references/migrate.md): map it, show diffs, ask before moving tracked files, and update links only after approval. Do not recreate sound files from scratch.
6. Re-read the produced layout, rules, index, and configuration. Confirm every configured step resolves to an indexed script and only the designated scratch space is newly ignored, as described in [setup.md](references/setup.md).

## Stop and verification

Stop and load `ps-ai-personalisation` if it is missing. Stop and ask which rules file to use if no file is identified. Present a migration plan and wait if tracked files must move. Do not run an unindexed fixed step.

- [ ] Layout, project schema, rules block, script index, and ignore rule match the references.
- [ ] Existing orchestration files and root scripts are preserved; diffs were shown before overwriting.
- [ ] Project id is registered in owner personalisation, with both configuration files validated.
