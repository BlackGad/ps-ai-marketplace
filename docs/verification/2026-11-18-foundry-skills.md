# Foundry skills: fresh-agent check (2026-11-18)

A fresh Sonnet agent with only the plugin's skills and scripts, a sandbox home and the fake `az` (`tests/fixtures/fake-az`) got two owner requests. It had no spec, plan or test access.

## "Add a Foundry Claude agent called claude-dev for https://res-a.cognitiveservices.azure.com/anthropic" — PASS

- Chose `ps-ai-claude`, section "Foundry agent" in `references/accounts.md`.
- Ran `-Action add ... -List` first; wrote nothing; showed 3 Claude deployments (gpt and embedding hidden).
- Asked keep / aliases / default one question at a time and showed the full command before running it.
- After approval: entry with trimmed endpoint, models, aliases and default; wrappers, runner, helper and `settings.json` `modelPicker` created; validation clean.
- Gap found and fixed: a successful Foundry `add` printed nothing; it now prints `Run '<id>' in a terminal; it signs in to Azure through az when needed.`
- Note: `add` has no roles parameter (same as subscription agents); the agent set `roles` by editing the JSON, as the personalisation skill allows.

## "Update models for claude-dev" after one deployment was deleted in Azure — PASS

- Ran `-Action models -Id claude-dev -List`; showed `claude-sonnet-x` as `gone`, the other two `kept`, nothing `new`.
- Asked whether to drop it, about the freed alias and the default, then showed the `-Action models` command to run after the answer.
