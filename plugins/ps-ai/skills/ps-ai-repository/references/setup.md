# Setup script

For tool operations, read `skills/ps-ai-<agent.tool>/SKILL.md` using the selected account's `agent.tool`; stop if it is missing.

Check the mode using [layout.md](layout.md) first. A `.legion/.git` folder or file means Private; otherwise `git ls-files .legion` must list tracked files for Shared. If neither check matches, setup is not finished: ask the owner the setup choice again, with Private as the default, and complete it.

One run does the whole fresh setup, `-Mode Shared` for the other choice (Private is the default):

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-repository.ps1 -Repo <repo> [-Mode Shared] [-Gate '<command>'] [-RulesFile <file>]
```

It creates `project.json`, `workflow.md` with the rules block (Private) or the rules file block (Shared), the script index, handoff, history and local docs from the templates in this folder, applies the ignore rules in [layout.md](layout.md), and commits only the paths it touched (Private in the inner repository). `-Gate` also writes `check-task.ps1` and its index row. Existing files stay byte-identical. It stops before any change when a file it must edit has uncommitted edits, and asks for `-RulesFile` when two rules files are ambiguous. It validates `project.json`; a repeat prints `skip: <Mode> orchestration (already done)`.

Plans and specs use the paths recorded in `workflow.md`. Create `.legion/state/roadmap/<goal-id>.md` from [roadmap-template.md](roadmap-template.md) only after the owner approves a roadmap. New scratch output belongs in `.legion/temp/`. Follow [takeover.md](../../ps-ai-overseer/references/takeover.md) for later state commits.
