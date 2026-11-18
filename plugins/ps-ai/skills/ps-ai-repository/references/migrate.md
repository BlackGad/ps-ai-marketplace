# Migrate an existing orchestration layout

1. Inventory existing configuration, rules, script paths, state/handoff, scratch, and tracked status. Keep `.agents/skills` and `.agents/plugins` intact.
2. Map each existing file to [layout.md](layout.md). Show proposed moves and a content diff for every destination already present. Preserve useful history and links. Choose the least disruptive mapping; a handoff under `docs/` can stay there until a move is approved.
3. If any tracked file must move, present the exact source and destination, link updates, and expected git diff to the owner. Wait for approval before moving it.
4. After approval, migrate one owner at a time, update references, create missing templates, register the project id, and validate both project and personalisation JSON. Review `git diff --check` and ensure only `.agents/temp/` was newly ignored.

For a fixed step currently outside `.agents/scripts/`, first add a wrapper there that calls the existing script and index the wrapper. Moving the original tracked script is a separate migration decision.
