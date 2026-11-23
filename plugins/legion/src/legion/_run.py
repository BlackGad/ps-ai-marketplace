# Run a command with stdin closed, capture both streams and kill the whole tree on timeout.

import contextlib
import ctypes
import os
import signal
import subprocess
import sys
from collections.abc import Mapping, Sequence
from dataclasses import dataclass
from pathlib import Path
from typing import Optional


@dataclass(frozen=True)
class RunResult:
    exit_code: int
    output: str
    error: str
    timed_out: bool


# Return exit code -1 and timed_out when the timeout kills the process tree.
def run_command(command: str, arguments: Sequence[str], timeout: Optional[float] = None, env: Optional[Mapping[str, str]] = None, cwd: Optional[Path] = None) -> RunResult:
    on_windows = sys.platform == "win32"
    line: str | list[str] = [command, *arguments]
    if on_windows and Path(command).suffix.lower() in {".cmd", ".bat"}:
        # Quote like bin/lib/process.ps1 so cmd.exe keeps spaces and special characters inside arguments.
        quoted = " ".join('"' + part.replace('"', '""') + '"' for part in [command, *arguments])
        line = f'"{os.environ.get("COMSPEC", "cmd.exe")}" /d /s /c "{quoted}"'
    process = subprocess.Popen(
        line,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        cwd=cwd,
        start_new_session=not on_windows,
        creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
    )
    job = _windows_job(process.pid) if on_windows else None
    try:
        try:
            output, error = process.communicate(timeout=timeout)
            timed_out = False
        except subprocess.TimeoutExpired:
            _kill_tree(process, job)
            output, error = process.communicate()
            timed_out = True
    finally:
        if job:
            _close_job(job)
    return RunResult(-1 if timed_out else process.returncode, _text(output), _text(error), timed_out)


def _text(data: bytes) -> str:
    # Children (legion, uv, agent CLIs) write UTF-8; the console code page would garble it.
    return data.decode("utf-8", errors="replace")


def _kill_tree(process: subprocess.Popen[bytes], job: Optional[int]) -> None:
    if sys.platform == "win32":
        if job:
            ctypes.WinDLL("kernel32").TerminateJobObject(ctypes.c_void_p(job), 1)
        else:
            process.kill()
        return
    # The child leads its own session, so its process group holds every descendant that did not leave it.
    with contextlib.suppress(ProcessLookupError):
        os.killpg(process.pid, signal.SIGKILL)


_PROCESS_SET_QUOTA = 0x0100
_PROCESS_TERMINATE = 0x0001


# Put the process in a job so a timeout can end its children after their parent exits.
def _windows_job(pid: int) -> Optional[int]:
    assert sys.platform == "win32"
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateJobObjectW.restype = ctypes.c_void_p
    kernel32.OpenProcess.restype = ctypes.c_void_p
    kernel32.AssignProcessToJobObject.argtypes = (ctypes.c_void_p, ctypes.c_void_p)
    kernel32.CloseHandle.argtypes = (ctypes.c_void_p,)
    job = kernel32.CreateJobObjectW(None, None)
    if not job:
        return None
    # The child runs for a moment before it joins the job; a process it starts in that moment stays outside.
    process = kernel32.OpenProcess(_PROCESS_SET_QUOTA | _PROCESS_TERMINATE, False, pid)
    if process:
        kernel32.AssignProcessToJobObject(job, process)
        kernel32.CloseHandle(process)
    return job


def _close_job(job: int) -> None:
    assert sys.platform == "win32"
    ctypes.WinDLL("kernel32").CloseHandle(ctypes.c_void_p(job))
