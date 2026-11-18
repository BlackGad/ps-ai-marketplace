# ps-ai-marketplace

The `ps-ai` plugin lets Claude Code, Codex CLI and GitHub Copilot CLI share one way of running multi-agent work in a repository. One session acts as the **overseer**: it plans, hands tasks to working agents on your other accounts, reviews their results and keeps a tracked handoff, so any of the three tools can pick the work up later. Working agents (the **legion**) do one task each and report back.

## Requirements

- PowerShell 7 (`pwsh`) on every machine. The Windows bootstrap can offer to install it; the other installers show a platform hint when it is missing.
- At least one of: Claude Code, Codex CLI, Copilot CLI.

## Install

On a clean Windows PC, download and extract the repository ZIP from GitHub if Git is not available. In Windows PowerShell 5.1, run:

```powershell
powershell -NoProfile -File .\ps-ai-marketplace\install\bootstrap.ps1
```

The bootstrap checks for PowerShell 7 first. If it is missing, it shows the `winget` command and asks before installing it. It then runs the plugin installer under `pwsh`. Running the bootstrap again skips the PowerShell step. If `winget` is missing, use the [official winget instructions](https://learn.microsoft.com/windows/package-manager/winget/) first.

If no coding CLI is installed yet, preview its official install command with `pwsh -NoProfile -File .\ps-ai-marketplace\plugins\ps-ai\bin\ps-ai-install-tool.ps1 -Tool claude` (or `codex` or `copilot`). After deciding to install, run that command with `-Yes`, then rerun the plugin installer. The same helper can show `git`, `gh`, `glab`, or `az` recipes; Linux recipes that need distribution-specific steps show official documentation. Tool and repository skills offer these as hints and ask before installation.

On Windows, the tool helper accepts `-Method winget`, `-Method msi`, or `-Method zip`. If winget is missing or fails, it prints both alternatives and exits 2. Choose a method, preview it, then add `-Yes` after approval. MSI/EXE installs may need admin; ZIP installs use `~/.agents/tools/<tool>/` and user PATH. Claude and Codex use their official install scripts for either alternative. Copilot uses npm when Node is present. See the [official sources and exceptions](plugins/ps-ai/skills/ps-ai-repository/references/tools.md).

On macOS or Linux, run `install/install.sh`; if `pwsh` is missing, it prints the platform's PowerShell installation hint.

```powershell
git clone https://github.com/BlackGad/ps-ai-marketplace
pwsh -NoProfile -File ps-ai-marketplace/install/install.ps1          # every installed CLI
pwsh -NoProfile -File ps-ai-marketplace/install/install.ps1 -Tools codex -ConfigDir <account folder>   # one extra account
```

On Linux or macOS, `install/install.sh` does the same. The installer is safe to run again: it skips steps that are already done.

Manual install per tool:

| Tool | Commands |
| --- | --- |
| Claude Code | `claude plugin marketplace add BlackGad/ps-ai-marketplace`, then `claude plugin install ps-ai@ps-ai-marketplace` |
| Codex CLI | `codex plugin marketplace add BlackGad/ps-ai-marketplace`, then `codex plugin add ps-ai@ps-ai-marketplace` |
| Copilot CLI | `copilot plugin marketplace add BlackGad/ps-ai-marketplace`, then `copilot plugin install ps-ai@ps-ai-marketplace` |

**Codex:** plugin hooks run only after you trust them once. Start `codex` and run `/hooks`.

## First run

Start any of the tools and ask it to set up your agent preferences. The `ps-ai-personalisation` skill asks a few questions, one at a time, and writes your personalisation:

- `~/.agents/configuration/ps-ai-personalisation.json`: your accounts, which account does which job, notification channels and projects. Validated against `plugins/ps-ai/schemas/personalisation.schema.json`. It never holds tokens.
- `~/.agents/configuration/ps-ai-notes.md`: free-form preferences and lessons.

Then, in a repository, ask it to set up orchestration. `ps-ai-repository` creates the `.agents/` layout below.

To open an overseer session with all your launch flags (for example a Telegram channel), run `ps-ai-overseer` in a terminal, or say "continue" in a session and accept the offer.

Foundry agents use one Azure endpoint per agent, such as `https://<resource>.cognitiveservices.azure.com`, and the owner's `az` login. Ask the matching tool skill to add an agent or "update models for <id>". It runs `ps-ai-account.ps1` with `-Action add -Tool <tool> -Id <id> -Provider foundry -Endpoint <url> -List` for add, or `-Action models -Id <id> -List` for updates, presents the deployments, and asks before saving `-Deployments`, `-Default`, and any Claude `-Aliases`. Copilot supports Claude deployments only, with a fixed token and an expiry notice; restart with `<id> --resume`. Codex is **not yet proven against Foundry**. Use [tools/foundry-probe.ps1](tools/foundry-probe.ps1) when an endpoint does not work.

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
claude plugin validate .
```

License: [MIT](LICENSE).

<!-- Naming: the owner is the Supreme Being; the overseer keeps the Great Tomb in order; the legion are the summoned; the floors are its lanes. Everything proceeds according to plan. -->
