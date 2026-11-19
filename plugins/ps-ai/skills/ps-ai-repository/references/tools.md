# Repository tool hints

At setup, check `git` with `pwsh -NoProfile -File <plugin>/bin/ps-ai-install-tool.ps1 -Tool git`. If it is missing, tell the owner and ask once whether to install, then pass `-Yes` only after an explicit yes. Show commands only when requested or when the owner must run them themselves. If the owner declines, respect that for the rest of this setup session. Stop Git-dependent setup until Git is available.

When Git is available, read `git remote -v` without changing remotes. Offer one relevant missing host CLI:

| Remote host | Tool |
| --- | --- |
| `github.com` | `gh` |
| Host containing `gitlab` | `glab` |
| `dev.azure.com` or `visualstudio.com` | `az` |

Use `ps-ai-install-tool.ps1 -Tool <tool>` for status and the command or documentation URL. Ask once per tool in the setup session; a no closes that offer for the session. Run with `-Yes` only after the owner's yes. These host CLIs are optional for local repository setup.

On Windows, the default uses winget. If it is unavailable or fails, the script exits 2 and prints both choices. Present them to the owner, then run the chosen `-Method msi` or `-Method zip` with `-Yes`. Previewing a method makes no downloads. Do not install a missing package manager implicitly.

For an agent CLI, use the selected tool skill's `references/install.md` for methods, prerequisites, integrity and layout. A tool found only on persistent PATH is skipped without executing it during detection. Portable installs preserve existing PATH placeholders and registry type; an approved retry repairs a missing PATH entry.

## Official Windows sources

Checked 2026-11-18; these downloads target Windows x64. `msi` selects the vendor's MSI or EXE; MSIs and the glab EXE require an administrator session. Git's EXE uses `/CURRENTUSER`. No unverified MSI per-user properties are supplied. `zip` extracts into `~/.agents/tools/<tool>/` and adds the executable folder to the user PATH once; open a new terminal afterwards.

GitHub release metadata comes from `https://api.github.com/repos/<repo>/releases/latest`; the asset's `browser_download_url` supplies the download URL and its `digest` supplies `sha256:<hex>`. A missing hash stops the install. Node and glab use their vendor checksum files. A mismatch deletes the download before extraction or execution.

PowerShell MSI deliberately stays on the newest stable 7.6 LTS release for MSI compatibility; ZIP follows the latest stable release because newer releases may ship without an MSI.

| Tool | Latest release and URL pattern | SHA-256 source | Executable folder in ZIP / installer arguments |
| --- | --- | --- | --- |
| PowerShell | [PowerShell/PowerShell releases](https://github.com/PowerShell/PowerShell/releases): `.../download/v<v>/PowerShell-<v>-win-x64.zip`; MSI uses `PowerShell-<v>-win-x64.msi` from the newest stable 7.6.x in `/releases?per_page=100&page=<n>` | GitHub asset `digest` | ZIP root (`pwsh.exe`); MSI `/qn /norestart ADD_PATH=1`. Latest ZIP checked: 7.7.0; latest MSI: 7.6.10, because 7.7 has no MSI. [MSI options](https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows) |
| Git | [git-for-windows/git releases](https://github.com/git-for-windows/git/releases): `.../download/v<v>.windows.<revision>/Git-<v>-64-bit.exe` or `MinGit-<v>-64-bit.zip` | GitHub asset `digest` | `cmd` (`git.exe`); EXE `/VERYSILENT /NORESTART /SP- /CURRENTUSER`. MinGit is the official ZIP alternative to PortableGit's self-extracting EXE. [Installer source](https://github.com/git-for-windows/build-extra/blob/main/installer/install.iss) |
| Node | [dist/index.json](https://nodejs.org/dist/index.json), first entry with `lts`: `https://nodejs.org/dist/<v>/node-<v>-x64.msi` or `node-<v>-win-x64.zip` (`<v>` includes `v`) | `https://nodejs.org/dist/<v>/SHASUMS256.txt`, matching exact filename | `node-<v>-win-x64` (`node.exe`); MSI `/qn /norestart` |
| Azure CLI | [Azure/azure-cli releases](https://github.com/Azure/azure-cli/releases): `.../download/azure-cli-<v>/azure-cli-<v>-x64.msi` or `.zip` | GitHub asset `digest` | `bin` (`az.cmd`); MSI `/qn /norestart`. [Windows ZIP instructions](https://learn.microsoft.com/cli/azure/install-azure-cli-windows) |
| GitHub CLI | [cli/cli releases](https://github.com/cli/cli/releases): `.../download/v<v>/gh_<v>_windows_amd64.msi` or `.zip` | GitHub asset `digest` | `bin` (`gh.exe`); MSI `/qn /norestart` |
| GitLab CLI | [latest release API](https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/releases/permalink/latest), `assets.links[].url`: `https://gitlab.com/api/v4/projects/gitlab-org%2Fcli/packages/generic/glab/<v>/glab_<v>_Windows_x86_64_installer.exe` or `glab_<v>_windows_amd64.zip` (API URLs may percent-encode dots) | Same release's `checksums.txt`, matching exact filename | `bin` (`glab.exe`), inspected in v1.131.0 ZIP; EXE `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /SP-`. [Release installer source](https://gitlab.com/gitlab-org/cli/-/blob/v1.131.0/scripts/setup_windows.iss) confirms Inno Setup; [official flags](https://jrsoftware.org/ishelp/topic_setupcmdline.htm). No installer was executed. |

Agent installation exceptions belong in the selected tool skill. The shared installer verifies archives and installers before extraction or execution.
