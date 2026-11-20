# Create or finish owner configuration

1. Read existing settings and notes. Reuse previous answers. Ask only which agents to add: the tool, account name, and an existing folder or a new one. Adding no accounts yet is valid.

2. Resolve account name or shortcut conflicts before replacing files. Create missing `<home>/.legion/configuration/ps-ai-personalisation.json` before helpers with `{"schemaVersion":1,"agents":[],"channels":[]}`. Create missing notes from [notes-template.md](notes-template.md). Use the optional stable schema URL in [fields.md](fields.md). Validate against the bundled schema.

3. Read `skills/ps-ai-<agent.tool>/SKILL.md` for each selected account; stop if missing. Explain that adding the selected accounts includes installing ps-ai into each folder. Preview any missing CLI installs with those installs and ask for one yes covering them all. Reuse existing approval. Deduplicate installation by normalized config folder. Use the tool's account guide for add/adopt/register and install ps-ai into each account. Resolve a previous default-folder answer through `tool.plugin.defaultConfigDir` to a concrete folder. Expand `~/` against the chosen home. Keep existing shortcuts, settings and logins. Only new accounts need owner login. Declined or failed installs stay incomplete under Finish later.

4. Re-read JSON and notes, validate JSON, and summarize accounts and any unfinished installs. Setup is complete when the selected accounts have ps-ai installed. Repeated setup skips completed actions with `skip: <what> (already done)` and preserves completed files byte-for-byte.

Only Foundry agents ask about models during setup; follow the tool's account guide for standard mapping or owner choices. Do not ask about models for subscription agents, account purposes, worker or reviewer roles, notification timing, channels, or knowledge during setup. Learn preferences later from the owner's words and save them using the [shared memory rule](../SKILL.md#identity-and-hard-rules). Set up a channel only when requested, such as “use Telegram”. Route it through `skills/ps-ai-<kind>/SKILL.md`; stop if missing. That skill owns connection, approval and verified bindings. Make the launcher available through [launcher.md](launcher.md) when requested.

The overseer asks about legion access at the [first legion dispatch](../../ps-ai-overseer/references/task-loop.md#first-legion-dispatch), not during setup.

## Requested changes and previous answers

For requested setup, preserve previous answers, existing prose, Foundry facts and known account/destination data while rewriting JSON into this single shape. Preserve removed preferences using the shared memory rule. Resolve conflicting answers first. This is agent-guided editing during requested setup, never a background rewrite or an old-shape runtime reader.

Requested account changes reuse answers. Save model preferences using the shared memory rule. Account scripts update exact channel bindings, and refuse to remove a last binding. The agent repairs affected prose references and reports unresolved wording. Move repository facts to that repository's workflow; record pending transfers for unopened repositories in Finish later. Re-read after every edit. Scripts never parse or rewrite notes.

In tests or an alternate home, substitute the chosen home for every `~`, pass `-HomeRoot <temp home>` to account/refresh/launcher scripts, and pass a full temp JSON `-Path` to validation. Fake all external tools. Never inspect real account folders.
