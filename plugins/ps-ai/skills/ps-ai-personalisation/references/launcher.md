# Overseer launcher shim

During owner setup, put `ps-ai-overseer` in `<home>/.agents/bin/` and ensure that folder is on PATH. The Unix shim uses `exec pwsh -NoProfile -File '<absolute plugin path>/bin/ps-ai-overseer.ps1' "$@"`; on Windows write `ps-ai-overseer.cmd` with `@pwsh -NoProfile -File "<absolute plugin path>\bin\ps-ai-overseer.ps1" %*`. Preserve each argument; ask before replacing a conflicting command.

Usage: `ps-ai-overseer [-Tool <tool-id>] [-Account <id>] [-Repo <path>]`. In a fixture pass `-HomeRoot <temp home>`; `-DryRun` prints arguments without opening a window. The shipped launcher resolves repo id and merges account, channel, then project flags. Do not reimplement this in the shim.

When an interactive session lacks the project's channel tool and the owner says continue, ask whether to open an overseer window with the channel. Run `ps-ai-overseer.ps1` only after a yes; the current session stays ad hoc. A direct shim invocation requests a launch. In guided simulations describe the proposed launch without running it; show commands only when requested or when the owner must run them themselves.

Read the selected tool skill's `references/launcher.md` for account, channel, project and CLI argument examples.

On Windows the launcher uses Terminal when available, invoking the selected command through PowerShell so batch wrappers work. It uses the current terminal if Terminal is missing or an argument or path contains a literal semicolon. Approved plugin updates refresh ps-ai-owned runtime copies and retarget existing launcher shims while preserving account settings and shim arguments.
