# Consult the knowledge hub

For tool operations, read `skills/legion-<agent.tool>/SKILL.md` using the selected account's `agent.tool`. Stop if missing. Read the repository workflow for its neutral label. Use the hub in `~/.config/llm-wiki/config.json` (`hub_path`, then legacy `resolved_path`), or `~/.legion/knowledge` when no pointer is saved.

1. The session start already lists each topic and its note titles. Pick the matching titles there; open the hub's `_index.md` only when the list says "more in" or nothing matches. Search Markdown for the symptom and related terms (for example timeout, readiness, flaky); use `rg` when available.
2. Open the candidate note, verify the context and date if present, and cite the exact path. Do not treat a search snippet as the lesson.
3. State what the note said and which part applies now. If evidence is weak or no note matches, say so and continue ordinary investigation.

Use the installed llm-wiki query skill when available. Direct Markdown reading works in every supported CLI and needs no wiki plugin.
