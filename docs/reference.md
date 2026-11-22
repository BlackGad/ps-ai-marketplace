# Technical reference

Installer options, CLI guides and repository details for maintainers and power users.

## Requirements

- PowerShell 7 (`pwsh`) on every machine. The platform launchers offer to install it when missing.
- On macOS and Linux: `sh`, `curl`, `awk`, `tar`, and either `sha256sum` or `shasum`. The portable PowerShell archive needs the platform's PowerShell runtime dependencies.
- At least one of: Claude Code, Codex CLI, Copilot CLI.

## Install

On Windows, start the bootstrap below in Windows PowerShell 5.1 or PowerShell 7 (`pwsh`). The installer and plugin run in PowerShell 7; 5.1 is used only by the bootstrap to get PowerShell 7 and start the installer:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1)))
```

The bootstrap downloads and expands the plugin archive from the fixed legion repository, then reads its PowerShell recipe. If PowerShell 7 is missing on Windows, it shows `winget install --id Microsoft.PowerShell -e` and asks before installing. If winget is missing or fails, it uses the official per-user ZIP, verifies its SHA-256 digest, extracts it to `~/.legion/tools/pwsh/`, and adds that folder to the process and user PATH after consent. The installer then runs under PowerShell 7 and asks `Install legion for <tools> now? [y/N]`, including a PATH hint when needed. The first install can therefore ask twice. A declined question prints `Nothing changed` and stops successfully. Use `-Yes` to skip questions. Without PowerShell 7, `-DryRun` shows only the PowerShell hint. `-Update` and `-Uninstall` skip the legion install question; update asks its own question for a folder where legion is missing (see Install and update targets). The temporary archive is removed after the run. `-Source` selects marketplace and catalog data; executable installer code always comes from the fixed legion repository or the local checkout.

macOS:

```sh
curl -fsSL https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.sh | sh
```

Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.sh | sh
```

The POSIX launcher reuses PowerShell 7 on PATH or in `~/.legion/tools/pwsh`. If missing, it shows a hint and asks in the terminal before installing; without a terminal it changes nothing unless `--yes` (or `-y`) was supplied. `--dry-run` never installs PowerShell. After consent, it reads the selected track's catalog bootstrap recipe, downloads the latest official PowerShell release archive for macOS or Linux (x64 or arm64), verifies SHA-256 against the release asset's digest, and extracts to `~/.legion/tools/pwsh`, without sudo. It adds that folder to the current process PATH and runs the root PowerShell stub, which owns the plugin archive flow described above. A local checkout uses its own catalog and stub. Temporary downloads are removed after success or failure. A repeated run skips PowerShell installation. If the portable runtime cannot start, resolve the platform runtime dependencies and rerun.

By default, the script installs legion for every installed coding CLI, using the targets below. If none is installed, it prints the official CLI install commands and stops successfully. Install one and rerun the script. Repeated runs skip completed steps and preserve hook approval.

### Install and update targets

Plain install and `-Update` select the same targets:

- Without `-Tools`, select the CLIs found on PATH from `tools.json`. `-Tools` selects the named descriptors instead; update skips a selected CLI if its executable is missing.
- For each selected CLI, the default folder is the one named by the CLI's account environment variable when it is set (for example `CLAUDE_CONFIG_DIR`). When it is not set, the CLI's own default runs with that variable cleared. Then add each matching `agents[].configDir` in `~/.legion/configuration/personalisation.json`; a recorded folder equal to the default folder is not run twice. Blank or missing `configDir` values are ignored; a leading `~/` or `~\` expands against the owner home and recorded paths become full paths. Repeated recorded paths run once (case insensitive on Windows, case sensitive elsewhere).
- `-ConfigDir` replaces that folder list with only the supplied folder for each selected CLI. `-Tools` and `-ConfigDir` can be combined.
- Plain install skips completed steps. Update refreshes installed copies, including disabled ones; if legion is missing in a folder, update asks `legion is not installed for <tool> in <folder>. Install it now? [y/N]` before a fresh install. `-Yes` skips that question; `-DryRun` only previews. After a yes it uses the same marketplace registration and plugin installation steps as plain install; a no prints a `skip:` line for that folder. Missing recorded folders can be created by installation. `-DryRun` reads listings and previews mutations.

Uninstall keeps its existing selection: selected installed CLIs' defaults and recorded account folders, or only `-ConfigDir` when supplied, plus matching legion generated files. It skips absent plugins and marketplace registrations and preserves account settings and logins.

Run `legion update` to update all selected targets, or the command below when `legion` is not available. Run `legion` in the repository afterward to load the new skills.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Update
```

