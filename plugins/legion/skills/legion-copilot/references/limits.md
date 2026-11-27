# Copilot CLI limits

Check one explicit account at a time as the [read tools guide](../../legion-overseer/references/read-tools.md) describes; it pings the account and may be billable.

Copilot has no limit readout. A normal answer proves only that it can answer now. A network or authentication failure is `ping failed`, not exhaustion. Foundry's Azure token check does not prove deployment access or capacity and does not refresh a running agent's fixed token. Follow its expiry notice and restart with `legion run --account <id> -- --resume`. Never use one account's result for another.
