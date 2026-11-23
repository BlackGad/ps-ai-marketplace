# Claude Code limits

Run `legion limits <id>` for the selected account (`legion limits` lists every account). It prints one table: window, used percentage, reset time and status. `unknown` means the tool gave no readout; never fill it in or declare the account exhausted from it.

legion runs the ping itself; do not repeat it by hand. Foundry accounts have no subscription window: the table shows the Azure token check (`token ok` or the Azure error), which does not prove deployment access or capacity. Never use one account's result for another.
