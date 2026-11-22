# Bot folder

The overseer launcher starts a session with a Telegram channel with `TELEGRAM_STATE_DIR` set to `~/.legion/channels/telegram/<channel id>` (the `state` entry in `channel.json`) and any inherited `TELEGRAM_BOT_TOKEN` removed. The variable is part of the launched command line, so a new Windows Terminal tab gets it too.

`-DryRun` prints `env TELEGRAM_STATE_DIR=<folder>`. Two Telegram channels in one launch are refused. The plugin reads the token only at start: after /telegram:configure, run /reload-plugins or restart. If the bot still does not answer, open /mcp, choose plugin:telegram:telegram and Reconnect (seen live: the server did not start in a fresh session until reconnected).

`pwsh -NoProfile -File <plugin>/bin/legion-channel.ps1 -Action check -Kind telegram -Accounts <ids>` also prints `<channel>  bot folder: ready` or `bot folder: missing token (run /telegram:configure in that session)`. It only looks for the token file and never reads it.

`-Action add` refuses a Foundry account: channels are not available on third-party providers.
