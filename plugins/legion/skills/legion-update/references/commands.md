# Update commands

Run the forced check:

```text
legion update --check --force
```

The result includes the installed and available versions and the update command, `legion update`. "Installed" is the version of the legion plugin that the `legion` command was installed from. Use the versions in the owner conversation; keep the command internal unless the owner asks for it or must run it themselves. The forced check bypasses the daily session-start cache. Checks read the `stable` branch of `BlackGad/ps-legion-marketplace`, which moves only with a published release. `legion update` follows the track the install was added with; to switch between release and main, uninstall, then install.

Before asking for approval, read `skills/legion-<agent.tool>/SKILL.md` and its plugin/update reference for each targeted account's tool. Stop if the tool skill is missing. Explain the documented update scope, including whether it can refresh other marketplaces in that account.

On Windows, after the owner's yes, tell them to close the Legion session, run `legion update` from a terminal, then run `legion` in the repository to reopen the conversation. The update refuses before making changes if it finds a registered ancestor. The owner runs the update themselves.

On macOS and Linux, after the owner's yes, run `legion update --yes`. The flag also answers the question the installer asks when legion is missing in a folder. Restart the starting session afterwards to load the new skills.

If the check fails, explain the failed check and offer the GitHub update from the README. It still requires the owner's yes. On Windows, give the owner the PowerShell command to run in a terminal after closing the Legion session.

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Update
```

The bootstrap announces preparation and asks for confirmation in the terminal. If the owner declines, the prompt to retry names `-Yes`, the PowerShell bootstrap flag.

`legion update` waits for MCP servers and `legion run` wrappers registered under its own legion home to exit before replacing the command. Tell the owner before approval. If legion reports that other sessions are still running after 30 seconds, ask the owner to close them and run it again. Continue stopped members from the [handoff](../../legion-overseer/references/takeover.md).

The bootstrap and the installed command on macOS and Linux display uv's progress and the result in the terminal. On Windows, the installed command can schedule its own replacement after it exits. When it does, check `<home>/.legion/temp/uv-tool.log` for the uv exit code or a handover error before reporting success. `legion status` flags a failed handover and points to the log. A same-version update reports the skip immediately.
