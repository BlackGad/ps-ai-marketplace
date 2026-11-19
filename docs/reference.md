# Technical reference

Installer options, CLI guides and repository details for maintainers and power users.

## Requirements

- PowerShell 7 (`pwsh`) on every machine. The installer offers to install it on Windows; on macOS and Linux, install it first using the official instructions linked below.
- At least one of: Claude Code, Codex CLI, Copilot CLI.

## Install

On Windows, run this in Windows PowerShell 5.1 or PowerShell 7 (`pwsh`):

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1)))
```

The script checks for PowerShell 7, which the plugin needs at runtime. If it is missing on Windows, the script shows `winget install --id Microsoft.PowerShell -e` and asks before installing. If winget is missing or fails, it offers the official per-user ZIP, verifies its SHA-256 digest, extracts it to `~/.agents/tools/pwsh/`, and adds that folder to the user and current process PATH. Use `-Yes` to approve installation without prompts.

On macOS or Linux, [install PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) first, then run:

```sh
pwsh -c '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1)))'
```

By default, the script installs ps-ai for every installed coding CLI, using the targets below. If none is installed, it prints the official CLI install commands and stops successfully. Install one and rerun the script. Repeated runs skip completed steps and preserve hook approval.

### Install and update targets

Plain install and `-Update` select the same targets:

- Without `-Tools`, select the CLIs found on PATH from `tools.json`. `-Tools` selects the named descriptors instead; update skips a selected CLI if its executable is missing.
- For each selected CLI, target its default config with the inherited account environment override cleared, then each matching `agents[].configDir` in `~/.agents/configuration/ps-ai-personalisation.json`. Ignore missing or blank `configDir` values and the value `default`; expand a leading `~/` or `~\` against the owner home and resolve recorded paths to full paths. Repeated recorded paths run once (case insensitive on Windows, case sensitive elsewhere).
- `-ConfigDir` replaces that folder list with only the supplied folder for each selected CLI. `-Tools` and `-ConfigDir` can be combined.
- Plain install skips completed steps. Update refreshes installed copies, including disabled ones; if ps-ai is missing, it uses the same marketplace registration and plugin installation steps as plain install. Missing recorded folders can be created by installation. `-DryRun` reads listings and previews mutations.

Uninstall keeps its existing selection: selected installed CLIs' defaults and recorded account folders, or only `-ConfigDir` when supplied, plus matching ps-ai generated files. It skips absent plugins and marketplace registrations and preserves account settings and logins.

Run the command below to update all selected targets. Restart the session afterward to load the new skills (Codex: resume).

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Update
```

### Installer parameters

For options, use the script-block form in PowerShell. This example selects an extra account:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools <tool-id> -ConfigDir <account folder>
```

Use `-Tools <tool-id>` (or an array of ids) to choose tools, `-Source <owner/repository>` to override the GitHub marketplace source, and `-DryRun` to print the steps without changing anything. The default source is `BlackGad/ps-ai-marketplace`. `-SourceRef` selects its catalog revision (default `main`). A working-tree script uses its sibling `tools.json` unless `-Source` or `-SourceRef` is supplied. Remote dry runs read that metadata once. It does not change the marketplace source passed to the CLI. Install and update dry runs execute read-only listings to detect existing registrations and plugins; displayed add and update commands are previews.

To adopt a signed-in account folder, say “Add my existing Claude account in ~/.claude-account2.” Account setup uses `ps-ai-account.ps1 -Action add -Tool <tool-id> -Id <id> -ConfigDir <existing folder>` to record the folder and create a shortcut for it. The folder must exist; setup preserves its settings and does not run or request a new login. An existing shortcut can instead be recorded with `-Action register -Command <wrapper> -ConfigDir <folder>`. Both flows install ps-ai through this installer after the owner's yes; see the tool account guides below.

### Version checks and catalog revisions

Overseer sessions check for a newer ps-ai version once a day and show a notice when one is available. Say "check ps-ai updates" for a fresh check, or "update ps-ai" to see the update command and approve running it. Checks never install updates. Checks and generated update commands follow `main` in `BlackGad/ps-ai-marketplace`, including after an installation using a tagged installer or catalog. The shared checker is `pwsh -NoProfile -File <plugin>/bin/ps-ai-update.ps1 -Check [-Force]`; `-Force` refreshes `~/.agents/temp/ps-ai-update.json` and reports check failures.

To run a specific installer and matching catalog revision, replace `<release-tag>` with a published release tag. This does not pin the installed plugin or future updates:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/<release-tag>/install.ps1))) -SourceRef <release-tag> -Tools <tool-id>
```

