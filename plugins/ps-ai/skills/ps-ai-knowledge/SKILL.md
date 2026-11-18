---
name: ps-ai-knowledge
description: Use when overseer research begins, two attempts fail, a failure looks familiar, a milestone closes, or the owner asks what was learned elsewhere.
---

# Cross-project knowledge

## Identity and hard rules

Use this planner to decide when to consult or file durable, cross-project lessons. Load `ps-ai-personalisation` and its notes first. Read `knowledge.backend` and the project's neutral `label`; when backend is `none`, skip silently. The hub is `~/.agents/knowledge/` unless the owner's configured wiki location resolves elsewhere.

- Consult at research before planning, after two failed attempts at one problem, or when a failure looks familiar.
- File at milestone close-out and immediately after a hard problem is solved.
- Before filing, generalise and remove client names, source code, hosts, addresses, and secrets. Tag the entry with the project's neutral `label`. Rewrite an unsafe example or drop it.
- A lesson that changes future behavior also goes into `~/.agents/configuration/ps-ai-notes.md`; no workflow rule may depend only on the wiki.
- Never install llm-wiki or dependencies yourself.

## Consult or file

1. Confirm the hub exists. If it does not, offer the setup steps in [llm-wiki-setup.md](references/llm-wiki-setup.md) and stop.
2. For a lookup, follow [consult.md](references/consult.md). Cite the exact Markdown note path and say how the earlier lesson applies to the present issue.
3. For a new lesson, follow [file.md](references/file.md). Use the installed wiki skill if available; otherwise use the Markdown fallback in [no-plugin.md](references/no-plugin.md).
4. Re-read the stored note after filing and check the sanitising list. If it fails, fix or remove the unsafe entry before reporting completion.

## Stop conditions

If the hub is missing, offer setup and wait; never install it. If the lesson cannot be expressed without client details, do not file it. If backend is `none`, exit quietly.

## Verification

- [ ] Lookup cites the note actually read, or accurately reports no match.
- [ ] Filed lesson is general, tagged with the neutral label, and re-read for sensitive details.
- [ ] Behavior-changing lessons are also in `ps-ai-notes.md`.
