# Run a command with stdin closed, capture both streams and kill the whole tree on timeout.

import contextlib
import ctypes
import os
import re
import signal
import subprocess
import sys
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Optional, Union

from pydantic import BaseModel, ConfigDict

# After a timeout kill, how long to wait for the pipes to close; a process that left the tree can hold them.
DRAIN_SECONDS = 5


class RunResult(BaseModel):
    model_config = ConfigDict(frozen=True)

    exit_code: int
    output: str
    error: str
    timed_out: bool


# Return exit code -1 and timed_out when the timeout kills the process tree.
# A .cmd or .bat runs through cmd.exe with every character kept literal; a line break cannot pass and raises ValueError.
def run_command(command: str, arguments: Sequence[str], timeout: Optional[float] = None, env: Optional[Mapping[str, str]] = None, cwd: Optional[Path] = None) -> RunResult:
    on_windows = sys.platform == "win32"
    line: Union[str, list[str]] = [command, *arguments]
    if on_windows and Path(command).suffix.lower() in {".cmd", ".bat"}:
        line = _cmd_line([command, *arguments])
    process = subprocess.Popen(
        line,
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=env,
        cwd=cwd,
        start_new_session=not on_windows,
        # Suspended until it is in the job, so no process it starts can escape the timeout.
        creationflags=subprocess.CREATE_NO_WINDOW | _CREATE_SUSPENDED if sys.platform == "win32" else 0,
    )
    job = None
    if on_windows:
        try:
            job = _windows_job(process.pid)
        except OSError:
            process.kill()
            process.communicate()
            raise
    try:
        try:
            output, error = process.communicate(timeout=timeout)
            timed_out = False
        except subprocess.TimeoutExpired:
            _kill_tree(process, job)
            try:
                output, error = process.communicate(timeout=DRAIN_SECONDS)
            except subprocess.TimeoutExpired:
                # A descendant can still hold the pipes after the first stop; try the tree again.
                _kill_tree(process, job)
                try:
                    output, error = process.communicate(timeout=DRAIN_SECONDS)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    output, error = b"", b""
            timed_out = True
    finally:
        if job:
            _close_job(job)
    return RunResult(exit_code=-1 if timed_out else process.returncode, output=_text(output), error=_text(error), timed_out=timed_out)


# cmd.exe reads the whole line: quotes keep & | < > ^ literal, /v:off keeps !, and %cd:~,% (an empty
# slice of a variable that always exists) stops %NAME% expansion. Backslashes before a quote are doubled for the C runtime.
def _cmd_line(parts: Sequence[str]) -> str:
    quoted = []
    for part in parts:
        if "\n" in part or "\r" in part:
            raise ValueError("cmd.exe cannot pass a line break in an argument")
        doubled = re.sub(r'(\\+)(?="|\Z)', r"\1\1", part)
        quoted.append('"' + doubled.replace('"', '""').replace("%", "%%cd:~,%") + '"')
    return f'"{os.environ.get("COMSPEC", "cmd.exe")}" /d /v:off /s /c "{" ".join(quoted)}"'


def _text(data: bytes) -> str:
    # Children (legion, uv, agent CLIs) write UTF-8; the console code page would garble it.
    return data.decode("utf-8", errors="replace")


def _kill_tree(process: subprocess.Popen[bytes], job: Optional[int]) -> None:
    if sys.platform == "win32":
        if not job or not ctypes.WinDLL("kernel32").TerminateJobObject(ctypes.c_void_p(job), 1):
            process.kill()
        return
    # The child leads its own session, so its process group holds every descendant that did not leave it.
    with contextlib.suppress(ProcessLookupError):
        os.killpg(process.pid, signal.SIGKILL)


_CREATE_SUSPENDED = 0x00000004
_PROCESS_SET_QUOTA = 0x0100
_PROCESS_TERMINATE = 0x0001
_PROCESS_SUSPEND_RESUME = 0x0800


# Put the suspended process in a job, so a timeout can end its children after their parent exits, then let it run.
def _windows_job(pid: int) -> int:
    assert sys.platform == "win32"
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateJobObjectW.restype = ctypes.c_void_p
    kernel32.OpenProcess.restype = ctypes.c_void_p
    kernel32.CloseHandle.argtypes = (ctypes.c_void_p,)
    ntdll = ctypes.WinDLL("ntdll")
    ntdll.NtResumeProcess.argtypes = (ctypes.c_void_p,)
    job = kernel32.CreateJobObjectW(None, None)
    if not job:
        raise OSError("could not create a job for the process")
    process = kernel32.OpenProcess(_PROCESS_SET_QUOTA | _PROCESS_TERMINATE | _PROCESS_SUSPEND_RESUME, False, pid)
    try:
        if not process or not _assign_to_job(job, process):
            _close_job(job)
            raise OSError("could not put the process in a job")
        if ntdll.NtResumeProcess(process) != 0:
            _close_job(job)
            raise OSError("could not start the process in its job")
    finally:
        if process:
            kernel32.CloseHandle(process)
    return job


def _assign_to_job(job: int, process: int) -> bool:
    assert sys.platform == "win32"
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.AssignProcessToJobObject.argtypes = (ctypes.c_void_p, ctypes.c_void_p)
    return bool(kernel32.AssignProcessToJobObject(job, process))


def _close_job(job: int) -> None:
    assert sys.platform == "win32"
    ctypes.WinDLL("kernel32").CloseHandle(ctypes.c_void_p(job))
