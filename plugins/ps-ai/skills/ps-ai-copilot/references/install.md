# Copilot CLI installation hint

When `copilot` is missing, run `pwsh -NoProfile -File <plugin>/bin/ps-ai-install-tool.ps1 -Tool copilot` to show status, any Node.js prerequisite, and the exact official install command. Ask the owner whether to install Copilot CLI and, if needed, Node.js. Only after an explicit yes, run the same command with `-Yes`; it checks installed state before changing anything. If the owner declines, stop the account flow for this session.

If installation reports a new terminal is needed for PATH, ask the owner to open one and recheck status. Then have the owner log in themselves, run the plugin installer for that account, and validate personalisation as described in [accounts.md](accounts.md). Never read credentials or tokens.