### Prerequisites and CLI guides

For optional prerequisite hints, use `pwsh -NoProfile -File <plugin>/bin/ps-ai-install-tool.ps1 -Tool <helper-id>`, replacing `<plugin>` with the installed ps-ai plugin directory. When working from a clone, that directory is `./plugins/ps-ai`. Add `-Yes` only after choosing to install. See [repository helper sources and approval policy](../plugins/ps-ai/skills/ps-ai-repository/references/tools.md).

Use the dedicated tool guides for CLI installation, account setup, plugin commands, and provider limitations:

- Claude Code: [installation](../plugins/ps-ai/skills/ps-ai-claude/references/install.md), [accounts](../plugins/ps-ai/skills/ps-ai-claude/references/accounts.md), [plugins and hooks](../plugins/ps-ai/skills/ps-ai-claude/references/plugins.md).
- Codex CLI: [installation](../plugins/ps-ai/skills/ps-ai-codex/references/install.md), [accounts](../plugins/ps-ai/skills/ps-ai-codex/references/accounts.md), [plugins and hook trust](../plugins/ps-ai/skills/ps-ai-codex/references/plugins.md).
- Copilot CLI: [installation and plugin commands](../plugins/ps-ai/skills/ps-ai-copilot/references/install.md), [accounts](../plugins/ps-ai/skills/ps-ai-copilot/references/accounts.md).

### Manual CLI installation

Run these in the selected account's environment after logging in. The linked tool guides cover account selection and hook approval.

Claude Code:

```text
claude plugin marketplace add BlackGad/ps-ai-marketplace
claude plugin install ps-ai@ps-ai-marketplace
```

Codex CLI:

```text
codex plugin marketplace add BlackGad/ps-ai-marketplace
codex plugin add ps-ai@ps-ai-marketplace
```

Copilot CLI:

```text
copilot plugin marketplace add BlackGad/ps-ai-marketplace
copilot plugin install ps-ai@ps-ai-marketplace
```

Codex hooks need one-time trust through `/hooks` in the selected account. Reinstalling preserves trust. Codex updates refresh all Git marketplaces in that account, including unrelated ones.

## Uninstall

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Uninstall
```

Shows the targets and generated files before asking. Use `-Yes` to skip the prompt, `-DryRun` to preview, or `-Tools` and `-ConfigDir` to narrow targets. Removes ps-ai and its marketplace registration, plus its generated account and overseer launchers and copied runtime in `~/.agents/bin` (shared files stay while other account launchers need them). Keeps `~/.agents/configuration` (settings and notes), account folders and logins, repositories, and the CLIs themselves. The script prints the kept locations so you can delete data by hand.

## First run

Start any of the tools and ask it to set up your agent preferences. The `ps-ai-personalisation` skill asks a few questions, one at a time, and writes your personalisation:

- `~/.agents/configuration/ps-ai-personalisation.json`: your accounts, which account does which job, notification channels and projects. Validated against `plugins/ps-ai/schemas/personalisation.schema.json`. It never holds tokens.
- `~/.agents/configuration/ps-ai-notes.md`: free-form preferences and lessons.

Then, in a repository, ask it to set up orchestration. `ps-ai-repository` creates the `.agents/` layout below.

To open an overseer session with all your launch flags (for example a Telegram channel), run `ps-ai-overseer` in a terminal, or say "continue" in a session and accept the offer.

Foundry agents use one Azure endpoint per agent, such as `https://<resource>.cognitiveservices.azure.com`, and the owner's `az` login. Use the matching account guide linked above to add an agent or ask "update models for <id>". Discovery presents deployments before the owner chooses what to save.

Manage legion accounts through the account's tool skill:

| Say | Action |
| --- | --- |
| “extend the legion”, “add a minion”, “add a legion member”, “recruit”, “new worker” | Add a legion account |
| Change a minion's model, rename, rebind a channel | Update a legion account |
| “dismiss”, “retire a minion”, “remove from the legion” | Remove a legion account |

## Modes

