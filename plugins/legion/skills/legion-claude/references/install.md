# Claude Code installation hint

When `claude` is missing, run `legion tool install --tool claude` to inspect status and the official install command internally. Show commands only when requested or when the owner must run them themselves. Ask the owner whether to install Claude Code. Only after an explicit yes, run the same command with `--yes`; the script checks for an existing CLI before changing anything. If the owner declines, stop the account flow for this session.

If installation reports a new terminal is needed for PATH, ask the owner to open one and recheck status. Then repeat the setup step in [accounts.md](accounts.md): setup installs legion before login, and the owner logs in themselves when its table says `log in`. Never read credentials or tokens.

If winget is unavailable or fails, follow the [method choice](../../legion-repository/references/tools.md).

## Platform methods and integrity

On Windows, Node is not required. The default and `--method winget` use `Anthropic.ClaudeCode`; `--method msi` and `--method zip` both run the official [install.ps1](https://claude.ai/install.ps1). The vendor manages installation and `~/.local/bin/claude.exe`; no administrator is required.

Payload SHA-256 verification belongs to the vendor script, which checks `https://downloads.claude.ai/claude-code-releases/<v>/manifest.json`, `platforms.win32-x64.checksum`; see [integrity docs](https://code.claude.com/docs/en/setup#binary-integrity-and-code-signing).

On macOS and Linux the recipe runs `bash -c "curl -fsSL https://claude.ai/install.sh | bash"` after approval.
