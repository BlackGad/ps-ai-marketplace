# Codex CLI limits

Check one explicit account at a time as the [read tools guide](../../legion-overseer/references/read-tools.md) describes; it pings the account, consumes quota and may be billable. Keep unknown readouts unknown; only this account's quota or window result can justify calling it exhausted.

Legion reads the account check; do not repeat it by hand. Codex is **not yet proven against Foundry**: the Azure token check (`token ok` or the Azure error) does not prove GPT deployment access or a working Codex session. Never use one account's result for another.
