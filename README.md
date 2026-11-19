# ps-ai

ps-ai helps Claude Code, Codex CLI and Copilot CLI plan work, share tasks across your AI accounts and pick up where you left off. An overseer coordinates the work and reviews the results, so you can focus on what to do next.

## Install

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1)))
```

Run this in PowerShell to install ps-ai for your installed AI tools; it asks before installing missing prerequisites.

## What you can do

Open your AI tool and say:

- **Preferences and accounts:** “Set up my agent preferences.” “Add an account.” “Change my notification preferences.”
- **Repository setup:** “Set up orchestration in this repository.”
- **Work with the overseer:** “Continue.” “Next step.” “Next milestone.”
- **Azure Foundry agents:** “Add an Azure Foundry agent.” “Update models for agent-a.”
- **Account limits:** “Check limits for codex-a.”
- **ps-ai updates:** “Check for ps-ai updates.” “Update ps-ai.”
- **Shared lessons:** “What was learned elsewhere?”

## Update and uninstall

To update, just ask your AI tool: “Update ps-ai.”

To update by hand, run this in PowerShell:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Update
```

To uninstall by hand:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Uninstall
```

## Security

Legion workers are task agents that run without a sandbox, with your full user rights, so they can use your installed tools. Setup asks for your approval before enabling them. Workers are told to stay in their assigned repository, never push or install tools, and stop if a required tool is missing; these rules are instructions, not enforced access limits. To opt out, leave legion unused.

[Details for maintainers and power users](docs/reference.md).

License: [MIT](LICENSE).
