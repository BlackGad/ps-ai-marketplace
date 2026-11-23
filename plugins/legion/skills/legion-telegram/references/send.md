# Sending

Read notes and [formats.md](formats.md). Resolve every requested destination separately with `Resolve-LegionChannel`; use its `Target` with the connected session's tool. Do not collapse two same-kind destinations. Verify that the session account is bound and that the session exposes the expected tools. Claude sessions send only through the plugin tools below; never call the Bot API directly from Claude. Codex has no plugin: it uses `legion-py telegram send` and `react` from the Codex section, which read the token inside their own process.

The supported session contract is `reply(chat_id, text, format, reply_to?, files?)`. Inspect the actual tool definition before use. Always supply `chat_id`, `text`, and explicit `format`. `reply_to` is an optional message ID; `files` is an array of absolute paths. Images appear inline; other files are documents. The plugin returns sent message IDs. It supports files up to 50 MB each.

The Telegram plugin's `react` tool sets a reaction on a message. Telegram accepts only its fixed reaction set (for example 👍 👌 🫡 🔥 👀 ✍️); any other emoji fails.

After agreeing the test text, call the connected tool with these fields (substitute the resolved target and absolute bundled path):

```json
{"chat_id":"123","text":"Connection test\\.","format":"markdownv2","files":["<skill-root>/assets/test.png"]}
```

For a second target or notes selecting plain text:

```json
{"chat_id":"456","text":"Connection test.","format":"text","files":["<skill-root>/assets/test.png"]}
```

Check the attachment exists first. Inspect delivery evidence for each resolved target and both text and image. Ask the owner to confirm both arrived. If evidence or confirmation is missing, record incomplete work. Automated fake evidence never establishes live connectivity.

## Codex

On Codex the channel is the bridge: when `TELEGRAM_STATE_DIR` is set, Telegram is connected even though no plugin tools exist. Owner messages arrive in the inbox (read it as the legion-overseer inbox reference says) as `from: telegram` with an indented body whose first line is `telegram chat_id=<id> message_id=<id> user=<name>`. Reply with the chat id from that line, through `Invoke-LegionPython`; print its `Output` and `Error` as that reference shows:

```text
telegram send --channel <id> --chat <chat id> --text <text> [--format text|markdownv2] [--reply-to <message id>] [--file <path>]...
telegram react --channel <id> --chat <chat id> --message <message id> --emoji <emoji>
```

`send` prints only the sent message ids and splits text over 4096 characters. A Bot API error prints one plain line and exits non-zero.
