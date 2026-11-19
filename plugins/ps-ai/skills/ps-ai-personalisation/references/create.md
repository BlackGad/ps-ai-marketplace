# Create or finish owner configuration

1. Read existing settings and notes. Reuse previous answers. Ask language and question cadence first; save stated preferences in notes. Ask one question at a time unless told otherwise. Current instructions win. None/later is valid for accounts, models, channels and knowledge.

2. Ask tools, account names, existing folders and shortcuts. Resolve conflicts before replacing files. Create `<home>/.agents/configuration/ps-ai-personalisation.json` before helpers with `{"schemaVersion":1,"agents":[],"channels":[]}`. Use the optional stable schema URL in [fields.md](fields.md). Validate against the bundled schema.

3. Read `skills/ps-ai-<agent.tool>/SKILL.md` for each selected account; stop if missing. Preview missing CLI installs and per-account ps-ai installs, then wait for yes. Use existing approval. Deduplicate installation by normalized config folder. Use the tool's account guide for add/adopt/register. Resolve a previous default-folder answer through `tool.plugin.defaultConfigDir` to a concrete folder. Expand `~/` against the chosen home. Registration creates a canonical wrapper around the adopted shortcut; keep the external shortcut, settings and login. Only new accounts need owner login. Declined or failed installs stay incomplete under Finish later.

4. Ask each account's actual available models, purposes and exclusions. Ask legion/reviewer order and careful/paid-use choices. Save ordinary sentences in notes, never roles, model preferences or launch defaults in JSON. Do not invent models. Explain the access boundary below and obtain yes before the first usable legion choice. Decline/later leaves legion unused. Add no consent or status field.

5. Ask channels, including none/later. Discover channel descriptors and route chosen kinds through `skills/ps-ai-<kind>/SKILL.md`; stop if missing. That skill owns support checks, install previews, approvals, connection, owner-only pairing, target-specific text/image tests and verified bindings. Deduplicate setup by kind/account and installs by normalized folder. Save only verified `id/kind/target/accounts`; no failed account is ready. Never request, read, print or store tokens.

6. Ask notification timing, destinations, tone and supported format preferences. Save notes; they override kind defaults. Unsupported choices need clarification. Keep unfinished connections and open model choices under Finish later with “Finish my ps-ai setup”. No completion claim while work is open.

7. Ask whether and where to use shared knowledge. Save only the answer in notes. The knowledge skill can guide setup; it never installs the wiki itself.

8. Re-read JSON and notes, validate JSON, and summarize accounts, channels, stated preferences and open items. Make the launcher available through [launcher.md](launcher.md) if requested. Repeated setup skips completed actions with `skip: <what> (already done)` and preserves completed files byte-for-byte.

## Legion access explanation

Before the first usable legion choice, explain and ask:

“Legion workers run without a sandbox and with your full user rights, so they can edit, run checks, and commit using your installed tools. Sandboxes can hide installed tools; agents then download their own SDKs and drift from your machine's setup. Workers must stay inside their assigned repository or worktree, never push or touch other folders, and never download or install SDKs, runtimes, package managers, or tools. If a tool is missing or the wrong version, they stop and report it so the overseer can ask you. These are instructions, not an enforced access boundary. Route legion only to accounts you trust, or leave legion unused. Do you want to enable legion routing?”

Wait for yes; reuse an explicit answer already given. Workers stay inside the assigned repository/worktree, never push or install tools. Missing or incorrect tools are reported. These instructions do not enforce an access boundary.

## Requested changes and previous answers

For requested setup, preserve previous answers, existing prose, Foundry facts and known account/destination data while rewriting JSON into this single shape. Preserve removed preferences in notes. Resolve conflicting answers first. This is agent-guided editing during requested setup, never a background rewrite or an old-shape runtime reader.

Requested add/remove/rename/model changes reuse answers. Account scripts update exact channel bindings, and refuse to remove a last binding. The agent repairs affected prose references and reports unresolved wording. Move repository facts to that repository's workflow; record pending transfers for unopened repositories in Finish later. Re-read after every edit. Scripts never parse or rewrite notes.

In tests or an alternate home, substitute the chosen home for every `~`, pass `-HomeRoot <temp home>` to account/refresh/launcher scripts, and pass a full temp JSON `-Path` to validation. Fake all external tools. Never inspect real account folders.
