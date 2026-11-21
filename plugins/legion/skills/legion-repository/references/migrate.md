# Migrate an existing orchestration layout

For old names in an existing setup, preview the changes first:

```text
pwsh -NoProfile -File <plugin>/bin/legion-repository.ps1 -Repo <repo> -Migrate [-RulesFile <file>]
```

The overseer offers this on next start when the orchestration block still has `## ps-ai orchestration`, `PS_AI_ROLE`, or `PS_AI_TASK`, or `project.json` has the old schema path. Show the diff and wait for the owner's yes, then repeat with `-Yes`. This changes only the names in the orchestration block (including the Private workflow block) and the project `$schema` value; unrelated text, BOMs and line endings stay intact. A repeat prints `skip:`. It does not move files or create a commit.

1. Inventory existing configuration, rules, script paths, state/handoff, scratch, and tracked status. Keep `.agents/skills` and `.agents/plugins` intact.
2. Map each existing file to [layout.md](layout.md). Show proposed moves and a content diff for every destination already present. Preserve useful history and links. Choose the least disruptive mapping; a handoff under `docs/` can stay there until a move is approved.
3. If any tracked file must move, present the exact source and destination, link updates, and expected git diff to the owner. Wait for approval before moving it.
4. After approval, migrate one owner at a time, update references, create missing templates, record repository choices in workflow, and validate minimal project JSON. Review `git diff --check`; verify every entry in [layout.md](layout.md)'s authoritative ignore list is ignored and no other ignore rules were added or broadened.

For a fixed step currently outside `.legion/scripts/`, first add a wrapper there that calls the existing script and index the wrapper. Moving the original tracked script is a separate migration decision.
