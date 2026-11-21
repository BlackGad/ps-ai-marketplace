## legion orchestration

- This repo uses the legion plugin. Modes: a session is a legion member only when `LEGION_ROLE=member` is set; it acts as the overseer only when the owner asks to continue; otherwise it works ad hoc.
- Tasks go to the legion accounts named in the owner's legion personalisation, not to same-tool subagents.
- Plans and specs go to the paths recorded in `.legion/configuration/workflow.md`.
- Fixed repo steps are scripts in `.legion/scripts/`, listed in `.legion/scripts/index.md`; use them instead of composing commands.