### Installer parameters

For macOS and Linux shell options, put arguments after `sh -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.sh | sh -s -- --tools codex,claude --config-dir "$HOME/account folder" --yes
```

| Shell option | PowerShell parameter |
| --- | --- |
| `--main` | `-Ref main` (default: release / stable) |
| `--update` | `-Update` |
| `--uninstall` | `-Uninstall` |
| `--purge` | `-Purge` |
| `--dry-run` | `-DryRun` |
| `--yes`, `-y` | `-Yes` |
| `--tools codex,claude` | `-Tools` with an array of comma-separated ids |
| `--config-dir <folder>` | `-ConfigDir <folder>` |

For options, use the script-block form in PowerShell. This example selects an extra account:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Tools <tool-id> -ConfigDir <account folder>
```

Use `-Tools <tool-id>` (or an array of ids) to choose tools, `-Source <owner/repository>` to override the GitHub marketplace source, and `-DryRun` to print the steps without changing anything. `-HomeRoot <folder>` uses that folder as the home for `~/.legion` and the files the installer writes, for a test or an alternate home. The default is your real home. The default source is `BlackGad/ps-legion-marketplace`. `-Ref release|main` picks the track (default `release`, the `stable` branch); to switch between release and main, uninstall, then install. A working-tree script uses its sibling `tools.json` unless `-Source` is supplied. Remote dry runs read that metadata once. It does not change the marketplace source passed to the CLI. Install and update dry runs execute read-only listings to detect existing registrations and plugins; displayed add and update commands are previews.

To adopt a signed-in account folder, run `legion add codex <existing folder>`. The folder must exist; setup keeps its settings and login, records it and creates a shortcut. Setup installs a missing CLI, and legion only where a folder has none, under the same approval; moving an installed legion to a new version is the update flow's job. Adopting the same folder again reuses its account. Only the owner logs in if the CLI asks. An existing shortcut can instead be recorded through the tool's account guide.

### Version checks and catalog revisions

Overseer sessions check for a newer legion version once a day and show a notice when one is available. Say "check legion updates" for a fresh check, or "update legion" to see the update command and approve running it. Checks never install updates. Release tags exist from `v0.6.0` onward. Update checks read the `plugin.json` on the `stable` branch, which moves only when a release is published, so a notice always means a published release. The notice names `legion update`. The shared checker is `pwsh -NoProfile -File <plugin>/bin/legion-update.ps1 -Check [-Force]`; `-Force` refreshes `~/.legion/temp/update.json` and reports check failures.

To follow `main` instead of releases, add `-Ref main` to the install line. To switch between release and main later, uninstall, then install:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Ref main
```

### Prerequisites and CLI guides

For optional prerequisite hints, use `pwsh -NoProfile -File <plugin>/bin/legion-install-tool.ps1 -Tool <helper-id>`, replacing `<plugin>` with the installed legion plugin directory. When working from a clone, that directory is `./plugins/legion`. Add `-Yes` only after choosing to install. See [repository helper sources and approval policy](../plugins/legion/skills/legion-repository/references/tools.md).

Use the dedicated tool guides for CLI installation, account setup, plugin commands, and provider limitations:

- Claude Code: [installation](../plugins/legion/skills/legion-claude/references/install.md), [accounts](../plugins/legion/skills/legion-claude/references/accounts.md), [plugins and hooks](../plugins/legion/skills/legion-claude/references/plugins.md).
- Codex CLI: [installation](../plugins/legion/skills/legion-codex/references/install.md), [accounts](../plugins/legion/skills/legion-codex/references/accounts.md), [plugins and hook trust](../plugins/legion/skills/legion-codex/references/plugins.md).
- Copilot CLI: [installation and plugin commands](../plugins/legion/skills/legion-copilot/references/install.md), [accounts](../plugins/legion/skills/legion-copilot/references/accounts.md).

### Manual CLI installation

