# ps-ai plugin: design

Date: 2026-11-18. Status: draft for owner review.

## 1. Goal

One plugin, `ps-ai`, installable into Claude Code, Codex CLI and GitHub Copilot CLI, that lets any of these tools:

- act as the **overseer** (orchestrator) of a repository and continue work that another tool started;
- act as a **legion** member (working agent) when, and only when, an overseer launched it;
- read one per-user **personalisation** (accounts, model roles, preferences, channels);
- consult and grow a per-user, cross-project **knowledge** wiki.

Success:

1. One install command per machine puts the plugin into every installed tool.
2. A fresh session in any repo picks the right mode without being told.
3. An overseer session can stop at any moment and another tool continues from tracked files.
4. Every skill passes baseline and guided verification (section 12), including with superpowers installed.

Out of scope: method skills (TDD, debugging, brainstorming, code review, worktrees). The plugin relies on whatever method skills are installed, usually superpowers. Moving an existing repository to this layout is a separate task after the plugin exists.

## 2. Terms

| Term | Meaning |
| --- | --- |
| Owner | The user. Owns design, scope, public API, other repositories, tooling and budgets. |
| Overseer | The orchestrating session: plans, delegates, reviews, keeps state, talks to the owner. |
| Legion | A working agent started by the overseer for one task. |
| Account | One CLI login, reached through one command (`claude`, `claude-b`, `codex-personal`). |
| Personalisation | Per-user configuration and notes under `~/.agents/configuration/`. |
| Knowledge | Per-user llm-wiki hub under `~/.agents/knowledge/`. |

## 3. Locations

