# Find a process's parent, name and start time with the standard library only.
# The session-start hook imports this module, so it must stay free of third-party packages.

import ctypes
import os
import re
import sys
import time
from collections.abc import Callable
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from typing import Optional

# Shells and launchers between an agent CLI and this process; matched without case and without ".exe".
SKIPPED_NAMES = frozenset({"pwsh", "powershell", "cmd", "sh", "bash", "zsh", "uv"})
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
    process = process_lookup()(pid)
    return process.started_at if process else None


# Return live parents, nearest first.
def ancestors(pid: int, lookup: Optional[Lookup] = None) -> list[ProcessInfo]:
    lookup = lookup or process_lookup()
    chain: list[ProcessInfo] = []
    child = lookup(pid)
    seen = {pid}
    while child and child.parent_pid not in seen:
        parent = lookup(child.parent_pid)
        # A parent pid can be reused: a process started after its child is not that child's parent.
        if not parent or parent.started_at > child.started_at:
            break
        chain.append(parent)
        seen.add(parent.pid)
        child = parent
    return chain


# Prefer the nearest non-shell ancestor; fall back to the oldest live shell.
def owner_process(pid: Optional[int] = None, lookup: Optional[Lookup] = None) -> ProcessInfo:
    chain = ancestors(os.getpid() if pid is None else pid, lookup)
    for process in chain:
        if not is_skipped(process.name):
            return process
    if chain:
        return chain[-1]
    raise LookupError("cannot find the agent session process; pass --process-id explicitly")


def is_skipped(name: str) -> bool:
    name = name.lower().removesuffix(".exe")
    return name in SKIPPED_NAMES or PYTHON_NAME.fullmatch(name) is not None


def process_lookup() -> Lookup:
    if sys.platform == "win32":
        return _windows_lookup()
    if sys.platform == "darwin":
        return _macos_process
    return _linux_lookup()


def _as_utc(value: datetime) -> datetime:
    # A lock file value without an offset was written as UTC.
    return value.replace(tzinfo=UTC) if value.tzinfo is None else value.astimezone(UTC)


# Fix boot time once so parents and children started in one clock tick keep their order.
def _linux_lookup() -> Lookup:
    assert sys.platform == "linux"
    # .NET takes boot time from CLOCK_BOOTTIME too; /proc/stat's btime is rounded to a whole second.
    boot = time.clock_gettime(time.CLOCK_REALTIME) - time.clock_gettime(time.CLOCK_BOOTTIME)
    ticks = os.sysconf("SC_CLK_TCK")
    return lambda pid: _linux_process(pid, boot, ticks)


def _linux_process(pid: int, boot: float, ticks: int) -> Optional[ProcessInfo]:
    try:
        with open(f"/proc/{pid}/stat", encoding="utf-8", errors="replace") as file:
            stat = file.read()
    except OSError:
        return None
    # The name sits in parentheses and may itself contain ")" or spaces.
    name = stat[stat.find("(") + 1 : stat.rfind(")")]
    fields = stat[stat.rfind(")") + 2 :].split()
    if fields[0] == "Z":
        return None
    # Field 22 counts clock ticks since boot.
    started = datetime.fromtimestamp(boot + int(fields[19]) / ticks, UTC)
    return ProcessInfo(pid, int(fields[1]), name, started)


class _BsdInfo(ctypes.Structure):
    # struct proc_bsdinfo from <sys/proc_info.h>.
    _fields_ = (
        ("pbi_flags", ctypes.c_uint32),
        ("pbi_status", ctypes.c_uint32),
        ("pbi_xstatus", ctypes.c_uint32),
        ("pbi_pid", ctypes.c_uint32),
        ("pbi_ppid", ctypes.c_uint32),
        ("pbi_uid", ctypes.c_uint32),
        ("pbi_gid", ctypes.c_uint32),
        ("pbi_ruid", ctypes.c_uint32),
        ("pbi_rgid", ctypes.c_uint32),
        ("pbi_svuid", ctypes.c_uint32),
        ("pbi_svgid", ctypes.c_uint32),
        ("rfu_1", ctypes.c_uint32),
        ("pbi_comm", ctypes.c_char * 16),
        ("pbi_name", ctypes.c_char * 32),
        ("pbi_nfiles", ctypes.c_uint32),
        ("pbi_pgid", ctypes.c_uint32),
        ("pbi_pjobc", ctypes.c_uint32),
        ("e_tdev", ctypes.c_uint32),
        ("e_tpgid", ctypes.c_uint32),
        ("pbi_nice", ctypes.c_int32),
        ("pbi_start_tvsec", ctypes.c_uint64),
        ("pbi_start_tvusec", ctypes.c_uint64),
    )


