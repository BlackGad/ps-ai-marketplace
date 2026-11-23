import shutil
import subprocess
import sys
from pathlib import Path
from typing import Optional

from . import _plugin

# Temporary while legion moves to Python: verbs the PowerShell entry point still serves, with their help line.
# Each row goes when its verb is ported. Bare `legion` and flags-only calls forward too, with no verb.
ENTRY_SCRIPT = "bin/legion.ps1"
FORWARDED_VERBS = {
    "pick": "Choose which account leads the overseer",
    "setup": "Finish setup: settings, commands, legion in every account",
    "add": "Add a claude, codex or copilot account",
    "remove": "Remove an account (its folder is kept)",
    "status": "Show accounts, commands, channels and this repository",
    "limits": "Show each account's usage windows and reset times",
    "update": "Update legion to the newest version of its track",
    "uninstall": "Remove legion; --purge also deletes settings, notes and logins",
    "help": "Show the legion commands",
}
PWSH_MISSING = "pwsh is missing. Ask the owner before installing PowerShell 7, then run the legion installer again."


# Runs the PowerShell entry point in the caller's console and folder and returns its exit code.
def run(words: list[str], home: Optional[Path]) -> int:
    pwsh = shutil.which("pwsh")
    if pwsh is None:
        print(PWSH_MISSING, file=sys.stderr)
        return 127
    command = [pwsh, "-NoProfile", "-File", str(_plugin.PLUGIN_ROOT / ENTRY_SCRIPT), *words]
    if home is not None:
        command += ["-HomeRoot", str(home)]
    return subprocess.run(command, check=False).returncode
