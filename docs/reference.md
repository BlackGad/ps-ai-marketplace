# Technical reference

Installer options, CLI guides and repository details for maintainers and power users.

The Windows bootstrap takes PowerShell flags such as `-Tools`, `-Yes` and `-Update`; the POSIX bootstrap takes `--tools`, `--yes` and `--update`; both pass them on to the Python `legion install`, which spells the tool option `--tool` (repeat it or separate ids with commas). [Installer parameters](#installer-parameters) maps the spellings.

## Requirements

- [uv](https://docs.astral.sh/uv/) on every machine. The bootstrap installs it after asking when it is missing; legion itself runs in Python through uv, and uv downloads the Python it needs.
- On Windows: the built-in Windows PowerShell 5.1 (or PowerShell 7) to start the bootstrap.
- On macOS and Linux: `sh`, `curl` and `tar`.
- At least one of: Claude Code, Codex CLI, Copilot CLI.

## Install

The install one-liners are in the [README](../README.md#install). The bootstrap script comes from the `main` branch, but it downloads the legion code archive from the `stable` branch (the latest release) unless you ask for `main` (`-Ref main`, `--main`). The archive supplies the installer code that runs `legion install`. The version legion reports is read from the `plugin.json` of the plugin installed in each tool, not from the archive: if an older plugin is already installed and enabled, the installer can skip it, so a newer bootstrap run over it may still report the older version until you run an update. A local checkout uses its own files instead.

The bootstrap only obtains uv, then hands every option to the Python `legion install` command. On Windows it runs in Windows PowerShell 5.1 or PowerShell 7. If uv is missing, it says so and asks `Install uv now? [y/N]`; after a yes it reads the latest uv release from GitHub, downloads the archive for your system, checks it against the release's SHA-256 digest (a mismatch deletes the download and stops) and publishes `uv` to uv's default folder (`~/.local/bin`, or `UV_INSTALL_DIR` / `XDG_BIN_HOME`; extracted privately first, run once to check it works, then renamed into place). uv is a global helper like git: legion never removes it. POSIX needs no sudo. Every download must be HTTPS, redirects included. If Python 3.12 is missing, `-DryRun` (`--dry-run`) only says so; an ordinary run asks before uv downloads it.

Then the bootstrap downloads the plugin archive from the fixed legion repository, or uses the local checkout, and runs `legion --home <home> install` through `uv run` with the same options in a throwaway environment in the system temp folder, removed afterwards. `legion install` asks `Install legion for <tools> now, and put the legion command on your PATH with uv? [y/N]`, so the first install can ask twice. It installs the legion command with `uv tool install "<plugin folder>[mcp]" --constraints <exported uv.lock> --reinstall` from the plugin copy each CLI has just installed, then, inside the same yes, runs `uv tool update-shell`, which puts uv's tool folder on your PATH by editing your shell profile or, on Windows, your user PATH (the dry run lists it); update never runs it. A repeat of the same version prints `skip: legion command <version> (already done)` and offers the PATH repair if needed. A declined question prints `Nothing changed` and stops successfully. `-Yes` skips questions. `-Update` and `-Uninstall` skip the install question. `-Source` selects marketplace and catalog data; executable code always comes from the fixed legion repository or the local checkout. The POSIX bootstrap reuses uv on PATH or in `~/.local/bin`; without a terminal it changes nothing unless `--yes` (or `-y`) was supplied.

By default, the script installs legion for every installed coding CLI, using the targets below. If none is installed, it says so and prints each CLI's install hint; add an account with `legion add <tool>`, which installs the CLI. Repeated runs skip completed steps and preserve hook approval.

### Install and update targets

Plain install and `-Update` select the same targets:

- Without `-Tools`, select the CLIs found on PATH from `tools.json`. `-Tools` selects the named descriptors (an array or comma-separated ids) instead; update skips a selected CLI if its executable is missing.
- For each selected CLI, the default folder is the one named by the CLI's account environment variable when it is set (for example `CLAUDE_CONFIG_DIR`). When it is not set, the CLI's own default runs with that variable cleared. Then add each matching `agents[].configDir` in `~/.legion/configuration/personalisation.json`; a recorded folder equal to the default folder is not run twice. Blank or missing `configDir` values are ignored; a leading `~/` or `~\` expands against the owner home and recorded paths become full paths. Repeated recorded paths run once (case insensitive on Windows, case sensitive elsewhere).
- `-ConfigDir` replaces that folder list with only the supplied folder for each selected CLI. `-Tools` and `-ConfigDir` can be combined.
- Plain install skips completed steps. Update refreshes installed copies, including disabled ones; a folder where legion is missing gets a fresh install, with the same marketplace registration and plugin installation steps as plain install. Missing recorded folders can be created by installation.
- Update lists every target and asks one question, `Update legion? [y/N]`, for all of them, so one folder cannot be declined alone. `-Yes` skips that question; `-DryRun` only previews, reading listings and showing the commands it would run.
- `legion update` has no `--tool` or `--config-dir` options and updates every listed target; use `-Update` with `-Tools` or `-ConfigDir` to update chosen targets. The one-liner for when `legion` is not available is in the [README](../README.md#update-and-uninstall). Run `legion` in the repository afterward to load the new skills.
- Uninstall selects the same targets (see [Uninstall](#uninstall)).

### Running sessions and the stop event

Each `legion mcp` server and `legion run` wrapper registers its process id in its legion home's `.legion/run/` folder. An update stops legion processes registered under its own legion home only. A full uninstall uses the same stop event immediately after approval, before removing plugins, changing PATH or purging the knowledge hub.

On Windows, an update with a registered ancestor refuses before changing any plugins or starting the stop event or uv. The ancestor keeps the tool files open. Close your Legion session, run `legion update` from a terminal, then reopen Legion. Update checks and dry runs are available from the session.

Registered processes check for the stop file about once a second. A `legion run` wrapper ends the account's whole process tree by process id. The calling process and its ancestors are exempt. On macOS and Linux, an update asks you to restart the calling session if an ancestor is registered. Legion waits up to 30 seconds for the other registered processes to exit, even after they remove their registration files. It also removes stale registrations. If any process remains, legion lifts the stop file and asks you to close those sessions and run the command again. The uv step is skipped. A full uninstall also skips plugin, PATH and hub changes in this case.

The detached Python helper waits up to 60 seconds for Legion to exit before running uv or purging folders. The command reports when it schedules the helper. The helper records uv's output, exit code and handover errors in `<home>/.legion/temp/uv-tool.log`. `legion status` flags failures recorded in the log. A wait timeout skips uv and folder deletion. The helper still removes the stop file and any temporary constraints. If the helper is interrupted, the stop file expires after ten minutes. On Windows, if uv reports locked files, close the sessions that have them open and retry from a separate terminal.

`legion run` repeats the session id Codex reports as `legion: session id <id>` on stderr. The overseer can resume a stopped Codex member when that id is in the handoff. It reruns Claude and Copilot members, and Codex members without a recorded id, from the handoff's task file. See the [task loop](../plugins/legion/skills/legion-overseer/references/task-loop.md#legion-run-and-updates). On every platform, `legion setup` and `legion install` defer the uv install until after exit when running from the installed uv tool.

### Installer parameters

For macOS and Linux shell options, put arguments after `sh -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.sh | sh -s -- --tools codex,claude --config-dir "$HOME/account folder" --yes
```

| Shell option | Windows parameter |
| --- | --- |
| `--main` | `-Ref main` (default: release / stable) |
| `--update` | `-Update` |
| `--uninstall` | `-Uninstall` |
| `--uninstall --purge` | `-Uninstall -Purge` |
| `--dry-run` | `-DryRun` |
| `--yes`, `-y` | `-Yes` |
| `--tools codex,claude` | `-Tools` with an array of comma-separated ids |
| `--config-dir <folder>` | `-ConfigDir <folder>` |

For options, use the script-block form in Windows PowerShell. This example selects an extra account:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Tools <tool-id> -ConfigDir <account folder>
```

`-Tools <tool-id>` (or an array of ids) chooses tools, `-Source <owner/repository>` overrides the GitHub marketplace source (default `BlackGad/ps-legion-marketplace`), and `-DryRun` prints the steps without changing anything. `-HomeRoot <folder>` uses that folder as the home for `~/.legion` and the files the installer writes, for a test or an alternate home; the default is your real home. `-Ref release|main` picks the track (default `release`, the `stable` branch). To follow `main`, add `-Ref main` to the install line; to switch between release and main later, uninstall, then install. The catalog comes from the bundled `tools.json` for the default source on the release track, and from the remote `tools.json` of the chosen source and branch otherwise (`-Ref main` included); a local checkout as source uses its own file. Remote dry runs read it once.

To adopt a signed-in account folder, run `legion add codex <existing folder>`. The folder must exist; setup keeps its settings and login and records it; the account then starts through `legion --account <id>` or `legion pick`. Adopting the same folder again reuses its account. Setup installs a missing CLI, and legion only where a folder has none, under the same approval; moving an installed legion to a new version is the update flow's job. Only the owner logs in if the CLI asks. An account's existing program can instead be registered through the tool's account guide.

### Version checks and catalog revisions

Overseer sessions check for a newer legion version once a day and show a notice when one is available. Say "check legion updates" for a fresh check, or "update legion" to start the update conversation. On Windows, the overseer asks you to run the update from a terminal after closing the session. On macOS and Linux, it can run the update after you approve. Checks never install updates. Update checks always read the `plugin.json` on the `stable` branch, which moves only when a release is published, so a notice always means a published release. That holds for an install that follows `main` too: the notice compares with the latest release, not with `main`; `legion update` itself follows the marketplace track the install registered. The notice names `legion update`. Run `legion update --check --force` for a fresh check; `--force` refreshes `~/.legion/temp/update.json` and reports check failures.

### Tools catalog

Three files describe the tools legion knows:

- `plugins/legion/tools.json` lists the supported coding CLIs (claude, codex, copilot): how to find each one, its account folder variable and its plugin and hook commands. It is generated from each tool skill's `tool.json`, never edited by hand.
- `plugins/legion/helpers.json` lists the helper programs `legion tool install --tool <id>` can install, such as git or node, with their checks and download steps.
- `tools/generate.py` rewrites `tools.json` and the editor schemas. Run it after changing a `tool.json`.

### Prerequisites and CLI guides

For optional prerequisite hints, use `legion tool install --tool <helper-id>`. Add `--yes` only after choosing to install. See [repository helper sources and approval policy](../plugins/legion/skills/legion-repository/references/tools.md).

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

Uninstall then install is an upgrade: your settings, notes and account folders stay in place. The one-liners are in the [README](../README.md#update-and-uninstall).

Uninstall shows the commands it will run and the folders it will delete, then asks. Use `-Yes` to skip the prompt, `-DryRun` to preview, or `-Tools` and `-ConfigDir` to narrow targets (the selected installed CLIs' defaults and recorded account folders, or only `-ConfigDir` when supplied). It runs each CLI's own plugin uninstall and marketplace remove commands, skips what is already gone, and edits none of the CLI's settings, caches or data. With every CLI selected (no `-ConfigDir`) it stops legion processes in its own legion home before removing plugins (see [the stop event](#running-sessions-and-the-stop-event)). After legion exits, the helper removes the legion command with `uv tool uninstall legion`. uv itself stays, and so does the PATH entry `uv tool update-shell` made: it is uv's, not legion's. A plain uninstall deletes no folder of `~/.legion`. Your settings, notes, account folders, logins, repositories and the CLIs themselves stay. Removing an account keeps its config folder.

Setup also puts the knowledge hub under git so a bad compile or a mistake can be undone: a new hub, or an existing hub that is not a repository, gets `git init`, a `.gitignore` with `.sessions/` and one first commit (a repeat prints `skip: knowledge hub git repository (already done)`; a hub that already is a repository is left alone). The commit uses your own git identity, or `legion` / `legion@localhost` for that repository only when none is set; the global config is never changed. Without git, setup prints one line and continues. `legion status` says when the hub is not a repository.

When knowledge is enabled, uninstall also removes the llm-wiki plugin and marketplace from the selected accounts and keeps the hub and its pointer.

If the bootstrap needs to download uv for uninstall, it keeps the verified executable in a separate system temp folder for the detached helper to use. The bootstrap removes its project environment and leaves the executable folder for system temp cleanup. The helper deletes approved purge folders when `uv tool uninstall legion` succeeds or when the tool is already absent. If uv fails to launch or exits with an error, the helper retains those folders and the log. It closes the log before deleting its folder and retries locked files during deletion on Windows. A directory link is removed without deleting its target.

For a full removal, run `legion uninstall --purge` or the bootstrap with `-Uninstall -Purge` (`--uninstall --purge`). Purge runs uninstall first, then deletes all of `~/.legion`: settings, notes, account folders, legion-made logins and the footprint index, and the user PATH entries recorded for the portable tools legion installed. If a knowledge hub exists in `~/.legion/knowledge`, purge asks about it in its own question, and `-Yes` does not answer it; without a yes the hub stays. Purge always covers every CLI: it is refused with `-ConfigDir` or a `-Tools` list that leaves out any catalog tool. `-Yes` answers the first question; `-DryRun` lists the plan and removes nothing. The CLIs' own files, repositories (including their `.legion` folders) and other tool settings stay.

## First run

Owner files are `~/.legion/configuration/personalisation.json` and `configuration/notes.md`; the update cache is `temp/update.json`, tool downloads use a throwaway `temp/install-*` folder, `run/` holds the running sessions' registrations and the stop file, and every account starts through `legion run`, which belongs to the uv tool.

The footprint index is `~/.legion/footprints.json`. It records what legion needs to find again: the user PATH entries of the portable tools it installed, and the folders of accounts.

After installing legion, ask any tool to add accounts, or run setup from a clone or installed plugin folder:

```text
legion add claude
```

This prints a plan and changes nothing. Example Windows output, with the temporary home abbreviated as `~` and path separators shown as `/`:

```text
Plan (nothing changed yet):
  create   settings and notes in ~/.legion/configuration
  add      claude1 (claude) new folder ~/.legion/agents/claude1
  install  legion into ~/.legion/agents/claude1
  command  install the legion command with uv, then run uv tool update-shell, which puts it on your PATH (your shell profile or user PATH)
Run again with --yes to apply.
```

After approving the plan (an interactive terminal asks `Apply? [Y/n]`), run it again with `--yes`. Setup installs a missing CLI first, then adds the account and installs legion before login. For a new account folder, the `log in:` column shows the command that starts the tool itself with the account's folder variable set (for example `$env:CLAUDE_CONFIG_DIR='<folder>'; claude` in PowerShell, `CLAUDE_CONFIG_DIR='<folder>' claude` on macOS and Linux); run it once outside legion and log in. `legion` and `legion pick` start only the overseer. If CLI installation fails or needs a new terminal, that account is not recorded; retry the add after resolving the reported next step. Setup writes:

- `~/.legion/configuration/personalisation.json`: account folders and any later verified channel bindings. Validated against `plugins/legion/schemas/personalisation.schema.json`. It never holds tokens.
- `~/.legion/configuration/notes.md`: free-form preferences and lessons.

For every Claude account, setup also adds the permission rule `Bash(LEGION_ROLE=member *)` to its `settings.json`, so the overseer can start legion members without a prompt; other settings and rules stay. It also installs the `legion` command as a uv tool (`uv tool install`, from the plugin copy, pinned to the plugin's `uv.lock`). Inside the same yes, setup and the installer run `uv tool update-shell`, which edits your shell profile or, on Windows, your user PATH so the tool folder is on PATH; the plan shows that line before consent and a dry run lists it. If the tool is already installed and its folder is missing from PATH, `legion status` reports it and setup offers to run just `uv tool update-shell` for the command. On Windows this checks the saved user and machine PATH. On macOS and Linux it checks the shell's current PATH. Without a yes nothing is installed or edited. Legion records only what it adds itself: a permission rule you already had stays yours. Open a new terminal if needed.

Run `legion status` before making changes. Before setup, outside an orchestrated repository, status prints:

```text
no legion settings yet
knowledge: off (not asked)
repo none
```

`legion setup` finishes setup for recorded accounts. A completed plan prints `Nothing to do.` The plan shows prerequisite repairs, such as a Node.js that is on PATH but does not run, on its `cli` line, so apply does nothing the plan did not show. With `legion --home <home> setup`, the commands setup writes carry that home, so `legion` reads that home and not the real one. Adding the same tool again without an explicit id creates another account. When the plan needs the remote installer, it names the download.

### Legion commands

These are the main commands; `legion help` lists all of them:

| Command | What it does |
| --- | --- |
| `legion setup [--yes]` | Finish setup: settings, commands, legion in every account |
| `legion setup --knowledge/--no-knowledge` | Turn llm-wiki on or decline it. Turning it off after an opt-in removes the wiki plugin and marketplace from every account and keeps the hub and its pointer. If knowledge was never enabled, a decline leaves manual installs in place. Add `--yes` to also apply the Legion setup plan. |
| `legion add <tool> [<folder>] [--yes]` | Add a claude, codex or copilot account, using a new or existing folder |
| `legion remove --id <id>` | Remove an account; keep its folder |
| `legion status` | Show accounts, channels, knowledge and this repository |
| `legion [--no-channel]` | Start the overseer here, set up if needed; resumes the last conversation (see [launcher defaults](../plugins/legion/skills/legion-personalisation/references/launcher.md)) |
| `legion pick [--no-channel]` | Choose which account leads the overseer |
| `legion limits [--id <id>]` | Show each account's usage windows (how much is left in %, reset time, status; JSON has `used` and `left`), or one account's; `unknown` when the tool gives no readout |
| `legion lease take\|status\|release` | Take, check or release this repository's overseer lease; the overseer skill runs it |
| `legion update [--yes]` | Update every listed target along the registered marketplace track (release or `main`). One question covers them all, and `--yes` skips it. On Windows, run from a terminal after closing the Legion session. Registered processes are stopped before the helper replaces the command with `uv tool install` |
| `legion update --check [--force]` | Check for a newer release; `--force` refreshes the cached result |
| `legion uninstall [--purge] [--yes]` | Remove legion (running sessions are stopped first); purge also removes settings, notes and legion-made logins |
| `legion help` | Show this list |

The owner command also accepts these account, channel and repository verbs:

| Command | What it does |
| --- | --- |
| `legion account add --id <id> --tool <tool> [--provider foundry --endpoint <url> --deployment <name> --default <name>]` | Add or repair a subscription or Foundry account; with `--command <path> --config-dir <dir>` it registers an existing account folder and its CLI program |
| `legion account rename --id <id> --new-id <new>` | Rename an account id; keep its folder |
| `legion account models --id <id> [--deployment <name> --default <name>] [--alias <a>=<b>] [--standard] [--list]` | Show or change a Foundry account's deployments |
| `legion channel add --id <id> --kind telegram --target <chat> --account <account>` | Bind a Telegram destination to an account |
| `legion channel check --kind telegram --account <account>` | Show channel prerequisites without launching a tool |
| `legion channel remove --id <id>` | Remove a channel binding |
| `legion repository setup --repo <path> [--mode shared] [--gate <command>] [--rules-file <file>]` | Set up repository orchestration |

`setup` and `add` show the plan, then ask `Apply? [Y/n]` in an interactive terminal (Enter accepts). `--yes` applies without asking; redirected input only prints the plan.

A bare `legion` creates Private orchestration by default; ask the tool for [Private or Shared](../plugins/legion/skills/legion-repository/SKILL.md#choose-where-notes-live) storage and a repository check command when needed. Each repository's overseer has its own Telegram bot folder, `~/.legion/channels/telegram/<channel id>`; the launcher points the session at it.

The console and each connected channel are equal; the rules are in the [personalisation skill](../plugins/legion/skills/legion-personalisation/SKILL.md#identity-and-hard-rules).

Runs pass no model flag by default; a flag is passed only when owner notes name a model or allow a tier ([model tiers](../plugins/legion/skills/legion-overseer/references/task-loop.md#model-tiers)). Without owner preferences the overseer follows [default routing](../plugins/legion/skills/legion-overseer/references/task-loop.md#default-routing).

The [launcher guide](../plugins/legion/skills/legion-personalisation/references/launcher.md) covers saved launches, account selection and channel defaults.

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

The hook is a small Python script in the plugin copy. `uv` starts it with Python 3.12 or later, offline and without downloads. When uv or Python is missing, the hook prints one line asking you to run the legion installer, and the session starts normally. Update notices use the local cache.

Legion passes the configured home when it starts an account for the overseer or a member run. The hook uses the login home by default. When starting a host directly for an alternate `legion --home` installation, set `LEGION_HOME` to the same absolute path.

The hook reports whether a repository lease file is present. `legion lease status`, `legion lease take`, and `legion status` check whether the process in the lease is still live.

On Windows, `legion status` also warns when a bound channel's launch flag is absent from a recognized native CLI session, including outside an orchestrated repo. Members, unknown or ambiguous accounts, and unsupported or unreadable sessions stay silent.

## Security: legion runs without a sandbox

Legion workers run with your full user rights so they can edit, run checks, and commit using your installed SDKs, user PATH, and tools. Sandboxes can hide installed tools; agents then download their own SDKs and drift from your machine's setup. Before the first legion dispatch, the overseer explains this and asks once. It records approval or refusal in notes and follows that answer without asking again.

The overseer starts legion only inside an assigned repository worktree and only for planned tasks. Workers must stay inside that repository or worktree, never push or touch other folders, and never download or install an SDK, runtime, package manager, or tool. If a needed tool is missing or the wrong version, they stop and report it so the overseer can ask you. These safeguards are instructions, not an enforced access boundary. Reviewer runs keep their read-only restrictions.

To opt out, leave legion unused. To limit its use, route legion only to accounts you trust.

## Files and folders

| What | Where | Git history |
| --- | --- | --- |
| Personalisation and notes | `~/.legion/configuration/` | no |
| The `legion` command (a uv tool; its folder is `uv tool dir`, the command in `uv tool dir --bin`) | uv's folders | no |
| Running legion sessions and the stop file | `~/.legion/run/` | no |
| New account config folders (adopted folders keep their names) | `~/.legion/agents/<id>/` | no |
| Portable prerequisite tools | `~/.legion/tools/<tool>/` | no |
| Cross-project knowledge wiki (optional, llm-wiki) | `~/.legion/knowledge/` | no |
| Repo workflow configuration | `<repo>/.legion/configuration/` (`project.json`, `workflow.md`) | inner for Private; code repo for Shared |
| Repo scripts and their index | `<repo>/.legion/scripts/`, `index.md` | inner for Private; code repo for Shared |
| Overseer state | `<repo>/.legion/state/handoff.md`, `history/` | inner for Private; code repo for Shared |
| Local specs and plans | `<repo>/.legion/docs/specs/`, `plans/` | no |
| Agent scratch files | `<repo>/.legion/temp/` | no |

The [repository layout](../plugins/legion/skills/legion-repository/references/layout.md) defines ignores and Git ownership. Private is identified by a `.legion/.git` folder. Its outer ignore is local to Git and shared across worktrees. Shared uses the code repo's `.gitignore` and rules file. For explicit choices use `legion repository setup` (see the commands above). Handoff, history, and roadmap commits use the Git repository that owns `.legion/state`.

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

Repository rules, tests and the release flow are in [AGENTS.md](../AGENTS.md).

License: [MIT](../LICENSE).
