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
WINDOWS = sys.platform == "win32"
STOP_SECONDS = 3.0
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
def owner_process(pid: Optional[int] = None, lookup: Optional[Lookup] = None) -> ProcessInfo:
    chain = ancestors(os.getpid() if pid is None else pid, lookup)
    owner = next((process for process in chain if not is_skipped(process.name)), None)
    if owner is None:
        raise LookupError("cannot find the agent session process; pass --process-id explicitly")
    return owner


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


# Go on past a process that cannot be stopped, then report the first such failure.
def end_tree(child: psutil.Process) -> None:
    if not child.is_running():
        return
    failures: list[psutil.Error] = []

    def stop(processes: list[psutil.Process], action: str) -> None:
        for process in processes:
            try:
                getattr(process, action)()
            except psutil.NoSuchProcess:
                continue
            except psutil.Error as error:
                failures.append(error)

    try:
        tree = [*child.children(recursive=True), child]
    except psutil.NoSuchProcess:
        return
    stop(tree, "terminate")
    _, alive = psutil.wait_procs(tree, timeout=STOP_SECONDS)
    stop(alive, "kill")
    psutil.wait_procs(alive, timeout=STOP_SECONDS)
    if failures:
        raise failures[0]


def _as_utc(value: datetime) -> datetime:
    # A lock file value without an offset was written as UTC.
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)
