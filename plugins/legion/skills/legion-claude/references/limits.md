# Claude Code limits

Use the `limits` tool on the plugin's `legion` MCP server for one explicit account at a time. It pings each named account, consumes quota and may be billable. Read the [selection, side effects, timeout and fallback guide](../../legion-overseer/references/read-tools.md). If the server fails to start, use `legion limits --id <id> --timeout 20 --json`. Members never call these tools. Keep unknown readouts unknown; only this account's quota or window result can justify calling it exhausted.

Legion reads the account check; do not repeat it by hand. Foundry accounts have no subscription window: the Azure token check (`token ok` or the Azure error) does not prove deployment access or capacity. Never use one account's result for another.
