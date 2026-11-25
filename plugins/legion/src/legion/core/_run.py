# Run a command with stdin closed, capture both streams and kill the whole tree on timeout.

import contextlib
import ctypes
import os
import re
import signal
import subprocess
import sys
import threading
import time
from contextlib import contextmanager
from contextvars import ContextVar
from collections.abc import Iterator
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Optional, Union

from pydantic import BaseModel, ConfigDict
import psutil

# After a timeout kill, how long to wait for the pipes to close; a process that left the tree can hold them.
DRAIN_SECONDS = 5
_cancellation: ContextVar[Optional[threading.Event]] = ContextVar("command_cancellation", default=None)
_deadline: ContextVar[Optional[float]] = ContextVar("command_deadline", default=None)


# Cancellation must bypass account_rows' ordinary error-to-row conversion.
class CommandCancelled(BaseException):
    pass


class CommandDeadlineError(Exception):
    pass


@contextmanager
def command_cancellation(event: threading.Event, *, deadline: Optional[float] = None) -> Iterator[None]:
    token = _cancellation.set(event)
    deadline_token = _deadline.set(deadline)
    try:
        yield
    finally:
        _cancellation.reset(token)
        _deadline.reset(deadline_token)


def check_command_context() -> None:
    cancelled = _cancellation.get()
    if cancelled is not None and cancelled.is_set():
        raise CommandCancelled
    deadline = _deadline.get()
    if deadline is not None and time.monotonic() >= deadline:
        raise CommandDeadlineError("MCP call deadline exceeded")


class RunResult(BaseModel):
    model_config = ConfigDict(frozen=True)

    exit_code: int
    output: str
    error: str
    timed_out: bool


# Return exit code -1 and timed_out when the timeout kills the process tree.
# A .cmd or .bat runs through cmd.exe with every character kept literal; a line break cannot pass and raises ValueError.
def run_command(command: str, arguments: Sequence[str], timeout: Optional[float] = None, env: Optional[Mapping[str, str]] = None, cwd: Optional[Path] = None) -> RunResult:
    cancelled = _cancellation.get()
    check_command_context()
    deadline = _deadline.get()
    if deadline is not None:
        remaining = max(0.0, deadline - time.monotonic())
        timeout = min(timeout, remaining) if timeout is not None else remaining
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
    owned: dict[int, psutil.Process] = {}
    if not on_windows:
        with contextlib.suppress(psutil.NoSuchProcess):
            owned[process.pid] = psutil.Process(process.pid)
    if on_windows:
        try:
            job = _windows_job(process.pid)
        except OSError:
            process.kill()
            process.communicate()
            raise
    try:
        try:
            output, error = _communicate(process, timeout, cancelled, owned)
            timed_out = False
        except subprocess.TimeoutExpired:
            _kill_tree(process, job, owned)
            try:
                output, error = process.communicate(timeout=DRAIN_SECONDS)
            except subprocess.TimeoutExpired:
                # A descendant can still hold the pipes after the first stop; try the tree again.
                _kill_tree(process, job, owned)
                try:
                    output, error = process.communicate(timeout=DRAIN_SECONDS)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
                    output, error = b"", b""
            timed_out = True
        except CommandCancelled:
            _kill_tree(process, job, owned)
            try:
                process.communicate(timeout=DRAIN_SECONDS)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise
    finally:
        if job:
            _close_job(job)
    return RunResult(exit_code=-1 if timed_out else process.returncode, output=_text(output), error=_text(error), timed_out=timed_out)


def _communicate(process: subprocess.Popen[bytes], timeout: Optional[float], cancelled: Optional[threading.Event], owned: dict[int, psutil.Process]) -> tuple[bytes, bytes]:
    if cancelled is None and not owned:
        return process.communicate(timeout=timeout)
    deadline = time.monotonic() + timeout if timeout is not None else None
    while True:
        _track_descendants(owned)
        if cancelled is not None and cancelled.is_set():
            raise CommandCancelled
        remaining = max(0.0, deadline - time.monotonic()) if deadline is not None else 0.1
        try:
            return process.communicate(timeout=min(0.1, remaining))
        except subprocess.TimeoutExpired:
            if deadline is not None and time.monotonic() >= deadline:
                raise


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


def _track_descendants(owned: dict[int, psutil.Process]) -> None:
    # Keep Process objects: psutil checks identity before signalling, avoiding PID reuse.
    # Retain children even after they change sessions or their parent exits.
    for parent in list(owned.values()):
        with contextlib.suppress(psutil.NoSuchProcess):
            for child in parent.children(recursive=True):
                owned.setdefault(child.pid, child)


def _kill_tree(process: subprocess.Popen[bytes], job: Optional[int], owned: dict[int, psutil.Process]) -> None:
    if sys.platform == "win32":
        if not job or not ctypes.WinDLL("kernel32").TerminateJobObject(ctypes.c_void_p(job), 1):
            process.kill()
        return
    _track_descendants(owned)
    for child in reversed(list(owned.values())):
        with contextlib.suppress(psutil.NoSuchProcess):
            child.kill()
    # Also cover short-lived parents whose children still belong to the original group.
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
