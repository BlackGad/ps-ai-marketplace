# Interactive overseer launch

Read owner notes before choosing an account and actual model. Follow exclusions, careful use and paid-use approval. Re-read after edits. Any chosen session may oversee without channels.

```powershell
pwsh -NoProfile -File <plugin>/bin/ps-ai-overseer.ps1 -Account <id> -Tool copilot -Repo <repo> -Arguments @('--model', '<chosen-model>', '<argument>', 'two words', '')
```

`-Account` is required; bare invocation prints usage. Commands are derived from the canonical wrapper. `-Arguments` preserves each literal array element. Pass the chosen model as CLI flags in `-Arguments`. The CLI validates those flags. Explicit arguments precede channel vectors, interactive arguments and the initial prompt. No saved account or project launch preferences are read.

For destinations, follow the selected `skills/ps-ai-<kind>/SKILL.md`. Pass explicit `-Channel <id[]>` only after setup. Missing support, tools or bindings fail before launch. Same-kind destinations resolve independently while their kind/account launch vector is emitted once. Never silently switch accounts; name an eligible alternate before relaunch.

Copilot keeps `-i` immediately before the prompt. Its Foundry runner cannot automatically select a saved default; choose the model in its picker.
