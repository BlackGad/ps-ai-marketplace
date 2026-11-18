---
name: ps-ai-repository
description: Use when the owner asks to set up or migrate orchestration in a repository, the overseer finds no .agents/configuration, or a fixed repository step lacks a listed script.
---

# Repository orchestration setup

## Identity and hard rules

For any agent tool operation, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`. Stop if that tool skill is missing; do not guess commands or capabilities.

This planner creates and updates shared repository facts. Load `ps-ai-personalisation` and its notes first. Use the existing repository rules and preserve all unrelated `.agents/` contents, including `.agents/skills/` and `.agents/plugins/`.

- Never overwrite an existing `.agents/` file without showing its diff. Read before editing and make the smallest change.
- A fixed gate, build, benchmark, or cleanup becomes a script in `.agents/scripts/` **and** a row in `index.md`; `project.json` steps name that script. Call the script instead of recomposing its commands. Scripts write temporary output only under `.agents/temp/`.
- Scripts created in `.agents/scripts/` must check current state first. Run each state-changing script twice; the second run exits 0 and prints `skip: <what> (already done)` for completed work.
- Repo facts go in `.agents/configuration/`; personal accounts and channels stay in the owner's personalisation. Plans and specs use the paths in `project.json`.
- Put the exact [rules-file-lines.md](references/rules-file-lines.md) block in the repo's rules file. It sets ps-ai mode, legion delegation, path, and fixed-step precedence over installed method skills. Method skills control how work is done when installed.
- Never move tracked files during migration without presenting the plan and waiting for owner approval.

## Create or update

1. Read the repo rules file, `.gitignore`, existing scripts, docs layout, and any `.agents/` files. If the owner supplied a rules filename that does not yet exist, create it; otherwise ask which file is authoritative. Read [layout.md](references/layout.md).
   Check Git and repository host, then offer missing tools through [tools.md](references/tools.md).
2. For a fresh repo, create `project.json` from [project-template.json](references/project-template.json) with a stable id, rules file, actual roadmap/plans/spec paths, delivery mode, and step names; create `workflow.md` from [workflow-template.md](references/workflow-template.md), `scripts/index.md` from [scripts-index-template.md](references/scripts-index-template.md), and `state/handoff.md` from [handoff-template.md](references/handoff-template.md). Ensure `history/` and ignored `temp/` exist.
3. For existing fixed steps, make a narrow script in `.agents/scripts/` that invokes an existing root script if appropriate; preserve the original entry point. Add its row and step name. Use only `.agents/temp/` for new scratch output. Add the precise `.agents/temp/` ignore line without broadening existing ignores.
4. Add the rules block to the named rules file. Register the project id in owner personalisation through [projects.md](../ps-ai-personalisation/references/projects.md), using the owner's notification answer. Validate with `pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind project -Path <repo>/.agents/configuration/project.json` and validate personalisation after its edit.
5. For an existing layout, use [migrate.md](references/migrate.md): map it, show diffs, ask before moving tracked files, and update links only after approval. Do not recreate sound files from scratch.
6. Re-read the produced layout, rules, index, and JSON. Confirm every `project.json` step resolves to an indexed script and only `.agents/temp/` is newly ignored.

## Stop and verification

Stop and load `ps-ai-personalisation` if it is missing. Stop and ask which rules file to use if no file is identified. Present a migration plan and wait if tracked files must move. Do not run an unindexed fixed step.

- [ ] Layout, project schema, rules block, script index, and ignore rule match the references.
- [ ] Existing `.agents/` files and root scripts are preserved; diffs were shown before overwriting.
- [ ] Project id is registered in owner personalisation, with both JSON files validated.