Run these in the selected account's environment. Setup normally installs legion before login. The linked tool guides cover account selection and hook approval.

Claude Code:

```text
claude plugin marketplace add BlackGad/ps-legion-marketplace#stable
claude plugin install legion@ps-legion-marketplace
```

Codex CLI:

```text
codex plugin marketplace add BlackGad/ps-legion-marketplace --ref stable
codex plugin add legion@ps-legion-marketplace
```

Copilot CLI:

```text
copilot plugin marketplace add BlackGad/ps-legion-marketplace#stable
copilot plugin install legion@ps-legion-marketplace
```

Codex hooks need one-time trust through `/hooks` in the selected account. Reinstalling preserves trust. Codex updates refresh all Git marketplaces in that account, including unrelated ones.

## Uninstall

Uninstall then install is an upgrade: your settings, notes, account folders and account launchers stay in place.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Uninstall
```

Shows the targets and generated files before asking. Use `-Yes` to skip the prompt, `-DryRun` to preview, or `-Tools` and `-ConfigDir` to narrow targets. Removes legion and its marketplace registration, and undoes the permission rule recorded for that target. The footprint index records which install targets share the `legion` command in `~/.legion/bin` (plus `legion.cmd` on Windows). Uninstall refreshes it from a remaining target, or removes it after the last target leaves. A linked path or command without the "Generated by legion" header is left alone. Unrelated files stay. Keeps account launchers, settings, notes, account folders, logins, repositories and the CLIs themselves. Reinstall recreates missing subscription account launchers from settings using the stock CLI on PATH, skipping accounts whose CLI is unavailable. Removing an account deletes its launchers; removing the last Foundry account also deletes its shared runtime copy.

For a full removal, run `legion uninstall --purge` or:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Uninstall -Purge
```

Purge runs uninstall first, then lists everything it will delete and asks a separate question. It removes all of `~/.legion`, including settings, notes, account folders, legion-made logins and launchers. It removes legion's plugin files, marketplace registration, caches, data and settings entries from every recorded tool folder and every default tool folder, even when a CLI is missing. On Windows it removes the exact recorded legion PATH entries, including portable tools, from the user and current process PATH. On macOS and Linux it removes the recorded shell profile PATH line and the `# Added by legion` line directly above it, preserving every other byte; a line without that marker is the owner's and stays. It also removes the recorded `~/.legion/bin/pwsh` link and recorded permission rules, preserving comments and other rules. Repositories, the CLIs and other tool settings stay. Purge covers all accounts even if `-Tools` or `-ConfigDir` narrowed the preceding uninstall. `-Yes` answers both questions; `-DryRun` lists the plan and removes nothing. Settings that cannot be safely edited are left unchanged and printed as manual steps.

Codex hook approvals for folders legion no longer knows cannot be identified and are left in place.

## First run

Versions before legion must be uninstalled and set up again; compatibility with those versions is not provided before 1.0.

Owner files use `~/.legion/configuration/personalisation.json` and `configuration/notes.md`; the update cache is `temp/update.json`, installer scratch uses `temp/install-<guid>`, and Foundry launchers use `bin/.runtime/`.

The footprint index is `~/.legion/footprints.json`. Without an index, uninstall leaves generated files alone; purge still removes the legion folder, but can undo only recorded PATH entries and permission rules. For the one-time reinstall after this change, delete the old `legion` and `legion.cmd` command files, rerun the installer for each target, then run `legion setup --yes`. Setup and refresh rewrite command files with a "Generated by legion" header in full, replacing hand-added text. A headerless file is kept.

After installing legion, ask any tool to add accounts, or run setup from a clone or installed plugin folder:

```powershell
pwsh -NoProfile -File <plugin>/bin/legion-setup.ps1 -Add claude
```

This prints a plan and changes nothing. Example Windows output, with the temporary home abbreviated as `~` and path separators shown as `/`:

```text
Plan (nothing changed yet):
  create   settings and notes in ~/.legion/configuration
  add      claude1 (claude) new folder ~/.legion/agents/claude1
  install  legion into ~/.legion/agents/claude1
  commands write legion in ~/.legion/bin
  path     add ~/.legion/bin to your user PATH
Run again with -Yes to apply.
```

