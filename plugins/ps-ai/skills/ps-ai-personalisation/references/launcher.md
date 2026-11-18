# Overseer launcher shim

During owner setup, put `ps-ai-overseer` in `<home>/.agents/bin/` and ensure that folder is on PATH. The Unix shim uses `exec pwsh -NoProfile -File '<absolute plugin path>/bin/ps-ai-overseer.ps1' "$@"`; on Windows write `ps-ai-overseer.cmd` with `@pwsh -NoProfile -File "<absolute plugin path>\bin\ps-ai-overseer.ps1" %*`. Preserve each argument; ask before replacing a conflicting command.

Usage: `ps-ai-overseer [-Tool claude|codex|copilot] [-Account <id>] [-Repo <path>]`. In a fixture pass `-HomeRoot <temp home>`; `-DryRun` prints arguments without opening a window. The shipped launcher resolves repo id and merges account, channel, then project flags. Do not reimplement this in the shim.

When an interactive session lacks the project's channel tool and the owner says continue, ask whether to open an overseer window with the channel. Run `ps-ai-overseer.ps1` only after a yes; the current session stays ad hoc. A direct shim invocation requests a launch. In guided simulations show commands without running a real launch.
