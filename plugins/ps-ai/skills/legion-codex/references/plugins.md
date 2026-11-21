# Codex plugins

After updating ps-ai, tell the owner to run `legion` in the repository to load the refreshed plugin copy.

The update uses `codex plugin marketplace upgrade` without a marketplace selector in each targeted account's environment, then updates ps-ai. Treat the marketplace step as refreshing all Git marketplaces in that account, including unrelated ones. Explain this scope before the owner approves an update; do not claim it targets only ps-ai's marketplace.

After the owner logs in to the selected account, use the account-specific [installer flow](accounts.md). For a manual install in that account's environment:

```text
codex plugin marketplace add BlackGad/ps-ai-marketplace --ref stable
codex plugin add ps-ai@ps-ai-marketplace
```

Optional llm-wiki setup is the owner's choice. Show these hints when requested; the shared knowledge skill never runs installs:

```text
codex plugin marketplace add nvk/llm-wiki
codex plugin add wiki@llm-wiki
```

After installation use the shared [wiki hub setup](../../legion-knowledge/references/llm-wiki-setup.md).

Plugin hooks run only after one-time trust. Start `codex` in the selected account and run `/hooks`. Repeated plugin installation preserves that trust.
