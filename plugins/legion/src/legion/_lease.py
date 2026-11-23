# The overseer lease: one lock file per repository that names the session allowed to orchestrate.
# The lock is shared with PowerShell's Get-LegionLease, so field names and time formats stay the same.
# The session-start hook will read it, so this module stays free of third-party packages.

import json
import os
import socket
import sys
import time
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Any, Literal, Optional

from ._process import owner_process, process_started_at, same_start_time

if sys.platform == "win32":
    import msvcrt
else:
    import fcntl

State = Literal["free", "held", "stale", "foreign"]
# A lock that cannot be read yet was most likely just created by a session that is still writing it.
WRITE_GRACE_SECONDS = 10


class LeaseError(Exception):
    pass


@dataclass(frozen=True)
class Lease:
    tool: str = ""
    account: str = ""
    pid: int = 0
    process_started_at: Optional[datetime] = None
    host: str = ""
    started_at: str = ""
    session: Optional[str] = None

    # Reject records that are not leases with ValueError or TypeError.
    @classmethod
    def from_json(cls, text: str) -> "Lease":
        data = json.loads(text)
        if not isinstance(data, dict):
            raise TypeError("lease is not a JSON object")
        pid = data.get("pid") or 0
        if not isinstance(pid, int) or isinstance(pid, bool):
            raise TypeError("lease pid is not a number")
        started = _text(data, "processStartedAt")
        session = data.get("session")
        return cls(
            tool=_text(data, "tool"),
            account=_text(data, "account"),
            pid=pid,
            process_started_at=datetime.fromisoformat(started) if started else None,
            host=_text(data, "host"),
            started_at=_text(data, "startedAt"),
            session=_text(data, "session") if session else None,
        )

    def to_json(self) -> str:
        assert self.process_started_at is not None
        data = {
            "tool": self.tool,
            "account": self.account,
            "pid": self.pid,
            "processStartedAt": round_trip(self.process_started_at) + "Z",
            "host": self.host,
            "startedAt": self.started_at,
        }
        if self.session:
            data["session"] = self.session
        return json.dumps(data, separators=(",", ":")) + "\n"


@dataclass(frozen=True)
class LeaseState:
    state: State
    lease: Optional[Lease]


def lease_path(repo: Path) -> Path:
    return Path(repo) / ".legion" / "temp" / "overseer.lock"


# Match .NET's round-trip "o" format in UTC, without the zone suffix.
def round_trip(value: datetime) -> str:
    return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.%f") + "0"


def state(repo: Path) -> LeaseState:
    path = lease_path(repo)
    if not path.exists():
        return LeaseState("free", None)
    try:
        lease = Lease.from_json(_read(path))
    except (OSError, ValueError, TypeError):
        if _age_seconds(path) < WRITE_GRACE_SECONDS:
            return LeaseState("held", None)
        return LeaseState("stale", None)
    if not lease.host or not lease.pid or lease.process_started_at is None:
        return LeaseState("stale", lease)
    if not _same_host(lease.host):
        return LeaseState("foreign", lease)
    started = process_started_at(lease.pid)
    if started is not None and same_start_time(started, lease.process_started_at):
        return LeaseState("held", lease)
    return LeaseState("stale", lease)


# Take the owner's lock; replace only stale or unreadable leases.
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
    for attempt in range(2):
        try:
            with open(path, "x", encoding="utf-8", newline="") as file:
                file.write(lease.to_json())
            return "lease taken"
        except (FileExistsError, PermissionError):
            current = state(repo)
        found = current.lease
        if current.state == "held" and found is not None and _same_host(found.host) and found.pid == pid:
            return "skip: lease take (already done)"
        if current.state == "foreign" and found is not None:
            raise LeaseError(f"lease from host {found.host}; ask the owner")
        if current.state == "held" and found is None:
            raise LeaseError("lease is being taken by another session; retry")
        if current.state == "held" and found is not None:
            raise LeaseError(f"lease held by {found.tool} {found.account} since {found.started_at}")
        if attempt == 0 and current.state == "stale":
            if not _remove_stale(repo, found):
                raise LeaseError("lease takeover in progress in another session; retry")
            continue
        break
    raise LeaseError("lease unavailable; retry takeover")


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
        if found is not None and started is not None and found.process_started_at is not None and _same_host(found.host) and found.pid == pid and same_start_time(found.process_started_at, started):
            path.unlink()
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


# Replace only the stale lease we saw, with one session acting at a time.
def _remove_stale(repo: Path, seen: Optional[Lease]) -> bool:
    path = lease_path(repo)
    guard = _open_guard(path)
    if guard is None:
        return False
    try:
        current = state(repo)
        if current.state != "stale":
            return True
        found = current.lease
        unchanged = (seen is None and found is None) or (seen is not None and found is not None and seen.pid == found.pid and seen.started_at == found.started_at)
        if unchanged:
            path.unlink(missing_ok=True)
        return True
    finally:
        _close_guard(guard)


# One session at a time changes the lease. The guard file stays; its OS lock is the guard, so a paused
# holder keeps it and the OS frees it when the holder exits. Returns the descriptor to pass to _close_guard,
# or None while another session holds it.
def _open_guard(path: Path) -> Optional[int]:
    try:
        guard = os.open(_guard_path(path), os.O_RDWR | os.O_CREAT)
    except OSError:
        return None
    try:
        if sys.platform == "win32":
            msvcrt.locking(guard, msvcrt.LK_NBLCK, 1)
        else:
            fcntl.flock(guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        os.close(guard)
        return None
    return guard


def _close_guard(guard: int) -> None:
    if sys.platform == "win32":
        os.lseek(guard, 0, os.SEEK_SET)
        msvcrt.locking(guard, msvcrt.LK_UNLCK, 1)
    os.close(guard)


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
            time.sleep(0.025)
    raise AssertionError("unreachable")


def _age_seconds(path: Path) -> float:
    try:
        return time.time() - path.stat().st_mtime
    except OSError:
        return float("inf")


def _same_host(host: str) -> bool:
    return host.lower() == socket.gethostname().lower()


def _text(data: dict[str, Any], key: str) -> str:
    value = data.get(key)
    if value is None:
        return ""
    if not isinstance(value, str):
        raise TypeError(f"lease {key} is not text")
    return value
