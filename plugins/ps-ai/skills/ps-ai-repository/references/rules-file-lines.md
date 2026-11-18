## ps-ai orchestration

- This repo uses the ps-ai plugin. Modes: a session is a legion member only when `PS_AI_ROLE=legion` is set; it acts as the overseer only when the owner asks to continue; otherwise it works ad hoc.
- Tasks go to the legion accounts named in the owner's ps-ai personalisation, not to same-tool subagents.
- Plans and specs go to the paths in `.agents/configuration/project.json`.
- Fixed repo steps are scripts in `.agents/scripts/`, listed in `.agents/scripts/index.md`; use them instead of composing commands.
