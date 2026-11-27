# Find a process's parent, name and start time.

import os
import re
import sys
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Optional

import psutil

# Shells and launchers between an agent CLI and this process; matched without case and without ".exe".
SKIPPED_NAMES = frozenset({"pwsh", "powershell", "cmd", "sh", "bash", "zsh", "uv", "legion"})
# Set by the Git Bash shim: the Windows pids of its parent shell and of itself, since the process chain loses the shell.
SHELL_WINPID_VARIABLE = "LEGION_SHELL_WINPID"
SHIM_WINPID_VARIABLE = "LEGION_SHIM_WINPID"
WINDOWS = sys.platform == "win32"
PYTHON_NAME = re.compile(r"python[0-9.]*")
# Linux and macOS derive a start time from the clock, so two reads can differ by a few milliseconds.
SAME_START_TOLERANCE = timedelta(milliseconds=500)


@dataclass(frozen=True)
class ProcessInfo:
    pid: int
    parent_pid: int
    name: str
    started_at: datetime


Lookup = Callable[[int], Optional[ProcessInfo]]


def same_start_time(first: datetime, second: datetime) -> bool:
    return abs(_as_utc(first) - _as_utc(second)) < SAME_START_TOLERANCE


def process_started_at(pid: int) -> Optional[datetime]:
    process = process_info(pid)
    return process.started_at if process else None


# Return live parents, nearest first.
def ancestors(pid: int, lookup: Optional[Lookup] = None) -> list[ProcessInfo]:
    lookup = lookup or process_info
    chain: list[ProcessInfo] = []
    child = lookup(pid)
    seen = {pid}
    while child and child.parent_pid not in seen:
        parent = lookup(child.parent_pid)
        # Hand-built, reason: Windows start times are exact, but Linux and macOS clock rounding can make a same-tick parent appear slightly younger.
        # A parent younger than its child has a reused pid.
        if not parent or (parent.started_at > child.started_at and (WINDOWS or not same_start_time(parent.started_at, child.started_at))):
            break
        chain.append(parent)
        seen.add(parent.pid)
        child = parent
    return chain


# The nearest ancestor that is not a shell or launcher; a chain of only shells is refused, since a shell may be short-lived.
# Git Bash on Windows cuts the chain at the shim's sh.exe, so the shim hands over its own and its parent shell's Windows pids.
def owner_process(pid: Optional[int] = None, lookup: Optional[Lookup] = None) -> ProcessInfo:
    lookup = lookup or process_info
    chain = ancestors(os.getpid() if pid is None else pid, lookup)
    owner = _first_session(chain)
    if owner is None and chain:
        owner = _session_behind_shim(chain[-1], lookup)
    if owner is None:
        raise LookupError("cannot find the agent session process; pass --process-id explicitly")
    return owner


def _first_session(processes: list[ProcessInfo]) -> Optional[ProcessInfo]:
    return next((process for process in processes if not is_skipped(process.name)), None)


# Trust the hint only when the shim that wrote it is the cut end of this chain; no start-time tolerance on this Windows-only path.
def _session_behind_shim(cut_end: ProcessInfo, lookup: Lookup) -> Optional[ProcessInfo]:
    shim_pid = os.environ.get(SHIM_WINPID_VARIABLE, "")
    shell_pid = os.environ.get(SHELL_WINPID_VARIABLE, "")
    if not (shim_pid.isdecimal() and shell_pid.isdecimal()) or int(shim_pid) != cut_end.pid:
        return None
    shell = lookup(int(shell_pid))
    if not shell or shell.started_at >= cut_end.started_at:
        return None
    return _first_session([shell, *ancestors(shell.pid, lookup)])


def is_skipped(name: str) -> bool:
    name = name.lower().removesuffix(".exe")
    return name in SKIPPED_NAMES or PYTHON_NAME.fullmatch(name) is not None


def process_info(pid: int) -> Optional[ProcessInfo]:
    try:
        if pid <= 0 or not psutil.pid_exists(pid):
            return None
        process = psutil.Process(pid)
        if process.status() == psutil.STATUS_ZOMBIE:
            return None
        started = datetime.fromtimestamp(process.create_time(), UTC)
        name = process.name()
        try:
            parent_pid = process.ppid()
        except psutil.AccessDenied:
            parent_pid = 0
        if process.is_running():
            return ProcessInfo(pid, parent_pid, name, started)
    except (psutil.Error, OverflowError):
        pass
    return None


def _as_utc(value: datetime) -> datetime:
    # A lock file value without an offset was written as UTC.
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
