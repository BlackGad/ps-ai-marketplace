# Legion's own folders cannot be deleted by the running Python: its files are open on Windows.
# A detached system shell does it after Python exits. Neither shell follows a link: it removes the link only.

import os
import subprocess
import sys
from pathlib import Path
from typing import BinaryIO

from legion.core import _process

RETRIES = 30
UV_WAIT_SECONDS = 60


# POSIX: wait for the parent to exit, then rm. Windows: cmd pauses, then retries while the files stay locked.
# Each Windows path travels in its own environment variable, so the command text holds no path and cmd cannot expand one.
def delete_command(folders: list[Path]) -> tuple[str | list[str], dict[str, str]]:
    if sys.platform != "win32":
        script = 'while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; shift; rm -rf -- "$@"'
        return ["/bin/sh", "-c", script, "sh", str(os.getpid()), *map(str, folders)], {}
    system = Path(os.environ["SYSTEMROOT"]) / "System32"
    pause = f'"{system / "ping.exe"}" -n 2 127.0.0.1 >nul'
    names = {f"LEGION_DELETE_{number}": folder for number, folder in enumerate(folders, 1)}
    steps = " & ".join(f'{"rmdir /s /q" if folder.is_dir() else "del /f /q"} "%{name}%" 2>nul & (if exist "%{name}%" {pause})' for name, folder in names.items())
    command = f'"{system / "cmd.exe"}" /d /v:off /s /c "{pause} & for /l %i in (1,1,{RETRIES}) do @({steps})"'
    return command, {name: str(folder) for name, folder in names.items()}


# Read the helper before uv replaces or removes this environment. The base interpreter lives outside the uv tool.
def start_command(command: list[str], remove: list[Path], *, log: Path) -> None:
    code = Path(__file__).with_name("_uv_handover.py").read_text(encoding="utf-8")
    python = getattr(sys, "_base_executable", sys.executable)
    program = [python, "-I", "-c", code, _uv_parent_pids(), str(UV_WAIT_SECONDS), str(len(remove)), *map(str, remove), *command]
    log.parent.mkdir(parents=True, exist_ok=True)
    with log.open("wb") as stream:
        _detach(program, {}, output=stream)


def _uv_parent_pids() -> str:
    pid = os.getpid()
    if sys.platform == "win32":
        # uv's entry point waits for Python and can still have legion.exe open as Python exits.
        for parent in _process.ancestors(pid):
            name = parent.name.lower()
            if name == "legion.exe":
                return f"{pid},{parent.pid}"
            if not name.startswith("python"):
                break
    return str(pid)


def start(folders: list[Path]) -> None:
    if not folders:
        return
    command, variables = delete_command(folders)
    _detach(command, variables)


def _detach(command: str | list[str], variables: dict[str, str], *, output: int | BinaryIO = subprocess.DEVNULL) -> None:
    quiet = {"stdin": subprocess.DEVNULL, "stdout": output, "stderr": output, "env": {**os.environ, **variables}}
    if sys.platform == "win32":
        subprocess.Popen(command, creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW, **quiet)
    else:
        subprocess.Popen(command, start_new_session=True, **quiet)
