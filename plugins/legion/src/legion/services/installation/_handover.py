# Legion's own folders cannot be deleted by the running Python: its files are open on Windows.
# A detached system shell does it after Python exits. Neither shell follows a link: it removes the link only.

import os
import subprocess
import sys
from pathlib import Path

RETRIES = 30


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


# Runs one command after the parent exits, retrying while Windows files stay locked, then deletes the paths in `remove`.
# Each word and each path travels in its own environment variable, so the command text holds no path and no shell expands one.
def run_command_line(command: list[str], remove: list[Path]) -> tuple[str | list[str], dict[str, str]]:
    removed = {f"LEGION_REMOVE_{number}": path for number, path in enumerate(remove, 1)}
    if sys.platform != "win32":
        words = " ".join(f'"${name}"' for name in removed)
        cleanup = f"rm -rf -- {words}; " if removed else ""
        script = f'while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; shift; "$@"; status=$?; {cleanup}exit $status'
        return ["/bin/sh", "-c", script, "sh", str(os.getpid()), *command], {name: str(path) for name, path in removed.items()}
    system = Path(os.environ["SYSTEMROOT"]) / "System32"
    pause = f'"{system / "ping.exe"}" -n 2 127.0.0.1 >nul'
    names = {f"LEGION_RUN_{number}": word for number, word in enumerate(command, 1)}
    line = " ".join(f'"%{name}%"' for name in names)
    cleanup = "".join(f'{"rmdir /s /q" if path.is_dir() else "del /f /q"} "%{name}%" 2>nul & ' for name, path in removed.items())
    program = f'"{system / "cmd.exe"}" /d /v:off /s /c "{pause} & for /l %i in (1,1,{RETRIES}) do @({line} && ({cleanup}exit 0) || {pause})"'
    return program, {**names, **{name: str(path) for name, path in removed.items()}}


def start_command(command: list[str], remove: list[Path] | None = None) -> None:
    program, variables = run_command_line(command, remove or [])
    _detach(program, variables)


def start(folders: list[Path]) -> None:
    if not folders:
        return
    command, variables = delete_command(folders)
    _detach(command, variables)


def _detach(command: str | list[str], variables: dict[str, str]) -> None:
    quiet = {"stdin": subprocess.DEVNULL, "stdout": subprocess.DEVNULL, "stderr": subprocess.DEVNULL, "env": {**os.environ, **variables}}
    if sys.platform == "win32":
        subprocess.Popen(command, creationflags=subprocess.CREATE_NEW_PROCESS_GROUP | subprocess.CREATE_NO_WINDOW, **quiet)
    else:
        subprocess.Popen(command, start_new_session=True, **quiet)
