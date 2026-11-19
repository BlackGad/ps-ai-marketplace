# Setup files and validation

For tool operations, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`; stop if it is missing. Read the existing rules file, `.gitignore`, scripts, docs layout, and `.agents/` files. Preserve unrelated contents, including `.agents/skills/` and `.agents/plugins/`.

Keep repository facts in `.agents/configuration/`. For a fresh repository:

- Create `project.json` from [project-template.json](project-template.json) with schemaVersion and optional editor schema metadata only. Record the rules file, actual roadmap/plans/spec paths, delivery mode, indexed gates, routing, notification destinations and neutral knowledge label in workflow.
- Create `workflow.md` from [workflow-template.md](workflow-template.md), `.agents/scripts/index.md` from [scripts-index-template.md](scripts-index-template.md), and `.agents/state/handoff.md` from [handoff-template.md](handoff-template.md).
- Ensure `.agents/state/history/`, local docs, and scratch directories exist; apply the authoritative ignore list in [layout.md](layout.md).

A fixed gate, build, benchmark, or cleanup becomes a script in `.agents/scripts/` and a row in `index.md`; workflow names that script. A narrow wrapper may call an existing root script; preserve that original entry point. Plans and specs use the paths recorded in `workflow.md`.

Scripts must check state before acting. Run each state-changing script twice: the second run exits 0, prints `skip: <what> (already done)` for completed work, and changes nothing. New scratch output belongs only in `.agents/temp/`. Re-read the resulting layout, rules, index, and JSON; confirm every project step resolves to an indexed script, every entry in [layout.md](layout.md)'s authoritative ignore list is ignored, and no other ignore rules were added or broadened.

When rewriting an existing project file, replace a plugin cache path in `$schema` with the stable URL in [project-template.json](project-template.json), or omit `$schema`. Validate the project after setup or migration with the running plugin's schema, never the file's `$schema` value:

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind project -Path <repo>/.agents/configuration/project.json
```

Validate personalisation after registering the project, using its [validation reference](../../ps-ai-personalisation/references/fields.md).
