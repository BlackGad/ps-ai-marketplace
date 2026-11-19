# Update commands

Run the forced check from the running plugin copy:

```text
pwsh -NoProfile -File <plugin>/bin/ps-ai-update.ps1 -Check -Force
```

The result includes the installed and available versions and a GitHub script-block update command. Use the versions in the owner conversation; keep the command internal unless the owner asks for it or must run it themselves. The forced check bypasses the daily session-start cache. Checks and generated update commands follow `main` in the detected marketplace source. An installer or catalog revision selected at installation does not pin the plugin or later updates.

Before asking for approval, read `skills/ps-ai-<agent.tool>/SKILL.md` and its plugin/update reference for each targeted account's tool. Stop if the tool skill is missing. Explain the documented update scope, including whether it can refresh other marketplaces in that account.

After the owner's yes, run the returned update command. If the check fails, explain the failed check and offer the default GitHub update instead; it still requires the owner's yes:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/BlackGad/ps-ai-marketplace/main/install.ps1))) -Update
```

Do not infer success from starting the installer; inspect its result. For restart/resume instructions, read `skills/ps-ai-<agent.tool>/SKILL.md` and its references for the selected account's `agent.tool`. Stop if that tool skill is missing; do not guess commands or capabilities.