| What | Where | Scope | Tracked |
| --- | --- | --- | --- |
| Personalisation (structured) | `~/.agents/configuration/ps-ai-personalisation.json` | user, all repos | no (user's own) |
| Personalisation (free form) | `~/.agents/configuration/ps-ai-notes.md` | user, all repos | no |
| Generated launchers and account wrappers | `~/.agents/bin/` | user | no |
| Extra account config folders | `~/.agents/accounts/<id>/` (existing ones keep their path) | user | no |
| Knowledge wiki hub | `~/.agents/knowledge/` | user, all repos | no |
| Repo workflow configuration | `<repo>/.agents/configuration/` | repo | yes |
| Repo scripts and their index | `<repo>/.agents/scripts/`, `index.md` | repo | yes |
| Overseer state | `<repo>/.agents/state/handoff.md`, `history/` | repo | yes |
| Agent scratch | `<repo>/.agents/temp/` | repo | no (only this folder is ignored) |

Existing `.agents/` uses that must keep working: `.agents/skills/` (open skill standard; Codex and Copilot read it) and `.agents/plugins/marketplace.json` (Codex marketplace). The names above do not collide with them.

`~` means the user's home folder (`%USERPROFILE%` on Windows).

## 4. Skills

All skills live in one plugin, `ps-ai`, under `skills/<name>/SKILL.md` with `references/` for detail. Types follow the repository skill-writing standard.

| Skill | Type | Job |
| --- | --- | --- |
| `ps-ai-personalisation` | Context provider | Read, validate and create the user's JSON and notes; own the schemas; clean up projects on request; put the overseer launcher on PATH. Every other skill loads it first. |
| `ps-ai-knowledge` | Planner | When and how to consult the cross-project wiki; when and what to file; the sanitising rule. Works through llm-wiki. |
| `ps-ai-repository` | Planner | Set up a repo: `.agents/configuration`, `scripts` with `index.md`, `state`, ignored `temp`; the precedence and delegation rule in the repo rules file; the "fixed step becomes a script" rule. |
| `ps-ai-overseer` | Planner | Take over from `.agents/state`; run the milestone flow and the task loop; dispatch reviews to independent model families; keep the handoff current; talk to the owner. |
| `ps-ai-legion` | Planner | The worker contract: one task, own scope only, local commits only, report format, when to stop. |
| `ps-ai-claude` | Tool | Run Claude Code as a legion member (print mode, resume, report), ping limits, add/rename/remove accounts. |
| `ps-ai-codex` | Tool | The same for Codex CLI. |
| `ps-ai-copilot` | Tool | The same for Copilot CLI, including read-only reviewer flags. |

Tool skills know how to operate their tool. Which account does what lives only in personalisation.

### 4.1 Relation to installed method skills

- ps-ai owns **who does the work, where, and where the record lives**. Installed method skills own **how one piece of work is done**.
- Skills name a method skill only as a soft reference ("use the installed test-driven-development skill when present") and never copy its text.
- Two real overlaps are resolved by repo instructions, which method skills already rank above themselves:
  - **Delegation:** tasks go to the legion accounts named in personalisation, not to same-tool subagents.
  - **Paths:** plans and specs go to the paths in `.agents/configuration/project.json`.
- `ps-ai-repository` writes both rules into the repo rules file (`AGENTS.md` or the file named in `project.json`), together with one line naming the modes of section 5, so the modes still apply where a hook is not active.

## 5. Modes and enforcement

A session-start hook decides the mode and injects one short context block. Skill triggers key off the mode, not off general words like "plan" or "build".

| Mode | Condition | Injected context and behaviour |
| --- | --- | --- |
| Legion | `PS_AI_ROLE=legion` and `PS_AI_TASK=<prompt path>` in the environment | Load `ps-ai-legion` with the task path. Overseer skills are off. A legion member never starts other legion members. |
| Overseer (on request) | Interactive session, repo has `.agents/state/`, the owner says continue, progress or next | Load `ps-ai-overseer`; take the overseer lease; take over from the handoff. |
| Setup | The owner asks to set up orchestration; no `.agents/configuration/` | Load `ps-ai-repository`, after `ps-ai-personalisation` if no personalisation exists. |
| Ad hoc | Everything else | Stay quiet. In an orchestrated repo, print one hint line from the handoff: *"This repo is orchestrated (milestone X, task N of M). Say continue to act as the overseer."* |

Rules:

1. Only the environment variable makes a session a legion member. An interactive launch never sets it.
2. **Overseer lease.** `.agents/temp/overseer.lock` holds tool, account, process id and start time. A second overseer warns the owner instead of taking over. A lease whose process is gone is stale and may be taken over.
3. A session never becomes the overseer by itself; the owner asks.

Hook support (verified 2026-11-18 against official docs):

| Tool | Hook | Context injection | Note |
| --- | --- | --- | --- |
| Claude Code | plugin `hooks/hooks.json`, `SessionStart` | stdout or `additionalContext` | — |
| Codex CLI 0.167 | `.codex-plugin/plugin.json` → `hooks/hooks.json`, `SessionStart` | stdout becomes developer context | the owner trusts plugin hooks once (`/hooks`) |
| Copilot CLI 1.0.109 | plugin `hooks.json`, `sessionStart` | `additionalContext` | — |

The hook command is one PowerShell 7 script, `detect-mode.ps1 -Format text|copilot-json`, that reads only: the two environment variables, whether `.agents/state/handoff.md` exists, the handoff's milestone and task lines, and the lease file. `text` prints the context block (Claude, Codex); `copilot-json` prints `{"additionalContext": "..."}`. Where a hook is not trusted or not available, the repo rules-file line from section 4.1 still names the modes, so the skills work without the hook, only less precisely.

## 6. Personalisation

### 6.1 Structured file

`~/.agents/configuration/ps-ai-personalisation.json`, validated by `schemas/personalisation.schema.json` shipped in the plugin (PowerShell 7 `Test-Json -SchemaFile`). JSON because PowerShell reads and validates it with built-in commands; nothing is installed (owner ruling 2026-11-18). The schema's `description` fields explain every key, and `"$schema"` lets editors show them. Example (the owner's current setup):

