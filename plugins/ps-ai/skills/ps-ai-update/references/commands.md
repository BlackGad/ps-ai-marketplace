# Update commands

Run the forced check from the running plugin copy:

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-update.ps1 -Check -Force
```

The result includes the installed and available versions and the update command, `legion update`. Use the versions in the owner conversation; keep the command internal unless the owner asks for it or must run it themselves. The forced check bypasses the daily session-start cache. Checks read the `stable` branch of `BlackGad/ps-ai-marketplace`, which moves only with a published release. `legion update` follows the track the install was added with; to switch between release and main, uninstall, then install.

Before asking for approval, read `skills/ps-ai-<agent.tool>/SKILL.md` and its plugin/update reference for each targeted account's tool. Stop if the tool skill is missing. Explain the documented update scope, including whether it can refresh other marketplaces in that account.

After the owner's yes, run `legion update --yes`; the owner has already agreed, and `--yes` also answers the question the installer asks when ps-ai is missing in a folder. If the check fails, explain the failed check and offer the GitHub update instead (the one-liner in the README); it still requires the owner's yes:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Update
```

Do not infer success from starting the installer; inspect its result. Afterwards the owner runs `legion` in the repository to load the new skills.
