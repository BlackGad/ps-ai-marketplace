# Shared layout

```
<repo>/.agents/
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

This is the authoritative ignore list for setup, migration, and final verification: `.agents/temp/` and `.agents/docs/`. Add missing entries to `.gitignore` without broadening existing ignores; preserve unrelated rules. `temp/` is ps-ai scratch, cleaned at milestone close-out; `docs/` holds specs and plans, which are temporary working documents that stay local and are never committed or cleaned. Keep `.agents/configuration`, `.agents/scripts`, `.agents/state`, `.agents/skills`, and `.agents/plugins` trackable. Git cannot track an empty directory; use a `.gitkeep` in `history/` when needed. Create `temp/` locally; it stays untracked.

`state/roadmap/` is tracked and optional. Leave it missing or empty until a goal is approved. It needs no placeholder or index. See `ps-ai-overseer/references/roadmap.md` for file rules.

Project JSON contains only schemaVersion and optional editor schema metadata. Workflow records spec and plan paths, the rules file, gates, delivery, routing, notifications and neutral knowledge label. Only fixed repo steps belong in `scripts/`; one-off exploration does not need a script.