After approving the plan, run it again with `-Yes`. Setup installs a missing CLI first, then adds the account and installs legion before login. If CLI installation fails or needs a new terminal, that account is not recorded; retry the add after resolving the reported next step. Setup writes:

- `~/.legion/configuration/personalisation.json`: account folders and any later verified channel bindings. Validated against `plugins/legion/schemas/personalisation.schema.json`. It never holds tokens.
- `~/.legion/configuration/notes.md`: free-form preferences and lessons.

For every Claude account, setup also adds the permission rule `Bash(LEGION_ROLE=member *)` to its `settings.json`, so the overseer can start legion members without a prompt; other settings and rules stay. It also writes account wrappers and the four commands below. After the same yes, setup and the installer add `~/.legion/bin` to your user PATH on Windows. On macOS and Linux they append `# Added by legion` and `export PATH="$HOME/.legion/bin:$PATH"` once to the shell profile selected by `$SHELL`: `~/.zshrc` for zsh, `~/.bashrc` for bash, otherwise `~/.profile`. The plan shows the profile change before consent; a repeat skips it. Legion records only what it adds: a PATH entry, profile line or permission rule you already had stays yours. When the installer runs from the portable PowerShell in `~/.legion/tools/pwsh` on macOS or Linux, it also links `~/.legion/bin/pwsh` to it, so new terminals, the `legion` command, Foundry launchers and session hooks find PowerShell. Purge removes the recorded line and its marker, preserving the rest of the file. Open a new terminal if needed.

Run `legion status` before making changes. Before setup, outside an orchestrated repository, status prints:

```text
no legion settings yet
path ~/.legion/bin on PATH: no
commands: missing legion
repo none
```

`legion setup` finishes setup for recorded accounts. A completed plan prints `Nothing to do.` The plan shows prerequisite repairs, such as a Node.js that is on PATH but does not run, on its `cli` line, so apply does nothing the plan did not show. With `-HomeRoot <home>`, the commands setup writes carry that home, so `legion` reads that home and not the real one. A default-home install is unchanged. Adding the same tool again without an explicit id creates another account; adopting the same folder again reuses its account. When the plan needs the remote installer, it names the download.

### Legion commands

`legion help` lists these verbs:

| Command | What it does |
| --- | --- |
| `legion setup [--yes]` | Finish setup: settings, commands, legion in every account |
| `legion add <tool> [<folder>] [--yes]` | Add a claude, codex or copilot account, using a new or existing folder |
| `legion remove <id>` | Remove an account; keep its folder |
| `legion status` | Show accounts, commands, channels and this repository |
| `legion [--no-channel]` | Start the overseer here, set up if needed; resumes the last conversation (see [launcher defaults](../plugins/legion/skills/legion-personalisation/references/launcher.md)) |
| `legion pick [--no-channel]` | Choose which account leads the overseer |
| `legion limits [<id>]` | Show each account's usage windows (used %, reset time, status), or one account's; `unknown` when the tool gives no readout |
| `legion update [--yes]` | Update legion along the track it was installed from |
| `legion uninstall [--purge] [--yes]` | Remove legion; purge also removes settings, notes and legion-made logins |
| `legion help` | Show this list |

`setup` and `add` show the plan, then ask `Apply? [Y/n]` in an interactive terminal (Enter accepts). `--yes` applies without asking; redirected input only prints the plan. For example, `legion add claude`, `legion remove claude1` and `legion pick`.