_PROC_PIDTBSDINFO = 3
_SZOMB = 5


def _macos_process(pid: int) -> Optional[ProcessInfo]:
    libproc = ctypes.CDLL("/usr/lib/libproc.dylib", use_errno=True)
    info = _BsdInfo()
    size = libproc.proc_pidinfo(pid, _PROC_PIDTBSDINFO, ctypes.c_uint64(0), ctypes.byref(info), ctypes.sizeof(info))
    if size != ctypes.sizeof(info) or info.pbi_status == _SZOMB:
        return None
    name = (info.pbi_name or info.pbi_comm).decode("utf-8", errors="replace")
    started = datetime.fromtimestamp(info.pbi_start_tvsec, UTC) + timedelta(microseconds=info.pbi_start_tvusec)
    return ProcessInfo(pid, info.pbi_ppid, name, started)


class _ProcessEntry(ctypes.Structure):
    # PROCESSENTRY32W from <tlhelp32.h>.
    _fields_ = (
        ("dwSize", ctypes.c_uint32),
        ("cntUsage", ctypes.c_uint32),
        ("th32ProcessID", ctypes.c_uint32),
        ("th32DefaultHeapID", ctypes.c_size_t),
        ("th32ModuleID", ctypes.c_uint32),
        ("cntThreads", ctypes.c_uint32),
        ("th32ParentProcessID", ctypes.c_uint32),
        ("pcPriClassBase", ctypes.c_int32),
        ("dwFlags", ctypes.c_uint32),
        ("szExeFile", ctypes.c_wchar * 260),
    )


_TH32CS_SNAPPROCESS = 0x2
_PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
_STILL_ACTIVE = 259
_FILETIME_EPOCH = datetime(1601, 1, 1, tzinfo=UTC)


# A handle that reads a process's times, exit code and command line, or 0; close it with CloseHandle.
def open_query_handle(pid: int) -> int:
    assert sys.platform == "win32"
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.restype = ctypes.c_void_p
    return kernel32.OpenProcess(_PROCESS_QUERY_LIMITED_INFORMATION, False, pid) or 0


# Snapshot parents and names once; read start times only for requested pids.
def _windows_lookup() -> Lookup:
    assert sys.platform == "win32"
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.CreateToolhelp32Snapshot.restype = ctypes.c_void_p
    kernel32.OpenProcess.restype = ctypes.c_void_p
    kernel32.Process32FirstW.argtypes = (ctypes.c_void_p, ctypes.c_void_p)
    kernel32.Process32NextW.argtypes = (ctypes.c_void_p, ctypes.c_void_p)
    kernel32.CloseHandle.argtypes = (ctypes.c_void_p,)
    kernel32.GetProcessTimes.argtypes = (ctypes.c_void_p, *(ctypes.c_void_p,) * 4)
    kernel32.GetExitCodeProcess.argtypes = (ctypes.c_void_p, ctypes.c_void_p)

    snapshot: dict[int, tuple[int, str]] = {}
    handle = kernel32.CreateToolhelp32Snapshot(_TH32CS_SNAPPROCESS, 0)
    if handle and handle != ctypes.c_void_p(-1).value:
        try:
            entry = _ProcessEntry()
            entry.dwSize = ctypes.sizeof(entry)
            found = kernel32.Process32FirstW(handle, ctypes.byref(entry))
            while found:
                snapshot[entry.th32ProcessID] = (entry.th32ParentProcessID, entry.szExeFile)
                found = kernel32.Process32NextW(handle, ctypes.byref(entry))
        finally:
            kernel32.CloseHandle(handle)

    def lookup(pid: int) -> Optional[ProcessInfo]:
        if pid not in snapshot:
            return None
        process = open_query_handle(pid)
        if not process:
            return None
        try:
            created, ignored, exit_code = ctypes.c_uint64(), ctypes.c_uint64(), ctypes.c_uint32()
            if not kernel32.GetExitCodeProcess(process, ctypes.byref(exit_code)) or exit_code.value != _STILL_ACTIVE:
                return None
            if not kernel32.GetProcessTimes(process, ctypes.byref(created), ctypes.byref(ignored), ctypes.byref(ignored), ctypes.byref(ignored)):
                return None
        finally:
            kernel32.CloseHandle(process)
        parent, name = snapshot[pid]
        # FILETIME counts 100-nanosecond steps since 1601, the same source as .NET's Process.StartTime.
        return ProcessInfo(pid, parent, name, _FILETIME_EPOCH + timedelta(microseconds=created.value // 10))

    return lookup
