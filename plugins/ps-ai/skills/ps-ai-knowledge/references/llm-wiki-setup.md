# Optional llm-wiki setup

The owner chooses whether to install llm-wiki. Explain the setup in plain words. Read the selected tool skill's `references/plugins.md` for supported installation hints; show commands only when requested or when the owner must run them themselves, and never run installs as part of this skill. If that reference has no recipe, do not invent one. The [llm-wiki installation guide](https://github.com/nvk/llm-wiki#install) is an optional owner resource.

After installation, in a wiki-capable session set the shared hub: `/wiki config hub-path "~/.agents/knowledge"`. This writes llm-wiki's own hub-path setting; it does not replace `ps-ai-personalisation.json`. The wiki can also be read directly as Markdown without the plugin.
