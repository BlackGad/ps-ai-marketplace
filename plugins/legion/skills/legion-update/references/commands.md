# Update commands

Run the forced check:

```text
legion update --check --force
```

The result includes the installed and available versions and the update command, `legion update`. "Installed" is the version of the legion plugin that the `legion` command was installed from. Use the versions in the owner conversation; keep the command internal unless the owner asks for it or must run it themselves. The forced check bypasses the daily session-start cache. Checks read the `stable` branch of `BlackGad/ps-legion-marketplace`, which moves only with a published release. `legion update` follows the track the install was added with; to switch between release and main, uninstall, then install.

Before asking for approval, read `skills/legion-<agent.tool>/SKILL.md` and its plugin/update reference for each targeted account's tool. Stop if the tool skill is missing. Explain the documented update scope, including whether it can refresh other marketplaces in that account.

After the owner's yes, run `legion update --yes`; the owner has already agreed, and `--yes` also answers the question the installer asks when legion is missing in a folder. If the check fails, explain the failed check and offer the GitHub update instead (the one-liner in the README); it still requires the owner's yes:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/install.ps1))) -Update
```

`legion update` first ends every running legion session (the MCP server and `legion run` wrappers) and waits up to 30 seconds for them; tell the owner before approving, and a member that was running is resumed afterwards from the handoff. If it reports that legion is still running, ask the owner to close those sessions and run it again. Then the legion command is replaced with `uv tool install` after legion exits.

Do not infer success from starting the installer; inspect its result.
