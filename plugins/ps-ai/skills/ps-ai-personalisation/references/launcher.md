# Overseer launcher shim

During owner setup, put `ps-ai-overseer` in `<home>/.agents/bin/` and ensure that folder is on PATH. The Unix shim uses `exec pwsh -NoProfile -File '<absolute plugin path>/bin/ps-ai-overseer.ps1' "$@"`; on Windows write `ps-ai-overseer.cmd` with `@pwsh -NoProfile -File "<absolute plugin path>\bin\ps-ai-overseer.ps1" %*`. Preserve each argument; ask before replacing a conflicting command.

Usage: `ps-ai-overseer -Account <id> [-Tool <tool-id>] [-Channel <id[]>] [-Model <model>] [-Arguments <string[]>] [-Repo <path>]`. In a fixture pass `-HomeRoot <temp home>`; `-DryRun` prints arguments without opening a window. The shipped launcher validates minimal owner/project JSON and merges additional model arguments, explicit arguments, channel vectors and interactive arguments before the initial prompt. Do not reimplement this in the shim.

Any owner-started session may take the lease on request without a channel. For requested destinations, read owner notes and route to `skills/ps-ai-<kind>/SKILL.md`; stop if missing. Prefer the current account when bound and its session tools are available. Otherwise name a supported bound alternate before an authorized relaunch. Pass `-Account <id>` explicitly, with optional `-Tool`, `-Channel <id[]>`, `-Model` and literal `-Arguments`. Declining relaunch permits current channel-free work. Follow the overseer communication guide's handoff/release/launch/stop sequence. A direct shim invocation requests launch. Simulations describe actions without running them.

Read the selected tool skill's `references/launcher.md` for explicit account/model/argument examples and channel routing.

On Windows the launcher uses Terminal when available, invoking the selected command through PowerShell so batch wrappers work. It uses the current terminal if Terminal is missing or an argument or path contains a literal semicolon. Approved plugin updates refresh ps-ai-owned runtime copies and retarget existing launcher shims while preserving account settings and shim arguments.
