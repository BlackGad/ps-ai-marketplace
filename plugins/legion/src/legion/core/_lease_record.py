# Lease file format shared by the hook and the takeover service.

import json
import socket
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Optional


class LeaseUnreadableError(ValueError):
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

    # Hand-built, reason: the lease record is also read by the standard-library-only hook.
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


def lease_path(repo: Path) -> Path:
    return Path(repo) / ".legion" / "temp" / "overseer.lock"


# Match .NET's round-trip "o" format in UTC, without the zone suffix.
def round_trip(value: datetime) -> str:
    return value.astimezone(UTC).strftime("%Y-%m-%dT%H:%M:%S.%f") + "0"


def read_lease(repo: Path) -> Optional[Lease]:
    try:
        lease = Lease.from_json(lease_path(repo).read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        return None
    except (OSError, ValueError, TypeError) as error:
        raise LeaseUnreadableError from error
    if not lease.host:
        raise LeaseUnreadableError("lease has no host")
    return lease


def same_host(host: str) -> bool:
    return host.lower() == socket.gethostname().lower()


def _text(data: dict[str, object], key: str) -> str:
    value = data.get(key)
    if value is None:
        return ""
    if not isinstance(value, str):
        raise TypeError(f"lease {key} is not text")
    return value