```json
{
  "$schema": "<plugin>/schemas/personalisation.schema.json",
  "schemaVersion": 1,
  "communication": {
    "language": "simple-english",
    "questions": "one-at-a-time",
    "channels": {
      "telegram-main": {
        "kind": "telegram", "target": "123456789", "format": "markdownv2", "tone": "business",
        "launch": { "claude": ["--channels", "plugin:telegram@claude-plugins-official"] }
      }
    }
  },
  "agents": [
    { "id": "claude", "tool": "claude", "command": "claude", "configDir": "default", "roles": ["overseer"], "care": "high", "launch": { "args": [] } },
    { "id": "claude-b", "tool": "claude", "command": "~/bin/claude-b", "configDir": "~/.claude-b", "roles": ["legion", "reviewer"], "models": { "legion": "opus", "reviewer": "opus" } },
    { "id": "codex-a", "tool": "codex", "command": "~/bin/codex-a", "configDir": "~/.codex", "roles": ["legion", "reviewer"], "models": { "legion": "gpt-6-sol", "reviewer": "gpt-6-astra" } },
    { "id": "codex-b", "tool": "codex", "command": "~/bin/codex-b", "roles": ["legion"], "models": { "legion": "gpt-6-sol" } },
    { "id": "copilot", "tool": "copilot", "command": "copilot", "configDir": "default", "roles": ["reviewer"], "models": { "reviewer": "gemini-4-argon" }, "cost": "paid" }
  ],
  "routing": {
    "implement": ["codex-a", "codex-b", "claude-b"],
    "review": ["codex-a", "claude-b", "copilot"],
    "mechanical": ["claude-b"],
    "neverModels": ["grok-4.7"],
    "rules": ["astra only for milestone review, never implementation", "sol never as reviewer"]
  },
  "knowledge": { "backend": "llm-wiki", "hub": "~/.agents/knowledge" },
  "projects": {
    "my-project": { "label": "example", "notify": ["telegram-main"], "launch": {}, "routing": {} }
  },
  "default": { "notify": [] }
}
```

Field meanings: `tool` is `claude | codex | copilot`; `configDir` is `default` or a folder; `roles` from `overseer | legion | reviewer | mechanical`; `care: high` means spend carefully; `cost: paid` means ask before use; `routing` lists are in preference order (the next one is used when an account is at its limit); `knowledge.backend` is `llm-wiki | none`; `projects` are keyed by the id in `<repo>/.agents/configuration/project.json`; `label` is a neutral wiki label, never a client name.

Rules:

- **No secrets.** Only commands and config folders, never tokens. Skills never read credential files.
- **Account ids** are any lowercase hyphenated name, unique in the file, and not an existing command on PATH. The default suggestion is `<tool><n>`.
- **Projects are keyed by repo id**, not path, so moves and clones keep their settings. No "last seen" field; the file changes only when the owner changes the setup. Stale entries are harmless; cleanup runs only when the owner asks, and lists each entry for confirmation.
- A new repo id with no entry: the first overseer takeover asks once where to notify and adds the entry.
- **Fixed safety rules are not configuration**; they live in the skills: never read, print or log credentials; never force-push or amend; ask before installing tools. Personal habits go in the notes; project facts go to the project.
- Limits are not configured: tool skills always ping an account before declaring it out of credit; `care: high` is how an account is spared.

### 6.2 Notes file

`~/.agents/configuration/ps-ai-notes.md`: free-form preferences and lessons that change behaviour, for example "read the test before a stress loop", "flat visuals only", "never open windows (except the overseer launcher, after a yes)". Every mode reads it.

### 6.3 Overseer launcher

The plugin ships `bin/ps-ai-overseer.ps1`; `ps-ai-personalisation` puts a small shim for it in `~/.agents/bin/` (on PATH):

