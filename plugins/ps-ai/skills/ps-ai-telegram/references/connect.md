# Connection

The owner creates a bot with BotFather and configures it outside agent-visible input/output. The owner alone uses `/telegram:configure` and `/telegram:access` for configuration and pairing. Never ask for, read, print, store or forward tokens, pairing codes or credential files. Do not invoke configuration or pairing tools on the owner's behalf.

Start a channel-enabled session on the chosen account when needed. Use the canonical wrapper with `--channels plugin:telegram@claude-plugins-official`. Verify nonsecret connection evidence in that session. Obtain the destination from an incoming message's `chat_id`, never from credentials. Check each selected account independently. Several targets can reuse one account's integration. Different account folders retain separate integration state.

Save only verified `id/kind/target/accounts` in owner JSON. IDs use lowercase hyphenated names. `kind` is `telegram`; `target` is the verified chat ID as a string; `accounts` lists the configured supported account IDs. Keep existing destination data. Missing skill, unsupported tool or failed connection remains under Finish later in notes, with “Finish my ps-ai setup”.

Do not claim readiness before the text/image test and owner confirmation. Never send a background test. Repeated setup skips completed actions.
