# Codex CLI installation hint

When `codex` is missing, run `legion tool install --tool codex` to inspect status and the platform-specific official install command internally. Show commands only when requested or when the owner must run them themselves. Ask the owner whether to install Codex CLI; offer Node.js only where the platform recipe requires it. Only after an explicit yes, run the same command with `--yes`; it checks installed state before changing anything. If the owner declines, stop the account flow for this session.

If installation reports a new terminal is needed for PATH, ask the owner to open one and recheck status. Then repeat the setup step in [accounts.md](accounts.md): setup installs legion before login, and the owner logs in themselves when its table says `log in`. Never read credentials or tokens.

## Platform methods and integrity

On Windows, Node is not required. The default/`--method winget` uses `OpenAI.Codex`. Explicit `--method msi` and `--method zip` both run the official [install.ps1](https://chatgpt.com/codex/install.ps1), which redirects to `https://releases.openai.com/codex/install.ps1`. The vendor manages `%LOCALAPPDATA%/Programs/OpenAI/Codex/bin` and its PATH entry; no administrator or legion ZIP folder is needed.

The official script verifies payload SHA-256 using release metadata asset `digest` and package checksums. The bootstrap script has no separate vendor hash: the installer runs the script without a hash.

On macOS and Linux, the recipe needs Node.js and runs `npm install -g @openai/codex`. Show the prerequisite hint and ask before installing it; a failed prerequisite stops the approved install. Native Windows paths do not require Node.js.

If winget is unavailable or fails, the installer exits 2 and presents explicit `msi`/`zip` choices. Ask for the owner's choice and approval before adding `--method` and `--yes`. Never install a package manager implicitly. Previews make no downloads. Existing CLI detection and approved retries preserve PATH placeholders and registry type.
