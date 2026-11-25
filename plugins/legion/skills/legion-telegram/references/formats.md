# Formats

Use the tone and format in the owner's notes. When the notes leave either unspecified, use a brief businesslike tone or `markdownv2` for that preference. Always pass the selected format explicitly. Supported formats are `text` and `markdownv2`. HTML is unsupported. Explain and obtain a supported choice before sending.

When using MarkdownV2, use short paragraphs, bullets or bold labels where they help the owner scan the update. Escape literal reserved characters outside code with a backslash: `` _ * [ ] ( ) ~ ` > # + - = | { } . ! \ ``. Escape backslash and backtick inside code, and backslash and closing parenthesis in a link URL. If the message is hard to escape, simplify the markup and keep the chosen format. Example JSON text: `"Connection test\\."`.

The plugin chunks text at Telegram's 4096-character message limit; formatted chunking may need shorter independently valid messages. Keep test text short. Images are inline photos; other attachments are documents, up to 50 MB each. See [reply schema](https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/telegram/server.ts).
