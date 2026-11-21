# Claude Code installation hint

When `claude` is missing, run `pwsh -NoProfile -File <plugin>/bin/legion-install-tool.ps1 -Tool claude` to inspect status and the official install command internally. Show commands only when requested or when the owner must run them themselves. Ask the owner whether to install Claude Code. Only after an explicit yes, run the same command with `-Yes`; the script checks for an existing CLI before changing anything. If the owner declines, stop the account flow for this session.

If installation reports a new terminal is needed for PATH, ask the owner to open one and recheck status. Then repeat the setup step in [accounts.md](accounts.md): setup installs legion before login, and the owner logs in themselves when its table says `log in`. Never read credentials or tokens.

## Platform methods and integrity

On Windows, Node is not required. The default/`-Method winget` uses `Anthropic.ClaudeCode`. Explicit `-Method msi` and `-Method zip` both run the official [install.ps1](https://claude.ai/install.ps1); these method names do not imply a legion MSI or ZIP extraction. The vendor manages installation and `~/.local/bin/claude.exe`; no administrator is required for this path.

The official script checks `https://downloads.claude.ai/claude-code-releases/<v>/manifest.json`, `platforms.win32-x64.checksum`. The bootstrap script has no separate vendor hash: `Get-ToolDownload` returns `Kind = 'script'` and `Hash = $null`. Payload SHA-256 verification belongs to the vendor script; see [integrity docs](https://code.claude.com/docs/en/setup#binary-integrity-and-code-signing).

On macOS and Linux the recipe runs `bash -c "curl -fsSL https://claude.ai/install.sh | bash"` after approval. Native Windows installation does not need Node.

If winget is unavailable or fails, the installer exits 2 and presents explicit `msi`/`zip` choices. Ask for the owner's choice and approval before adding `-Method` and `-Yes`. Never install a package manager implicitly. Previews make no downloads. Existing CLI detection and approved retries preserve PATH placeholders and registry type.
