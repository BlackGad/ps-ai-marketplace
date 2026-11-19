# Setup files and validation

For tool operations, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`; stop if it is missing. Read the existing rules file, `.gitignore`, scripts, docs layout, and `.legion/` files. Preserve unrelated contents, including `.agents/skills/` and `.agents/plugins/`.

Keep repository facts in `.legion/configuration/`. For a fresh repository:

- Create `project.json` from [project-template.json](project-template.json) with schemaVersion and optional editor schema metadata only. Record the rules file, actual plan and spec paths, delivery mode, indexed gates, routing, notification destinations and neutral knowledge label in workflow.
- Create `workflow.md` from [workflow-template.md](workflow-template.md), `.legion/scripts/index.md` from [scripts-index-template.md](scripts-index-template.md), and `.legion/state/handoff.md` from [handoff-template.md](handoff-template.md).
- Ensure `.legion/state/history/`, local docs, and scratch directories exist; apply the authoritative ignore list in [layout.md](layout.md).

A fixed gate, build, benchmark, or cleanup becomes a script in `.legion/scripts/` and a row in `index.md`; workflow names that script. A narrow wrapper may call an existing root script; preserve that original entry point. Plans and specs use the paths recorded in `workflow.md`.

Do not ask for a roadmap path. After the owner approves a goal's roadmap, create `.legion/state/roadmap/<goal-id>.md` from [roadmap-template.md](roadmap-template.md). Follow `ps-ai-overseer/references/roadmap.md`. Until then, the folder may be missing or empty.

Scripts must check state before acting. Run each state-changing script twice: the second run exits 0, prints `skip: <what> (already done)` for completed work, and changes nothing. New scratch output belongs only in `.legion/temp/`. Re-read the resulting layout, rules, index, and JSON. Confirm every project step resolves to an indexed script and ignores match the chosen mode in [layout.md](layout.md).

When rewriting an existing project file, replace a plugin cache path in `$schema` with the stable URL in [project-template.json](project-template.json), or omit `$schema`. Validate the project after setup or migration with the running plugin's schema, never the file's `$schema` value:

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-validate.ps1 -Kind project -Path <repo>/.legion/configuration/project.json
```

Validate personalisation after registering the project, using its [validation reference](../../ps-ai-personalisation/references/fields.md).

## Initialize storage

Put the [rules block](rules-file-lines.md) in workflow for Private. For Shared, add it to the named repo rules file. After authoring and validating configuration, scripts, and state, run the fixed storage step:

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-repository.ps1 -Repo <repo> -Mode Private
```

Use `-Mode Shared` for the other choice. Omitting `-Mode` selects Private. The script resolves the Git exclude file, including from a worktree. Private initializes `.legion/` as a Git repository and commits `.gitignore`, configuration, scripts, and state there. It leaves tracked repo files alone. Shared adds the two outer ignore entries; then commit the setup files, `.gitignore`, and the rules block in the code repository. Stage only the files setup changed. Follow [takeover.md](../../ps-ai-overseer/references/takeover.md) for later state commits.
