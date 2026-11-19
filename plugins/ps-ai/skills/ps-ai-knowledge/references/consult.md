# Consult the knowledge hub

For tool operations, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`; stop if missing. Read `knowledge.backend` and `projects.<repo-id>.label` from personalisation. When backend is `none`, exit silently. The hub defaults to `~/.agents/knowledge/` unless the owner's configured wiki location resolves elsewhere.

1. Start at the hub's `_index.md`, then any relevant topic `_index.md`. Search Markdown for the symptom and related terms (for example timeout, readiness, flaky); use `rg` when available.
2. Open the candidate note, verify the context and date if present, and cite the exact path. Do not treat a search snippet as the lesson.
3. State what the note said and which part applies now. If evidence is weak or no note matches, say so and continue ordinary investigation.

Use the installed llm-wiki query skill when available. Direct Markdown reading works in every supported CLI and needs no wiki plugin.
