# Codex CLI installation hint

When `codex` is missing, run `pwsh -NoProfile -File <plugin>/bin/ps-ai-install-tool.ps1 -Tool codex` to show status and the platform-specific official install command. Ask the owner whether to install Codex CLI; offer Node.js only where the platform recipe requires it. Only after an explicit yes, run the same command with `-Yes`; it checks installed state before changing anything. If the owner declines, stop the account flow for this session.

If installation reports a new terminal is needed for PATH, ask the owner to open one and recheck status. Then have the owner log in themselves, run the plugin installer for that account, and validate personalisation as described in [accounts.md](accounts.md). Never read credentials or tokens.

## Platform methods and integrity

On Windows, Node is not required. The default/`-Method winget` uses `OpenAI.Codex`. Explicit `-Method msi` and `-Method zip` both run the official [install.ps1](https://chatgpt.com/codex/install.ps1), which redirects to `https://releases.openai.com/codex/install.ps1`. The vendor manages `%LOCALAPPDATA%/Programs/OpenAI/Codex/bin` and its PATH entry; no administrator or ps-ai ZIP folder is needed.

The official script verifies payload SHA-256 using release metadata asset `digest` and package checksums. The bootstrap script has no separate vendor hash: `Get-ToolDownload` returns `Kind = 'script'` and `Hash = $null`.

On macOS and Linux, the recipe needs Node.js and runs `npm install -g @openai/codex`. Show the prerequisite hint and ask before installing it; a failed prerequisite stops the approved install. Native Windows paths do not require Node.js.

If winget is unavailable or fails, the installer exits 2 and presents explicit `msi`/`zip` choices. Ask for the owner's choice and approval before adding `-Method` and `-Yes`. Never install a package manager implicitly. Previews make no downloads. Existing CLI detection and approved retries preserve PATH placeholders and registry type.
