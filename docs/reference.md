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

The script checks for PowerShell 7, which the plugin needs at runtime. If it is missing on Windows, the script shows `winget install --id Microsoft.PowerShell -e` and asks before installing. If winget is missing or fails, it offers the official per-user ZIP, verifies its SHA-256 digest, extracts it to `~/.legion/tools/pwsh/`, and adds that folder to the process PATH, and to the user PATH only after you agree. Before installing ps-ai, the script asks once: `Install ps-ai for <tools> now? [y/N]`. Use `-Yes` to skip every question. `-Update`, `-Uninstall` and `-DryRun` do not ask this question. `-Update` asks its own question for a folder where ps-ai is missing (see Install and update targets).

On macOS or Linux, [install PowerShell 7](https://learn.microsoft.com/powershell/scripting/install/installing-powershell) first, then run:

```sh
pwsh -c '& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1)))'
```

By default, the script installs ps-ai for every installed coding CLI, using the targets below. If none is installed, it prints the official CLI install commands and stops successfully. Install one and rerun the script. Repeated runs skip completed steps and preserve hook approval.

### Install and update targets

Plain install and `-Update` select the same targets:

- Without `-Tools`, select the CLIs found on PATH from `tools.json`. `-Tools` selects the named descriptors instead; update skips a selected CLI if its executable is missing.
- For each selected CLI, the default folder is the one named by the CLI's account environment variable when it is set (for example `CLAUDE_CONFIG_DIR`). When it is not set, the CLI's own default runs with that variable cleared. Then add each matching `agents[].configDir` in `~/.legion/configuration/ps-ai-personalisation.json`; a recorded folder equal to the default folder is not run twice. Blank or missing `configDir` values are ignored; a leading `~/` or `~\` expands against the owner home and recorded paths become full paths. Repeated recorded paths run once (case insensitive on Windows, case sensitive elsewhere).
- `-ConfigDir` replaces that folder list with only the supplied folder for each selected CLI. `-Tools` and `-ConfigDir` can be combined.
- Plain install skips completed steps. Update refreshes installed copies, including disabled ones; if ps-ai is missing in a folder, update asks `ps-ai is not installed for <tool> in <folder>. Install it now? [y/N]` before a fresh install. `-Yes` skips that question; `-DryRun` only previews. After a yes it uses the same marketplace registration and plugin installation steps as plain install; a no prints a `skip:` line for that folder. Missing recorded folders can be created by installation. `-DryRun` reads listings and previews mutations.

Uninstall keeps its existing selection: selected installed CLIs' defaults and recorded account folders, or only `-ConfigDir` when supplied, plus matching ps-ai generated files. It skips absent plugins and marketplace registrations and preserves account settings and logins.

Run `legion update` to update all selected targets, or the command below when `legion` is not available. Run `legion` in the repository afterward to load the new skills.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Update
```

### Installer parameters

For options, use the script-block form in PowerShell. This example selects an extra account:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Tools <tool-id> -ConfigDir <account folder>
```

Use `-Tools <tool-id>` (or an array of ids) to choose tools, `-Source <owner/repository>` to override the GitHub marketplace source, and `-DryRun` to print the steps without changing anything. `-HomeRoot <folder>` uses that folder as the home for `~/.legion` and the files the installer writes, for a test or an alternate home. The default is your real home. The default source is `BlackGad/ps-ai-marketplace`. `-Ref release|main` picks the track (default `release`, the `stable` branch); to switch between release and main, uninstall, then install. A working-tree script uses its sibling `tools.json` unless `-Source` is supplied. Remote dry runs read that metadata once. It does not change the marketplace source passed to the CLI. Install and update dry runs execute read-only listings to detect existing registrations and plugins; displayed add and update commands are previews.

To adopt a signed-in account folder, run `legion add codex <existing folder>`. The folder must exist; setup keeps its settings and login, records it and creates a shortcut. Setup installs a missing CLI, and ps-ai only where a folder has none, under the same approval; moving an installed ps-ai to a new version is the update flow's job. Adopting the same folder again reuses its account. Only the owner logs in if the CLI asks. An existing shortcut can instead be recorded through the tool's account guide.

### Version checks and catalog revisions

Overseer sessions check for a newer ps-ai version once a day and show a notice when one is available. Say "check ps-ai updates" for a fresh check, or "update ps-ai" to see the update command and approve running it. Checks never install updates. Release tags exist from `v0.6.0` onward. Update checks read the `plugin.json` on the `stable` branch, which moves only when a release is published, so a notice always means a published release. The notice names `legion update`. The shared checker is `pwsh -NoProfile -File <plugin>/bin/legion-update.ps1 -Check [-Force]`; `-Force` refreshes `~/.legion/temp/ps-ai-update.json` and reports check failures.

To follow `main` instead of releases, add `-Ref main` to the install line. To switch between release and main later, uninstall, then install:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Ref main
```

### Prerequisites and CLI guides

For optional prerequisite hints, use `pwsh -NoProfile -File <plugin>/bin/legion-install-tool.ps1 -Tool <helper-id>`, replacing `<plugin>` with the installed ps-ai plugin directory. When working from a clone, that directory is `./plugins/ps-ai`. Add `-Yes` only after choosing to install. See [repository helper sources and approval policy](../plugins/ps-ai/skills/legion-repository/references/tools.md).

Use the dedicated tool guides for CLI installation, account setup, plugin commands, and provider limitations:

- Claude Code: [installation](../plugins/ps-ai/skills/legion-claude/references/install.md), [accounts](../plugins/ps-ai/skills/legion-claude/references/accounts.md), [plugins and hooks](../plugins/ps-ai/skills/legion-claude/references/plugins.md).
- Codex CLI: [installation](../plugins/ps-ai/skills/legion-codex/references/install.md), [accounts](../plugins/ps-ai/skills/legion-codex/references/accounts.md), [plugins and hook trust](../plugins/ps-ai/skills/legion-codex/references/plugins.md).
- Copilot CLI: [installation and plugin commands](../plugins/ps-ai/skills/legion-copilot/references/install.md), [accounts](../plugins/ps-ai/skills/legion-copilot/references/accounts.md).

### Manual CLI installation

Run these in the selected account's environment. Setup normally installs ps-ai before login. The linked tool guides cover account selection and hook approval.

Claude Code:

```text
claude plugin marketplace add BlackGad/ps-ai-marketplace#stable
claude plugin install ps-ai@ps-ai-marketplace
```

Codex CLI:

```text
codex plugin marketplace add BlackGad/ps-ai-marketplace --ref stable
codex plugin add ps-ai@ps-ai-marketplace
```

Copilot CLI:

```text
copilot plugin marketplace add BlackGad/ps-ai-marketplace#stable
copilot plugin install ps-ai@ps-ai-marketplace
```

Codex hooks need one-time trust through `/hooks` in the selected account. Reinstalling preserves trust. Codex updates refresh all Git marketplaces in that account, including unrelated ones.

## Uninstall

Uninstall then install is an upgrade: your settings, notes, account folders and account launchers stay in place.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Uninstall
```

Shows the targets and generated files before asking. Use `-Yes` to skip the prompt, `-DryRun` to preview, or `-Tools` and `-ConfigDir` to narrow targets. Removes ps-ai and its marketplace registration, plus its copied runtime when no unselected account launcher needs it. Keeps account launchers in `~/.legion/bin`; subscription launchers only select the config folder and call the CLI. The four owner commands in `~/.legion/bin` (`ps-ai-setup`, `ps-ai-status`, `ps-ai-overseer` and `legion`, with Windows `.cmd` files) keep working: if their ps-ai copy is gone and another install is left, they point to that install; if none is left, ps-ai removes them. Unrelated files stay. Keeps `~/.legion/configuration` (settings and notes), `~/.legion/agents` (account folders and logins), repositories, and the CLIs themselves. Reinstall recreates missing subscription account launchers from settings using the stock CLI on PATH, skipping accounts whose CLI is unavailable. Removing a single account still deletes its launchers.

For a full removal, run `legion uninstall --purge` or:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Uninstall -Purge
```

Purge runs uninstall first, then lists everything it will delete and asks a separate question. It removes all of `~/.legion`, including settings, notes, account folders, legion-made logins and launchers. It removes ps-ai's plugin files, marketplace registration, caches, data and settings entries from every recorded tool folder and every default tool folder, even when a CLI is missing. On Windows it also removes the legion bin and portable PowerShell entries from user and current process PATH. Repositories, the CLIs and other tool settings stay. Purge covers all accounts even if `-Tools` or `-ConfigDir` narrowed the preceding uninstall. `-Yes` answers both questions; `-DryRun` lists the plan and removes nothing. Settings that cannot be safely edited are left unchanged and printed as manual steps.

Codex hook approvals for folders ps-ai no longer knows cannot be identified and are left in place.

## First run

After installing ps-ai, ask any tool to add accounts, or run setup from a clone or installed plugin folder:

```powershell
pwsh -NoProfile -File <plugin>/bin/legion-setup.ps1 -Add claude
```

This prints a plan and changes nothing. Example Windows output, with the temporary home abbreviated as `~` and path separators shown as `/`:

```text
Plan (nothing changed yet):
  create   settings and notes in ~/.legion/configuration
  add      claude1 (claude) new folder ~/.legion/agents/claude1
  install  ps-ai into ~/.legion/agents/claude1
  commands write legion in ~/.legion/bin
  path     add ~/.legion/bin to your user PATH
Run again with -Yes to apply.
```

After approving the plan, run it again with `-Yes`. Setup installs a missing CLI first, then adds the account and installs ps-ai before login. If CLI installation fails or needs a new terminal, that account is not recorded; retry the add after resolving the reported next step. Setup writes:

- `~/.legion/configuration/ps-ai-personalisation.json`: account folders and any later verified channel bindings. Validated against `plugins/ps-ai/schemas/personalisation.schema.json`. It never holds tokens.
- `~/.legion/configuration/ps-ai-notes.md`: free-form preferences and lessons.

It also writes account wrappers and the four commands below. On Windows it adds `~/.legion/bin` to your user PATH; on macOS and Linux it prints the line to add to your shell profile. It never edits that profile. Open a new terminal if needed.

Run `legion status` before making changes. Before setup, outside an orchestrated repository, status prints:

```text
no ps-ai settings yet
path ~/.legion/bin on PATH: no
commands: missing legion
repo none
```

`legion setup` finishes setup for recorded accounts and deletes the old `ps-ai-setup`, `ps-ai-status` and `ps-ai-overseer` commands when ps-ai made them (an edited one stays and is named as a manual step). A completed plan prints `Nothing to do.` The plan shows prerequisite repairs, such as a Node.js that is on PATH but does not run, on its `cli` line, so apply does nothing the plan did not show. With `-HomeRoot <home>`, the commands setup writes carry that home, so `legion` reads that home and not the real one. A default-home install is unchanged. Adding the same tool again without an explicit id creates another account; adopting the same folder again reuses its account. When the plan needs the remote installer, it names the download.

### Legion commands

`legion help` lists these verbs:

| Command | What it does |
| --- | --- |
| `legion setup [--yes]` | Finish setup: settings, commands, ps-ai in every account |
| `legion add <tool> [<folder>] [--yes]` | Add a claude, codex or copilot account, using a new or existing folder |
| `legion remove <id>` | Remove an account; keep its folder |
| `legion status` | Show accounts, commands, channels and this repository |
| `legion [--no-channel]` | Start the overseer here, set up if needed; resumes the last conversation (see [launcher defaults](../plugins/ps-ai/skills/legion-personalisation/references/launcher.md)) |
| `legion pick [--no-channel]` | Choose which account leads the overseer |
| `legion update [--yes]` | Update ps-ai along the track it was installed from |
| `legion uninstall [--purge] [--yes]` | Remove ps-ai; purge also removes settings, notes and legion-made logins |
| `legion help` | Show this list |

`setup` and `add` show the plan, then ask `Apply? [Y/n]` in an interactive terminal (Enter accepts). `--yes` applies without asking; redirected input only prints the plan. For example, `legion add claude`, `legion remove claude1` and `legion pick`.

Open `my-project` and describe the work. A bare `legion` creates Private orchestration by default; ask the tool for [Private or Shared](../plugins/ps-ai/skills/legion-repository/SKILL.md#choose-where-notes-live) storage and a repository check command when needed. State preferences later; they are saved in notes. Channels are set up only on request, such as “use Telegram”.

The console and each connected channel are equal. Owner questions go to all of them; an answer in any one resolves the question, with confirmation in the others. A request arriving through a channel is acknowledged there at once, followed by the real answer. Progress and completion notices go to all connected channels and the console.

Legion and review runs pass no model flag by default. Each CLI uses that account's own default model. A model flag is passed only when owner notes name one, such as “use astra for reviews”. Routing chooses agents without model discovery or model lists. Without owner preferences, the overseer follows [task routing](../plugins/ps-ai/skills/legion-overseer/references/task-loop.md) and chooses a different tool/provider for independent reviews. It says which agent was chosen. Owner preferences always win.

To open an overseer session, run `legion`. See the [launcher guide](../plugins/ps-ai/skills/legion-personalisation/references/launcher.md) for saved launches, account selection and channel defaults. Choose an account with `legion pick`; use `legion --no-channel` to skip the default channel.

Foundry agents use one Azure endpoint per agent, such as `https://<resource>.cognitiveservices.azure.com`, and the owner's `az` login. Setup can adopt an existing folder without changing its provider settings. For an explicit provider configuration request, use the matching account guide with values already supplied by the owner. Model preferences for work remain in notes.

Manage accounts through the account's tool skill. See the shared [terms](../plugins/ps-ai/skills/legion-overseer/references/terms.md) for account actions and model preferences.

## Modes

The `ps-ai` plugin lets Claude Code, Codex CLI and GitHub Copilot CLI share one way of running multi-agent work in a repository. One session acts as the **overseer**: it plans, hands tasks to working agents on your other accounts, reviews their results and keeps a tracked handoff, so any of the three tools can pick the work up later. Working agents (the **legion**) do one task each and report back.

A hook at session start decides the mode:

| Mode | When | What happens |
| --- | --- | --- |
| Member | The overseer started this process with `LEGION_ROLE=member` and `LEGION_TASK` | One task, local commits, a report; no other agents |
| Overseer | You say continue, progress or next in a repo with `.legion/state/` | Takes the lease, reads the handoff, continues the work |
| Setup | You ask to set up orchestration | Creates the repo layout |
| Ad hoc | Anything else | Nothing changes; an orchestrated repo shows one hint line |

A session you start yourself is never a legion member.

## Security: legion runs without a sandbox

Legion workers run with your full user rights so they can edit, run checks, and commit using your installed SDKs, user PATH, and tools. Sandboxes can hide installed tools; agents then download their own SDKs and drift from your machine's setup. Before the first legion dispatch, the overseer explains this and asks once. It records approval or refusal in notes and follows that answer without asking again.

The overseer starts legion only inside an assigned repository worktree and only for planned tasks. Workers must stay inside that repository or worktree, never push or touch other folders, and never download or install an SDK, runtime, package manager, or tool. If a needed tool is missing or the wrong version, they stop and report it so the overseer can ask you. These safeguards are instructions, not an enforced access boundary. Reviewer runs keep their read-only restrictions.

To opt out, leave legion unused. To limit its use, route legion only to accounts you trust.

## Files and folders

| What | Where | Git history |
| --- | --- | --- |
| Personalisation and notes | `~/.legion/configuration/` | no |
| Account wrappers and `legion` | `~/.legion/bin/` | no |
| New account config folders (adopted folders keep their names) | `~/.legion/agents/<id>/` | no |
| Portable prerequisite tools | `~/.legion/tools/<tool>/` | no |
| Cross-project knowledge wiki (optional, llm-wiki) | `~/.legion/knowledge/` | no |
| Repo workflow configuration | `<repo>/.legion/configuration/` (`project.json`, `workflow.md`) | inner for Private; code repo for Shared |
| Repo scripts and their index | `<repo>/.legion/scripts/`, `index.md` | inner for Private; code repo for Shared |
| Overseer state | `<repo>/.legion/state/handoff.md`, `history/` | inner for Private; code repo for Shared |
| Local specs and plans | `<repo>/.legion/docs/specs/`, `plans/` | no |
| Agent scratch files | `<repo>/.legion/temp/` | no |

The [repository layout](../plugins/ps-ai/skills/legion-repository/references/layout.md) defines ignores and Git ownership. Private is identified by a `.legion/.git` folder. Its outer ignore is local to Git and shared across worktrees. Shared uses the code repo's `.gitignore` and rules file. a bare `legion` creates the setup files; for explicit choices use `pwsh -NoProfile -File <plugin>/bin/legion-repository.ps1 -Repo <repo> [-Mode Private|Shared] [-Gate '<check command>']`. Handoff, history, and roadmap commits use the Git repository that owns `.legion/state`.

## Skills

| Skill | Job |
| --- | --- |
| `legion-personalisation` | Your accounts, routing, channels and projects |
| `legion-repository` | Repo layout, scripts index, rules-file block |
| `legion-overseer` | Takeover, milestone flow, task loop, reviews, handoff |
| `legion-member` | The working agent's contract and report |
| `legion-knowledge` | Consult and grow the cross-project wiki |
| `legion-update` | Check versions and update ps-ai after approval |
| `legion-claude`, `legion-codex`, `legion-copilot` | Run each CLI, check its limits, add or rename accounts |

## Works with method skills

ps-ai decides who does the work, where, and where the record lives. How one piece of work is done (brainstorming, planning, test-driven development, debugging, code review) comes from the method skills you have installed, such as superpowers. The repo rules block that `legion-repository` adds sends tasks to your legion accounts and plans to the repo's configured paths.

## Releases

If you push a commit to the release pull request by hand, run the `release` workflow once through `workflow_dispatch` to post the `gate` and `integration` statuses on the new head.

## Development

CLIs cache plugin copies by version. For changes shipped to agents, bump the version together in `plugins/ps-ai/plugin.json`, `plugins/ps-ai/.claude-plugin/plugin.json` and `plugins/ps-ai/.codex-plugin/plugin.json`. Restart Claude Code and Copilot CLI sessions after updating; resume the Codex session to load its refreshed copy.

Repository rules are in [AGENTS.md](../AGENTS.md). Specs, plans and verification notes stay local in the ignored `docs/specs/`, `docs/plans/`, `docs/superpowers/` and `docs/verification/` folders. Scratch files, logs, reports and worktrees belong in `.agents/temp/`. Keep `docs/reference.md` tracked.

Run the test suite from the repository root. Tests use fakes and must not call real coding CLIs, Azure CLI, winget or the network. The last line must be `<n> passed, 0 failed`.


```powershell
pwsh -NoProfile -File tests/run.ps1
```

License: [MIT](../LICENSE).
