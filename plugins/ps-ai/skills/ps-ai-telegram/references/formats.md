# Formats

Default to brief businesslike messages and explicit `markdownv2`. Notes override tone and format, including `text`. The plugin defaults to `text` if format is omitted; always choose explicitly. Supported formats are `text` and `markdownv2`. HTML is unsupported: explain and obtain a supported choice before sending.

Escape MarkdownV2 reserved characters outside code: `_ * [ ] ( ) ~ ` > # + - = | { } . !` with a backslash. Escape backslash and backtick inside code; escape backslash and closing parenthesis in a link URL. Prefer plain text for content that cannot be escaped reliably. Example JSON text: `"Connection test\\."`.

The plugin chunks text at Telegram's 4096-character message limit; formatted chunking may need shorter independently valid messages. Keep test text short. Images are inline photos; other attachments are documents, up to 50 MB each. See [reply schema](https://github.com/anthropics/claude-plugins-official/blob/main/external_plugins/telegram/server.ts).
