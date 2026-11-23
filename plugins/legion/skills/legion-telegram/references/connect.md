# Connection

The owner creates a bot with BotFather and configures it outside agent-visible input/output. The owner alone uses `/telegram:configure` and `/telegram:access` for configuration and pairing. Never ask for, read, print, store or forward tokens, pairing codes or credential files. Do not invoke configuration or pairing tools on the owner's behalf.

Start a channel-enabled session on the chosen account when needed. For a second bot, start it with the legion overseer launcher for that channel (`pwsh -NoProfile -File <plugin>/bin/legion-overseer.ps1 -Account <id> -Tool claude -Channel <id> -Repo <repo>`, which sets the bot folder), never with the bare account wrapper: the wrapper would configure the account's default bot folder instead. The session uses `--channels plugin:telegram@claude-plugins-official`. Verify nonsecret connection evidence in that session. Obtain the destination from an incoming message's `chat_id`, never from credentials. Check each selected account independently. Several targets can reuse one account's integration. Different account folders retain separate integration state.

Save only a verified binding with `pwsh -NoProfile -File <plugin>/bin/legion-channel.ps1 -Action add -Id <id> -Kind telegram -Target <chat_id> -Accounts <ids>` (IDs are lowercase hyphenated; the target is the verified chat ID). A repeat prints `skip:`; `-Action remove -Id <id>` removes it. Keep existing destination data. A missing skill, unsupported tool or failed connection stays under Finish later in notes, with “Finish my legion setup”.

Do not claim readiness before the text/image test and owner confirmation. Never send a background test. Repeated setup skips completed actions.