The `ps-ai` plugin lets Claude Code, Codex CLI and GitHub Copilot CLI share one way of running multi-agent work in a repository. One session acts as the **overseer**: it plans, hands tasks to working agents on your other accounts, reviews their results and keeps a tracked handoff, so any of the three tools can pick the work up later. Working agents (the **legion**) do one task each and report back.

A hook at session start decides the mode:

| Mode | When | What happens |
| --- | --- | --- |
| Legion | The overseer started this process with `PS_AI_ROLE=legion` and `PS_AI_TASK` | One task, local commits, a report; no other agents |
| Overseer | You say continue, progress or next in a repo with `.agents/state/` | Takes the lease, reads the handoff, continues the work |
| Setup | You ask to set up orchestration | Creates the repo layout and registers the project |
| Ad hoc | Anything else | Nothing changes; an orchestrated repo shows one hint line |

A session you start yourself is never a legion member.

## Security: legion runs without a sandbox

Legion workers run with your full user rights so they can edit, run checks, and commit using your installed SDKs, user PATH, and tools. Sandboxes can hide installed tools; agents then download their own SDKs and drift from your machine's setup. Setup explains this and asks for your yes before saving the first legion routing.

The overseer starts legion only inside an assigned repository worktree and only for planned tasks. Workers must stay inside that repository or worktree, never push or touch other folders, and never download or install an SDK, runtime, package manager, or tool. If a needed tool is missing or the wrong version, they stop and report it so the overseer can ask you. These safeguards are instructions, not an enforced access boundary. Reviewer runs keep their read-only restrictions.

To opt out, leave legion unused. To limit its use, route legion only to accounts you trust.

## Files and folders

| What | Where | Tracked |
| --- | --- | --- |
| Personalisation and notes | `~/.agents/configuration/` | no |
| Launcher and account wrappers | `~/.agents/bin/` | no |
| New account config folders (adopted folders keep their names) | `~/.legion-<id>/` | no |
| Portable prerequisite tools | `~/.agents/tools/<tool>/` | no |
| Cross-project knowledge wiki (optional, llm-wiki) | `~/.agents/knowledge/` | no |
| Repo workflow configuration | `<repo>/.agents/configuration/` (`project.json`, `workflow.md`) | yes |
| Repo scripts and their index | `<repo>/.agents/scripts/`, `index.md` | yes |
| Overseer state | `<repo>/.agents/state/handoff.md`, `history/` | yes |
| Local specs and plans | `<repo>/.agents/docs/specs/`, `plans/` | no |
| Agent scratch files | `<repo>/.agents/temp/` | no |

## Skills

| Skill | Job |
| --- | --- |
| `ps-ai-personalisation` | Your accounts, routing, channels and projects |
| `ps-ai-repository` | Repo layout, scripts index, rules-file block |
| `ps-ai-overseer` | Takeover, milestone flow, task loop, reviews, handoff |
| `ps-ai-legion` | The working agent's contract and report |
| `ps-ai-knowledge` | Consult and grow the cross-project wiki |
| `ps-ai-update` | Check versions and update ps-ai after approval |
| `ps-ai-claude`, `ps-ai-codex`, `ps-ai-copilot` | Run each CLI, check its limits, add or rename accounts |

## Works with method skills

ps-ai decides who does the work, where, and where the record lives. How one piece of work is done (brainstorming, planning, test-driven development, debugging, code review) comes from the method skills you have installed, such as superpowers. The repo rules block that `ps-ai-repository` adds sends tasks to your legion accounts and plans to the repo's configured paths.

## Development

CLIs cache plugin copies by version. For changes shipped to agents, bump the version together in `plugins/ps-ai/plugin.json`, `plugins/ps-ai/.claude-plugin/plugin.json` and `plugins/ps-ai/.codex-plugin/plugin.json`. Restart Claude Code and Copilot CLI sessions after updating; resume the Codex session to load its refreshed copy.

Repository rules are in [AGENTS.md](../AGENTS.md). Specs, plans and verification notes stay local in the ignored `docs/specs/`, `docs/plans/`, `docs/superpowers/` and `docs/verification/` folders. Scratch files, logs, reports and worktrees belong in `.agents/temp/`. Keep `docs/reference.md` tracked.

Run the test suite from the repository root. Tests use fakes and must not call real coding CLIs, Azure CLI, winget or the network. The last line must be `<n> passed, 0 failed`.


```powershell
pwsh -NoProfile -File tests/run.ps1
```

License: [MIT](../LICENSE).
