# Legion's own folders cannot be deleted by the running Python: its files are open on Windows.
# A detached system shell does it after Python exits. Neither shell follows a link: it removes the link only.

import subprocess
import sys
from pathlib import Path

RETRIES = 30


# cmd retries for a while, because the files are free only once legion has ended.
def delete_command(folders: list[Path]) -> str | list[str]:
    if sys.platform == "win32":
        steps = " & ".join(f'rmdir /s /q "{folder}" 2>nul & (if exist "{folder}" ping -n 2 127.0.0.1 >nul)' for folder in folders)
        return f'cmd /d /s /c "for /l %i in (1,1,{RETRIES}) do @({steps})"'
    return ["sh", "-c", 'sleep 1; rm -rf -- "$@"', "sh", *map(str, folders)]


def start(folders: list[Path]) -> None:
    if not folders:
        return
    if sys.platform == "win32":
        flags = subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW
        subprocess.Popen(delete_command(folders), creationflags=flags, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        subprocess.Popen(delete_command(folders), start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