```
ps-ai-overseer [-Tool claude|codex|copilot] [-Account <id>] [-Repo <path>]
```

It reads the repo id, merges arguments in this order: the account's `launch.args`, each notify channel's `launch.<tool>`, the project's `launch.<tool>`; opens a new terminal tab (`wt` on Windows, else a new terminal) running the account's command with those arguments and the first prompt "continue as the overseer". A channel without flags for the chosen tool produces a warning; updates then go to the terminal only.

Two entry points:

1. **From a session.** The owner says continue in a session that lacks a project channel. `ps-ai-overseer` asks: "This session has no Telegram. Open an overseer window with it?" On yes it runs the launcher; the current session stays ad hoc.
2. **Directly.** The owner types `ps-ai-overseer` in any terminal.

## 7. Repository layout

```
<repo>/.agents/
  configuration/
    project.json       structured: id, rules file, paths, delivery, steps
    workflow.md        free form: how this repo makes a roadmap, milestone and task
  scripts/
    index.md
    <script files>
  state/
    handoff.md
    history/
  temp/                git-ignored
```

### 7.1 project.json

Validated by `schemas/project.schema.json` shipped in the plugin.

```json
{
  "$schema": "<plugin>/schemas/project.schema.json",
  "schemaVersion": 1,
  "id": "my-project",
  "rulesFile": "AGENTS.md",
  "paths": {
    "roadmap": "docs/superpowers/plans/2026-10-23-weave-roadmap.md",
    "plans": "docs/superpowers/plans",
    "specs": "docs"
  },
  "delivery": "merge-request",
  "steps": {
    "task": { "before": [], "after": ["check-task"] },
    "milestone": { "before": [], "after": ["check-milestone", "bench-compare"] }
  }
}
```

`delivery` is `merge-request | direct`. `steps` name scripts from `scripts/index.md`, never raw commands. Only repo facts that every contributor shares; nothing personal.

### 7.2 Scripts and index

Rule for every ps-ai skill: a step that is fixed for this repo (a gate, a build, a benchmark, a cleanup) becomes a script in `.agents/scripts/` with a row in `index.md`; the skills then call the script by name and never compose the commands again. When a needed fixed step has no script, the overseer creates it (or has a legion member create it) and adds the row before using it.

`index.md` format:

| Script | When | What it does | Arguments | Output |
| --- | --- | --- | --- | --- |
| `check-task.ps1` | after each task | Release build, analyzers, suites of changed projects | `-Base <commit>` | pass/fail table; log in `.agents/temp/` |

### 7.3 Handoff

`.agents/state/handoff.md` with fixed headings, so any tool reads it the same way:

1. Branch
2. Milestone and base commit
3. State (step of the milestone flow)
4. Current task
5. Legion running (account, task, prompt path, report path, log path, base commit, start time)
6. Next action
7. Open decisions
8. Postponed (with reason)
9. Recent evidence

Write-ahead rules (hard rules in `ps-ai-overseer`):

1. Before a legion member starts: add its row and set the next action to "wait for task N, then review".
2. After it ends: record the result (commit, checks, report), remove the row, set the next action.
3. At every milestone-flow step and before asking the owner a question.
4. Only the overseer writes the handoff; legion members write their report file.
5. Each update goes to disk at once and is committed with the stage it belongs to.

Takeover, for each "legion running" row: process alive → wait; report present → review it; task commit present without report → review from the commit; none → save uncommitted work as a patch and relaunch (same account when resuming, the patch on another account otherwise).

History: one file per finished milestone in `history/`; the handoff stays short.

## 8. Overseer flow

`ps-ai-overseer` keeps the milestone flow from the current playbook as a state machine, with prompt templates in `references/`:

Research → design questions → plan draft → plan dry-run → rulings → tasks → milestone gate → gate fixes → performance check → reviews → findings to owner → review fixes → close-out.

