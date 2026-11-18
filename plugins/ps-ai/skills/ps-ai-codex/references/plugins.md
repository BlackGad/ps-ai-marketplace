# Codex plugins

After the owner logs in to the selected account, use the account-specific [installer flow](accounts.md). For a manual install in that account's environment:

```text
codex plugin marketplace add BlackGad/ps-ai-marketplace
codex plugin add ps-ai@ps-ai-marketplace
```

Optional llm-wiki setup is the owner's choice. Show these hints when requested; the shared knowledge skill never runs installs:

```text
codex plugin marketplace add nvk/llm-wiki
codex plugin add wiki@llm-wiki
```

After installation use the shared [wiki hub setup](../../ps-ai-knowledge/references/llm-wiki-setup.md).

Plugin hooks run only after one-time trust. Start `codex` in the selected account and run `/hooks`. Repeated plugin installation preserves that trust.
