# Optional llm-wiki setup

The owner chooses whether to install llm-wiki. Show these commands; never run them as part of this skill. The [llm-wiki installation guide](https://github.com/nvk/llm-wiki#install) currently documents:

```text
claude plugin marketplace add nvk/llm-wiki
claude plugin install wiki@llm-wiki

codex plugin marketplace add nvk/llm-wiki
codex plugin add wiki@llm-wiki
```

After installation, in a wiki-capable session set the shared hub: `/wiki config hub-path "~/.agents/knowledge"`. This writes llm-wiki's own hub-path setting; it does not replace `ps-ai-personalisation.json`. The wiki can also be read directly as Markdown without the plugin.
