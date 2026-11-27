# Repository tool hints

At setup, check `git` with `legion tool install --tool git`. If it is missing, tell the owner and ask once whether to install, then pass `--yes` only after an explicit yes. Show commands only when requested or when the owner must run them themselves. If the owner declines, respect that for the rest of this setup session. Stop Git-dependent setup until Git is available.

When Git is available, read `git remote -v` without changing remotes. Offer one relevant missing host CLI:

| Remote host | Tool |
| --- | --- |
| `github.com` | `gh` |
| Host containing `gitlab` | `glab` |
| `dev.azure.com` or `visualstudio.com` | `az` |

For optional helpers, check availability, show the official install steps, install after the owner's yes, then verify. Use [GitHub CLI](https://cli.github.com/manual/installation) or [GitLab CLI](https://gitlab.com/gitlab-org/cli#installation) instructions for those helpers; Azure CLI remains available through `legion tool install --tool az`. A no closes that offer for the setup session.

On Windows, the default uses winget. If it is unavailable or fails, the script exits 2 and prints both choices. Present them to the owner, then run the chosen `--method msi` or `--method zip` with `--yes`. Previewing a method makes no downloads. Do not install a missing package manager implicitly.

For an agent CLI, use the selected tool skill's `references/install.md` for methods, prerequisites, integrity and layout. A tool found only on persistent PATH is skipped without executing it during detection. Portable installs preserve existing PATH placeholders and registry type; an approved retry repairs a missing PATH entry.

## Official Windows sources

These downloads target Windows x64. `msi` selects the vendor's MSI or EXE; MSIs require an administrator session. Git's EXE uses `/CURRENTUSER`. `zip` extracts into `~/.legion/tools/<tool>/` and adds the executable folder to the user PATH once; open a new terminal afterwards.

GitHub release metadata comes from `https://api.github.com/repos/<repo>/releases/latest`; the asset's `browser_download_url` supplies the download URL and its `digest` supplies `sha256:<hex>`. A missing hash stops the install. Node uses its vendor checksum file. A mismatch deletes the download before extraction or execution.

`plugins/legion/helpers.json` holds each helper's download URL pattern, checksum source, executable folder in the ZIP and installer arguments.

Agent installation exceptions belong in the selected tool skill. The shared installer verifies archives and installers before extraction or execution.
