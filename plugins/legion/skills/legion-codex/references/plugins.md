# Codex plugins

With knowledge enabled, the update targets the Legion marketplace in each selected account. Otherwise `codex plugin marketplace upgrade` refreshes all configured Git marketplaces in that account. Explain the scope before the owner approves an update.

After the owner logs in to the selected account, use the account-specific [installer flow](accounts.md). For a manual install in that account's environment:

```text
codex plugin marketplace add BlackGad/ps-legion-marketplace --ref stable
codex plugin add legion@ps-legion-marketplace
```

Plugin hooks run only after trust. Start `codex` in the selected account and run `/hooks`. Repeated plugin installation preserves that trust. Codex records trust against the hook and the script it runs, so a legion update that changes either asks for trust again: run `/hooks` once more after such an update.