- Steps that are fixed for the repo come from `project.json` `steps` and run as scripts.
- Design questions, plan writing, TDD, debugging and the review checklist use the installed method skills.
- **Review dispatch stays in ps-ai** (`references/reviews.md`): reviewers from different model families picked from `routing.review`, frozen worktree, same brief, no shared reports, one verifier per report, merge by agreement then severity. The review content comes from the installed review skills.
- Flaky or intermittent failures: the overseer starts a legion member with an investigation prompt that names the installed debugging skill.
- Parallel lanes: at most two, split by owner type, each in its own worktree `.agents/temp/floor-<n>/`.
- Progress messages go to the project's `notify` channels, in the channel's format and tone.

## 9. Knowledge

- Hub at `~/.agents/knowledge/` (llm-wiki's `hub-path` setting). Installing llm-wiki is the owner's choice; `ps-ai-knowledge` explains how and never installs it.
- **Consult:** at milestone research before planning; when stuck after two failed attempts at the same problem; when a failure looks familiar (flaky tests, lane merge conflicts, account limits).
- **File:** at milestone close-out (patterns, decisions with reasons, problems and how they were solved) and right after a hard problem is solved.
- **Sanitise before filing:** generalised patterns only. No client names, code, hosts, addresses or secrets. Each entry is tagged with the project's neutral `label`.
- **Reading needs no plugin:** the wiki is Markdown with `_index.md`, so a Copilot overseer searches it directly. Writing goes through the wiki skills where installed; otherwise the overseer drops a raw note in the wiki inbox for the next compile.
- A lesson that changes behaviour also goes into `ps-ai-notes.md`; rules never depend on the wiki.

## 10. Accounts and tool skills

Each tool skill covers the same five operations, with tool-specific detail in `references/`:

| Operation | Claude | Codex | Copilot |
| --- | --- | --- | --- |
| Run as legion member | print mode with prompt file, `PS_AI_ROLE`/`PS_AI_TASK` set | `exec` with prompt on stdin, `-o <report>` | prompt mode with tool denials for reviewers |
| Resume after a question | same account only | `exec resume --last`, same account and folder | same account only |
| Ping limits | `-p --model <small> --output-format stream-json --verbose`, read the rate-limit event | short `exec`, read the newest session record's rate limits | no limit readout found; a short prompt run that fails with a quota error means out |
| Add account | wrapper sets `CLAUDE_CONFIG_DIR` | wrapper sets `CODEX_HOME` | wrapper sets `COPILOT_HOME` |
| Rename / remove account | wrapper, `agents` entry and every `routing` reference in one step; folder rename only after asking | same | same |

Adding an account: ask for the name (suggest `<tool><n>`); create `~/.agents/bin/<id>` (and `.cmd` on Windows) and `~/.agents/accounts/<id>/`; ask the owner to log in once in a terminal (the skill never handles credentials); run the plugin installer for that config folder; add the `agents` entry; validate. Existing wrappers (`~/bin/claude-b`, `~/bin/codex-a`, `~/bin/codex-b`) are registered as they are.

## 11. Marketplace and install

```
ps-ai-marketplace/
  .claude-plugin/marketplace.json     Claude Code and Copilot CLI (Copilot reads this path)
  .agents/plugins/marketplace.json    Codex
  plugins/ps-ai/
    .claude-plugin/plugin.json        Claude Code
    .codex-plugin/plugin.json         Codex: "skills": "./skills/", "hooks": "./hooks/hooks.json"
    plugin.json                       Copilot CLI (its first manifest location): "hooks": "hooks/copilot-hooks.json"
    hooks/hooks.json                  Claude and Codex format (SessionStart)
    hooks/copilot-hooks.json          Copilot format (sessionStart, version 1)
    hooks/detect-mode.ps1
    bin/ps-ai-overseer.ps1            overseer launcher
    skills/ps-ai-*/SKILL.md, references/
    schemas/personalisation.schema.json, project.schema.json
  install/install.ps1, install.sh     install.sh only runs install.ps1 with pwsh
  tests/
  README.md
```

All scripts are PowerShell 7 (`pwsh`), which runs on Windows, Linux and macOS; it is the one runtime requirement, and the installer stops with a clear message when it is missing. Facts verified 2026-11-18: Copilot CLI reads `plugin.json`, `.github/plugin/plugin.json` or `.claude-plugin/plugin.json`, and `.claude-plugin/marketplace.json`; Codex sets `CLAUDE_PLUGIN_ROOT` as well as `PLUGIN_ROOT` for hooks; the Telegram channel loads with `claude --channels plugin:telegram@claude-plugins-official`; `COPILOT_HOME` moves Copilot's configuration and state.

`install.ps1 [-Tools claude,codex,copilot] [-ConfigDir <path>]`:

1. Find which CLIs are installed.
2. For each: add the marketplace and install `ps-ai` with that tool's own commands (`claude plugin marketplace add` / `install`, `codex plugin marketplace add` / `add`, `copilot plugin marketplace add` / `install`).
3. Print a table: tool, version, plugin installed, hooks active (Codex: remind to trust hooks once).
4. Never create or change personalisation; the first session's `ps-ai-personalisation` does that.
5. `-ConfigDir` installs into one extra account's folder; tool skills call it when an account is added.

The README holds install commands per tool and the dependency note on method skills.

## 12. Verification

- **Per skill (standard):** baseline run without the skill and guided run with it, on a small fixture repo; record the difference.
- **Mode detection:** a fixture table runs against `detect-mode.ps1` in both formats: legion env, orchestrated repo, no state, stale lease, live lease.
- **Conflict check:** guided runs of `ps-ai-overseer` with superpowers installed in Claude Code and Codex; pass when tasks go to legion accounts and plans go to `project.json` paths.
- **Takeover drill:** start an overseer in one tool, kill it with a legion member running, continue in another tool; pass when the new overseer follows the takeover rules from the handoff alone.
- **Install:** `claude plugin validate` on the marketplace and plugin; install with each tool's commands; `plugin list` shows `ps-ai` enabled.
- **Schema:** valid and invalid personalisation samples against the JSON Schema.

## 13. Confirmed facts

All four open points were settled on 2026-11-18; see section 11. One remains to prove by running it: that Copilot picks the root `plugin.json` over `.claude-plugin/plugin.json` when both exist (the install task checks it).

## 14. Easter eggs

The names come from the anime *Overlord* (the overseer is Albedo's title; the owner is the Supreme Being). A few hints are hidden for fans. Rules:

- **Rare:** at most six in the whole plugin.
- **Dual meaning:** each must read as ordinary professional text to anyone who does not know the show. No character names, no quotes a general reader would find odd.
- **Never in owner-facing reports** (progress messages, review tables, MR text) and never in anything a client sees: business tone stays clean.
- **Never change behaviour or names that carry meaning**, except where the plain meaning is just as good.

The set:

| Where | Text | Plain meaning | Fan meaning |
| --- | --- | --- | --- |
| Lane worktrees | `.agents/temp/floor-1/`, `floor-2/` | levels of parallel work | the floors of the Great Tomb, each with its guardian |
| Overseer takeover message | "All floors report in." | every lane checked | the Floor Guardians' assembly |
| Milestone close-out line | "Everything proceeds according to plan." | the milestone met its plan | Demiurge crediting a plan Ainz never made |
| Error when a legion member tries to start another | "A summoned unit cannot summon." | legion members cannot launch agents | summoned undead do not summon |
| Plugin description | "Orchestration that keeps every floor in order, so the one in charge only has to nod." | the owner approves, the overseer works | Ainz nodding along to schemes he does not follow |
| README source | an HTML comment with the full naming map | invisible when rendered | the map for those who read the source |
