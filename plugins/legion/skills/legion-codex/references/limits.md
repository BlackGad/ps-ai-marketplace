# Codex CLI limits

Run `legion limits <id>` for the selected account (`legion limits` lists every account). It prints one table: window, used percentage, reset time and status. `unknown` means the tool gave no readout; never fill it in. Only `limit reached` (a quota error, with its retry time) or a window status from this account can justify calling it exhausted.

legion runs the account check and reads its result; do not repeat it by hand. Codex is **not yet proven against Foundry**: a Foundry account shows the Azure token check (`token ok` or the Azure error), which does not prove GPT deployment access or a working Codex session. Never use one account's result for another.
