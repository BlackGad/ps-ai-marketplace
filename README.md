# ps-ai-marketplace

The `ps-ai` plugin lets Claude Code, Codex CLI and GitHub Copilot CLI share one way of running multi-agent work in a repository. One session acts as the **overseer**: it plans, hands tasks to working agents on your other accounts, reviews their results and keeps a tracked handoff, so any of the three tools can pick the work up later. Working agents (the **legion**) do one task each and report back.

## Requirements

- PowerShell 7 (`pwsh`) on every machine. The installer offers to install it on Windows; on macOS and Linux, install it first using the official instructions linked below.
- At least one of: Claude Code, Codex CLI, Copilot CLI.

## Install

On Windows, run this in Windows PowerShell 5.1 or PowerShell 7 (`pwsh`):

```powershell
irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1 | iex
```

The script checks for PowerShell 7, which the plugin needs at runtime. If it is missing on Windows, the script shows `winget install --id Microsoft.PowerShell -e` and asks before installing. If winget is missing or fails, it offers the official per-user ZIP, verifies its SHA-256 digest, extracts it to `~/.agents/tools/pwsh/`, and adds that folder to the user and current process PATH. Use `-Yes` to approve installation without prompts.

On macOS or Linux, [install PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) first, then run:

```sh
pwsh -c "irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1 | iex"
```

By default, the script installs ps-ai for every installed coding CLI. If none is installed, it prints the official CLI install commands and stops successfully. Install one and rerun the script. Repeated runs skip completed steps and preserve hook approval.

To refresh installed ps-ai copies in every CLI's default config and every recorded account folder, run the command below; `-Tools` and `-ConfigDir` narrow the targets, and `-DryRun` previews commands. Restart agents afterward to load the new skills. During development, Claude and Copilot can load the working copy directly with `--plugin-dir ./plugins/ps-ai`.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Update
```

For options, use the script-block form in PowerShell. This example selects an extra account:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools <tool-id> -ConfigDir <account folder>
```

Use `-Tools <tool-id>` (or an array of ids) to choose tools, `-Source <repository or local path>` to override the marketplace source, and `-DryRun` to print the steps without changing anything. Local sources resolve to an absolute path. The default source is `BlackGad/ps-ai-marketplace`. `-SourceRef` selects its catalog revision (default `main`); local sources must contain the generated `tools.json`. Remote dry runs read that metadata once. It does not change the marketplace source passed to the CLI.

To pin the installer, replace `<release-tag>` with a published release tag:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/<release-tag>/install.ps1))) -SourceRef <release-tag> -Tools <tool-id>
```

For optional prerequisite hints, use `pwsh -NoProfile -File ./plugins/ps-ai/bin/ps-ai-install-tool.ps1 -Tool <helper-id>`. Add `-Yes` only after choosing to install. See [repository helper sources and approval policy](plugins/ps-ai/skills/ps-ai-repository/references/tools.md).

Use the dedicated tool guides for CLI installation, account setup, plugin commands, and provider limitations:

- Claude Code: [installation](plugins/ps-ai/skills/ps-ai-claude/references/install.md), [accounts](plugins/ps-ai/skills/ps-ai-claude/references/accounts.md), [plugins and hooks](plugins/ps-ai/skills/ps-ai-claude/references/plugins.md).
- Codex CLI: [installation](plugins/ps-ai/skills/ps-ai-codex/references/install.md), [accounts](plugins/ps-ai/skills/ps-ai-codex/references/accounts.md), [plugins and hook trust](plugins/ps-ai/skills/ps-ai-codex/references/plugins.md).
- Copilot CLI: [installation and plugin commands](plugins/ps-ai/skills/ps-ai-copilot/references/install.md), [accounts](plugins/ps-ai/skills/ps-ai-copilot/references/accounts.md).

## First run

Start any of the tools and ask it to set up your agent preferences. The `ps-ai-personalisation` skill asks a few questions, one at a time, and writes your personalisation:

- `~/.agents/configuration/ps-ai-personalisation.json`: your accounts, which account does which job, notification channels and projects. Validated against `plugins/ps-ai/schemas/personalisation.schema.json`. It never holds tokens.
- `~/.agents/configuration/ps-ai-notes.md`: free-form preferences and lessons.

Then, in a repository, ask it to set up orchestration. `ps-ai-repository` creates the `.agents/` layout below.

To open an overseer session with all your launch flags (for example a Telegram channel), run `ps-ai-overseer` in a terminal, or say "continue" in a session and accept the offer.

Foundry agents use one Azure endpoint per agent, such as `https://<resource>.cognitiveservices.azure.com`, and the owner's `az` login. Use the matching account guide linked above to add an agent or ask "update models for <id>". Discovery presents deployments before the owner chooses what to save.

## Modes

A hook at session start decides the mode:

| Mode | When | What happens |
| --- | --- | --- |
| Legion | The overseer started this process with `PS_AI_ROLE=legion` and `PS_AI_TASK` | One task, local commits, a report; no other agents |
| Overseer | You say continue, progress or next in a repo with `.agents/state/` | Takes the lease, reads the handoff, continues the work |
| Setup | You ask to set up orchestration | Creates the repo layout and registers the project |
| Ad hoc | Anything else | Nothing changes; an orchestrated repo shows one hint line |

A session you start yourself is never a legion member.

## Files and folders

| What | Where | Tracked |
| --- | --- | --- |
| Personalisation and notes | `~/.agents/configuration/` | no |
| Launcher and account wrappers | `~/.agents/bin/` | no |
| Extra account config folders | `~/.agents/accounts/<id>/` | no |
| Cross-project knowledge wiki (optional, llm-wiki) | `~/.agents/knowledge/` | no |
| Repo workflow configuration | `<repo>/.agents/configuration/` (`project.json`, `workflow.md`) | yes |
| Repo scripts and their index | `<repo>/.agents/scripts/`, `index.md` | yes |
| Overseer state | `<repo>/.agents/state/handoff.md`, `history/` | yes |
| Agent scratch files | `<repo>/.agents/temp/` | no |

## Skills

| Skill | Job |
| --- | --- |
| `ps-ai-personalisation` | Your accounts, routing, channels and projects |
| `ps-ai-repository` | Repo layout, scripts index, rules-file block |
| `ps-ai-overseer` | Takeover, milestone flow, task loop, reviews, handoff |
| `ps-ai-legion` | The working agent's contract and report |
| `ps-ai-knowledge` | Consult and grow the cross-project wiki |
| `ps-ai-claude`, `ps-ai-codex`, `ps-ai-copilot` | Run each CLI, check its limits, add or rename accounts |

## Works with method skills

ps-ai decides who does the work, where, and where the record lives. How one piece of work is done (brainstorming, planning, test-driven development, debugging, code review) comes from the method skills you have installed, such as superpowers. The repo rules block that `ps-ai-repository` adds sends tasks to your legion accounts and plans to the repo's configured paths.

## Development

```powershell
pwsh -NoProfile -File tests/run.ps1
```

License: [MIT](LICENSE).

<!-- Naming: the owner is the Supreme Being; the overseer keeps the Great Tomb in order; the legion are the summoned; the floors are its lanes. Everything proceeds according to plan. -->
