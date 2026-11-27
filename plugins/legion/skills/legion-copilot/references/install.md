# Copilot CLI installation hint

When `copilot` is missing, run `legion tool install --tool copilot` to inspect status and the platform-specific official install command internally. Show commands only when requested or when the owner must run them themselves. Ask the owner whether to install Copilot CLI; offer Node.js only where the platform recipe requires it. Only after an explicit yes, run the same command with `--yes`; it checks installed state before changing anything. If the owner declines, stop the account flow for this session.

If installation reports a new terminal is needed for PATH, ask the owner to open one and recheck status. Then repeat the setup step in [accounts.md](accounts.md): setup installs legion before login, and the owner logs in themselves when its table says `log in`. Never read credentials or tokens.

If setup cannot install legion, run in the selected account's environment, after the owner's yes: `copilot plugin marketplace add BlackGad/ps-legion-marketplace#stable`, then `copilot plugin install legion@ps-legion-marketplace`.

If winget is unavailable or fails, follow the [method choice](../../legion-repository/references/tools.md).

## Platform methods and integrity

On Windows, when Node is already available, the recipe uses `npm install -g @github/copilot` before any explicit method, including `winget`, `msi` or `zip`. This route delegates package integrity to npm. Without Node, native Windows methods do not require it: winget uses `GitHub.Copilot`, `msi` downloads `copilot-x64.msi`, and `zip` downloads `copilot-win32-x64.zip`.

The native downloads use the [github/copilot-cli releases](https://github.com/github/copilot-cli/releases) latest API at `https://api.github.com/repos/github/copilot-cli/releases/latest`. Asset `browser_download_url` supplies the URL and `digest` supplies `sha256:<hex>`. A missing hash stops installation; a mismatch deletes the download before execution or extraction. The MSI needs an administrator and uses `/qn /norestart`. The ZIP has `copilot.exe` at its root extracted to `~/.legion/tools/copilot/`; its folder is added once to user PATH. Open a new terminal afterwards.

On macOS and Linux the recipe needs Node.js and runs `npm install -g @github/copilot`. Ask before installing that prerequisite; failure stops the approved install.
