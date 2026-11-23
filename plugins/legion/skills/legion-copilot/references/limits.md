# Copilot CLI limits

Run `legion limits <id>` for the selected account (`legion limits` lists every account). Copilot CLI has no limit readout, so percentages and reset times show `unknown`. A quota error from the ping shows `limit reached`; a normal answer shows only that the account can answer now. A network or authentication failure is `ping failed`, not exhaustion.

legion runs the ping itself; do not repeat it by hand. Foundry accounts show the Azure token check (`token ok` or the Azure error); deployment access and capacity still need a real response. A new token check does not refresh a running Copilot agent's fixed token. Follow its expiry notice and restart with `<id> --resume`. Never use one account's result for another.
