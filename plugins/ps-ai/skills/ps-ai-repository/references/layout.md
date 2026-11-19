# Repository layout

```
<repo>/.legion/
  configuration/project.json
  configuration/workflow.md
  scripts/index.md
  scripts/<fixed-step>.ps1
  state/handoff.md
  state/history/
  state/roadmap/
  docs/specs/
  docs/plans/
  temp/
```

## Storage and ignores

Use the [setup choice](../SKILL.md#choose-where-notes-live). In the main tree, a `.legion/.git` folder or file means Private. Otherwise, files under `.legion/` tracked by the code repo (`git ls-files .legion`) mean Shared. If neither is true, setup is not finished: ask the owner the setup choice again, with Private as the default, and complete it. Save no mode setting.

These are the authoritative ignore rules for setup and verification:

| Mode | Outer repository | Inside `.legion/` | Rules block | Commit destination |
| --- | --- | --- | --- | --- |
| Private | Add `.legion/` to `.git/info/exclude`; never edit `.gitignore` | Initialize Git; write `.gitignore` with `temp/` and `docs/` | `configuration/workflow.md` | Inner repository |
| Shared | Add `.legion/temp/` and `.legion/docs/` to `.gitignore` | No inner Git repository | Named repo rules file | Code repository |

Preserve unrelated ignore rules. Git shares `.git/info/exclude` across worktrees. Private worktrees therefore ignore their own `.legion/` scratch too. Never change tracked repo files during Private setup.

`temp/` is ps-ai scratch, cleaned at milestone close-out. `docs/` holds local specs and plans; never commit or clean them. Commit `configuration/`, `scripts/`, and `state/` in the repository named above. Keep unrelated `.agents/skills` and `.agents/plugins` intact. Git cannot track an empty directory; use a `.gitkeep` in `history/` when needed. Create `temp/` locally; it stays untracked.

`state/roadmap/` is tracked and optional. Leave it missing or empty until a goal is approved. It needs no placeholder or index. See `ps-ai-overseer/references/roadmap.md` for file rules.

Project JSON contains only schemaVersion and optional editor schema metadata. Workflow records spec and plan paths, the rules file, gates, delivery, routing, notifications and neutral knowledge label. Only fixed repo steps belong in `scripts/`; one-off exploration does not need a script.
