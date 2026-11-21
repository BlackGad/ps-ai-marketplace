# Claude plugins

After updating ps-ai, tell the owner to run `legion` in the repository to load the new skills.

After the owner logs in to the selected account, use the account-specific [installer flow](accounts.md). For a manual install in that account's environment:

```text
claude plugin marketplace add BlackGad/ps-ai-marketplace#stable
claude plugin install ps-ai@ps-ai-marketplace
```

Optional llm-wiki setup is the owner's choice. Show these hints when requested; the shared knowledge skill never runs installs:

```text
claude plugin marketplace add nvk/llm-wiki
claude plugin install wiki@llm-wiki
```

After installation use the shared [wiki hub setup](../../ps-ai-knowledge/references/llm-wiki-setup.md).