Open `my-project` and describe the work. A bare `legion` creates Private orchestration by default; ask the tool for [Private or Shared](../plugins/legion/skills/legion-repository/SKILL.md#choose-where-notes-live) storage and a repository check command when needed. State preferences later; they are saved in notes. Channels are set up only on request, such as “use Telegram”.

The console and each connected channel are equal. Owner questions go to all of them; an answer in any one resolves the question, with confirmation in the others. A request arriving through a channel is acknowledged there at once, followed by the real answer. Progress and completion notices go to all connected channels and the console.

Legion and review runs pass no model flag by default. Each CLI uses that account's own default model. A model flag is passed only when owner notes name one, such as “use astra for reviews”. Routing chooses agents without model discovery or model lists. Without owner preferences, the overseer follows [task routing](../plugins/legion/skills/legion-overseer/references/task-loop.md) and chooses a different tool/provider for independent reviews. It says which agent was chosen. Owner preferences always win.

To open an overseer session, run `legion`. See the [launcher guide](../plugins/legion/skills/legion-personalisation/references/launcher.md) for saved launches, account selection and channel defaults. Choose an account with `legion pick`; use `legion --no-channel` to skip the default channel.

Foundry agents use one Azure endpoint per agent, such as `https://<resource>.cognitiveservices.azure.com`, and the owner's `az` login. Setup can adopt an existing folder without changing its provider settings. For an explicit provider configuration request, use the matching account guide with values already supplied by the owner. Model preferences for work remain in notes.

Manage accounts through the account's tool skill. See the shared [terms](../plugins/legion/skills/legion-overseer/references/terms.md) for account actions and model preferences.

## Modes

The `legion` plugin lets Claude Code, Codex CLI and GitHub Copilot CLI share one way of running multi-agent work in a repository. One session acts as the **overseer**: it plans, hands tasks to working agents on your other accounts, reviews their results and keeps a tracked handoff, so any of the three tools can pick the work up later. Working agents (the **legion**) do one task each and report back.

A hook at session start decides the mode:

| Mode | When | What happens |
| --- | --- | --- |
| Member | The overseer started this process with `LEGION_ROLE=member` and `LEGION_TASK` | One task, local commits, a report; no other agents |
| Overseer | You say continue, progress or next in a repo with `.legion/state/` | Takes the lease, reads the handoff, continues the work |
| Setup | You ask to set up orchestration | Creates the repo layout |
| Ad hoc | Anything else | Nothing changes; an orchestrated repo shows one hint line |

A session you start yourself is never a legion member.

On Windows, the hook also warns when a bound channel's launch flag is absent from a recognized native CLI session; unknown accounts and unsupported or unreadable sessions stay silent.

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

The [repository layout](../plugins/legion/skills/legion-repository/references/layout.md) defines ignores and Git ownership. Private is identified by a `.legion/.git` folder. Its outer ignore is local to Git and shared across worktrees. Shared uses the code repo's `.gitignore` and rules file. a bare `legion` creates the setup files; for explicit choices use `pwsh -NoProfile -File <plugin>/bin/legion-repository.ps1 -Repo <repo> [-Mode Private|Shared] [-Gate '<check command>']`. Handoff, history, and roadmap commits use the Git repository that owns `.legion/state`.

## Skills

| Skill | Job |
| --- | --- |
| `legion-personalisation` | Your accounts, routing, channels and projects |
| `legion-repository` | Repo layout, scripts index, rules-file block |
| `legion-overseer` | Takeover, milestone flow, task loop, reviews, handoff |
| `legion-member` | The working agent's contract and report |
| `legion-knowledge` | Consult and grow the cross-project wiki |
| `legion-update` | Check versions and update legion after approval |
| `legion-claude`, `legion-codex`, `legion-copilot` | Run each CLI, check its limits, add or rename accounts |

## Works with method skills

legion decides who does the work, where, and where the record lives. How one piece of work is done (brainstorming, planning, test-driven development, debugging, code review) comes from the method skills you have installed, such as superpowers. The repo rules block that `legion-repository` adds sends tasks to your legion accounts and plans to the repo's configured paths.

## Releases

If you push a commit to the release pull request by hand, run the `release` workflow once through `workflow_dispatch` to post the `gate` and `integration` statuses on the new head.

## Development

CLIs cache plugin copies by version. For changes shipped to agents, bump the version together in `plugins/legion/plugin.json`, `plugins/legion/.claude-plugin/plugin.json` and `plugins/legion/.codex-plugin/plugin.json`. Restart Claude Code and Copilot CLI sessions after updating; resume the Codex session to load its refreshed copy.

Repository rules are in [AGENTS.md](../AGENTS.md). Specs, plans and verification notes stay local in the ignored `docs/specs/`, `docs/plans/`, `docs/superpowers/` and `docs/verification/` folders. Scratch files, logs, reports and worktrees belong in `.agents/temp/`. Keep `docs/reference.md` tracked.

Run the test suite from the repository root. Tests use fakes and must not call real coding CLIs, Azure CLI, winget or the network. The last line must be `<n> passed, 0 failed`.


```powershell
pwsh -NoProfile -File tests/run.ps1
```

License: [MIT](../LICENSE).
