# Codex plugins

The update uses `codex plugin marketplace upgrade` without a marketplace selector in each targeted account's environment, then updates legion. Treat the marketplace step as refreshing all Git marketplaces in that account, including unrelated ones. Explain this scope before the owner approves an update; do not claim it targets only legion's marketplace.

After the owner logs in to the selected account, use the account-specific [installer flow](accounts.md). For a manual install in that account's environment:

```text
codex plugin marketplace add BlackGad/ps-legion-marketplace --ref stable
codex plugin add legion@ps-legion-marketplace
```

Optional llm-wiki setup is the owner's choice. Show these hints when requested; the shared knowledge skill never runs installs:

```text
codex plugin marketplace add nvk/llm-wiki
codex plugin add wiki@llm-wiki
```

After installation use the shared [wiki hub setup](../../legion-knowledge/references/llm-wiki-setup.md).

Plugin hooks run only after trust. Start `codex` in the selected account and run `/hooks`. Repeated plugin installation preserves that trust. Codex records trust against the hook and the script it runs, so a legion update that changes either asks for trust again: run `/hooks` once more after such an update.
