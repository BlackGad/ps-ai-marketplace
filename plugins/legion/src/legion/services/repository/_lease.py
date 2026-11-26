# The overseer lease: one lock file per repository that names the session allowed to orchestrate.

import os
import socket
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Literal, Optional

from filelock import FileLock, Timeout

from legion.core._lease_record import (
    Lease,
    lease_path,
    round_trip,
    same_host,
)
from legion.core._process import owner_process, process_started_at, same_start_time

State = Literal["free", "held", "stale", "foreign"]
# A lock that is not a lease yet was most likely just created by a session that is still writing it.
WRITE_GRACE_SECONDS = 10
# On Windows another process may have the lock open for a moment; wait this long between the few tries.
RETRY_PAUSE_SECONDS = 0.025


class LeaseError(Exception):
    pass


@dataclass(frozen=True)
class LeaseState:
    state: State
    lease: Optional[Lease]


def state(repo: Path) -> LeaseState:
    path = lease_path(repo)
    try:
        lease = Lease.from_json(_read(path))
    except FileNotFoundError:
        return LeaseState("free", None)
    except OSError:
        return LeaseState("held", None)  # Unreadable is not stale: the owner may be alive behind a sharing or permission error.
    except (ValueError, TypeError):  # Not a lease, including bytes that are not UTF-8.
        if _age_seconds(path) < WRITE_GRACE_SECONDS:
            return LeaseState("held", None)
        return LeaseState("stale", None)
    if not lease.host or not lease.pid or lease.process_started_at is None:
        return LeaseState("stale", lease)
    if not same_host(lease.host):
        return LeaseState("foreign", lease)
    started = process_started_at(lease.pid)
    if started is not None and same_start_time(started, lease.process_started_at):
        return LeaseState("held", lease)
    return LeaseState("stale", lease)


# Take the owner's lock; replace only a stale lease. The guard is held from the check until the new lease is written.
def take(repo: Path, tool: str, account: str, process_id: Optional[int] = None) -> str:
    pid, started = _owner(process_id)
    if started is None:
        raise LeaseError("lease owner process is not running")
    path = lease_path(repo)
    path.parent.mkdir(parents=True, exist_ok=True)
    thread = os.environ.get("CODEX_THREAD_ID")
    lease = Lease(
        tool=tool,
        account=account,
        pid=pid,
        process_started_at=started,
        host=socket.gethostname(),
        started_at=round_trip(datetime.now(UTC)) + "+00:00",
        session=thread if tool == "codex" and thread else None,
    )
    guard = _open_guard(path)
    if guard is None:
        raise LeaseError("lease change in progress in another session; retry")
    try:
        current = state(repo)
        found = current.lease
        if current.state == "held" and found is not None and same_host(found.host) and found.pid == pid:
            return "skip: lease take (already done)"
        if current.state == "foreign" and found is not None:
            raise LeaseError(f"lease from host {found.host}; ask the owner")
        if current.state == "held" and found is None:
            raise LeaseError("lease is being written or cannot be read; retry, or check its permissions")
        if current.state == "held" and found is not None:
            raise LeaseError(f"lease held by {found.tool} {found.account} since {found.started_at}")
        if current.state == "stale" and not _remove(path):
            raise LeaseError("lease takeover in progress in another session; retry")
        try:
            with open(path, "x", encoding="utf-8", newline="") as file:
                file.write(lease.to_json())
        except (FileExistsError, PermissionError):
            raise LeaseError("lease unavailable; retry takeover") from None
        return "lease taken"
    finally:
        _close_guard(guard)


# Release only this owner's lock, checked by pid, host and start time.
def release(repo: Path, process_id: Optional[int] = None) -> str:
    path = lease_path(repo)
    if not path.exists():
        return "skip: lease release (already done)"
    pid, started = _owner(process_id)
    guard = _open_guard(path)
    if guard is None:
        raise LeaseError("lease change in progress in another session; retry")
    try:
        current = state(repo)
        if current.state == "free":
            return "skip: lease release (already done)"
        found = current.lease
        if found is not None and started is not None and found.process_started_at is not None and same_host(found.host) and found.pid == pid and same_start_time(found.process_started_at, started):
            if not _remove(path):
                raise LeaseError("lease change in progress in another session; retry")
            return "lease released"
        raise LeaseError("lease belongs to another session; cannot release it")
    finally:
        _close_guard(guard)


def _owner(process_id: Optional[int]) -> tuple[int, Optional[datetime]]:
    if process_id is not None:
        return process_id, process_started_at(process_id)
    try:
        owner = owner_process()
    except LookupError as error:
        raise LeaseError(str(error)) from error
    return owner.pid, owner.started_at


# One session at a time changes the lease. The OS lock is the guard, so a paused holder keeps it and the OS
# frees it when the holder exits. Returns the lock to pass to _close_guard, or None while another session holds it.
def _open_guard(path: Path) -> Optional[FileLock]:
    lock = FileLock(_guard_path(path), timeout=0)
    try:
        lock.acquire()
    except (Timeout, OSError):
        return None
    return lock


def _close_guard(guard: FileLock) -> None:
    guard.release()


def _guard_path(path: Path) -> Path:
    return path.with_name(path.name + ".takeover")


def _read(path: Path) -> str:
    # A PowerShell writer opens the lock without sharing, so a read on Windows can fail for a moment.
    for attempt in range(5):
        try:
            return path.read_text(encoding="utf-8-sig")
        except PermissionError:
            if attempt == 4:
                raise
            time.sleep(RETRY_PAUSE_SECONDS)
    raise AssertionError("unreachable")


# Windows cannot remove a lock another session is reading; give up after a few tries so the caller can say retry.
def _remove(path: Path) -> bool:
    for attempt in range(5):
        try:
            path.unlink(missing_ok=True)
            return True
        except PermissionError:
            if attempt < 4:
                time.sleep(RETRY_PAUSE_SECONDS)
    return False


def _age_seconds(path: Path) -> float:
    try:
        return time.time() - path.stat().st_mtime
    except OSError:
        return float("inf")
