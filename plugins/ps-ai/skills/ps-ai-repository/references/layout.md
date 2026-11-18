# Shared layout

```
<repo>/.agents/
  configuration/project.json
  configuration/workflow.md
  scripts/index.md
  scripts/<fixed-step>.ps1
  state/handoff.md
  state/history/
  temp/
```

Add exactly `.agents/temp/` to `.gitignore` for ps-ai scratch. Keep `.agents/configuration`, `.agents/scripts`, `.agents/state`, `.agents/skills`, and `.agents/plugins` trackable. Git cannot track an empty directory; use a `.gitkeep` in `history/` when needed. Create `temp/` locally; it stays untracked.

The project id is stable across moves and clones. `paths` are repo-relative. The `rulesFile` is the existing or owner-named agent rules file. Only fixed repo steps belong in `scripts/`; one-off exploration does not need a script.
