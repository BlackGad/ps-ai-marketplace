# Claude Code installation hint

When `claude` is missing, run `pwsh -NoProfile -File <plugin>/bin/ps-ai-install-tool.ps1 -Tool claude` to show status and the exact official install command. Ask the owner whether to install Claude Code. Only after an explicit yes, run the same command with `-Yes`; the script checks for an existing CLI before changing anything. If the owner declines, stop the account flow for this session.

If installation reports a new terminal is needed for PATH, ask the owner to open one and recheck status. Then have the owner log in themselves, run the plugin installer for that account, and validate personalisation as described in [accounts.md](accounts.md). Never read credentials or tokens.
