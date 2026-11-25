# Status and account limits

Use the `status` and `limits` tools on the plugin's `legion` MCP server first. If discovery or startup fails, use `legion status --json` or `legion limits --id <id> --timeout 20 --json`. Report that fallback. Members never call these tools.

For limits, choose account IDs from configuration, the owner's request and prose preferences. Scripts never parse notes. Ask only when scope or paid-use permission is unclear. Always pass an explicit, nonempty `accounts` list; omitted or empty selection never pings all accounts. Call once per account. Unknown results stay unknown.

Every limits call pings each named account with a real minimal prompt through its launcher, consumes quota and is billable on paid accounts. It creates and removes a disposable ping folder; Codex leaves a session record in the account's sessions folder. Foundry runs `az account get-access-token` instead and reports only the token check. This does not prove deployment access.

The CLI timeout defaults to 120 seconds per account. MCP accepts the same upper bound but caps probe work at 20 seconds per call to fit host timeouts, with time left for cleanup. A single-account default call works; a selection exceeding that budget is refused with “call limits once per account”. Use the CLI with `--timeout 20` to compare the same effective arguments. Cancelling a call or disconnecting stops its probes and removes ping folders. A new connection starts a new server process.
