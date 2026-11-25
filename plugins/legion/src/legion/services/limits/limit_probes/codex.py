# Codex prints no limits; its session file in the account folder holds the last rate_limits it saw.

import os
import re
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, ValidationError

from legion.services.limits.limit_probes._ping import LimitRow, Ping, format_reset_time, format_used_percent, ping, ping_failure

ARGUMENTS = ["exec", "ping"]
RETRY = re.compile(r"try again at (.+?)\.?\s*$", re.IGNORECASE)


class Window(BaseModel):
    used_percent: Optional[float] = None
    window_minutes: Optional[int] = None
    resets_at: Optional[float] = None


class RateLimits(BaseModel):
    primary: Optional[Window] = None
    secondary: Optional[Window] = None


class RateLimitsPayload(BaseModel):
    rate_limits: Optional[RateLimits] = None


# Newer sessions put rate_limits in the payload, older ones at the top.
class RateLimitsRecord(BaseModel):
    payload: Optional[RateLimitsPayload] = None
    rate_limits: Optional[RateLimits] = None


class SessionPayload(BaseModel):
    cwd: Optional[str] = None


class SessionMeta(BaseModel):
    type: Optional[str] = None
    payload: Optional[SessionPayload] = None


# Codex needs a git folder to run.
def read(command: str, folder: Path, timeout: float) -> list[LimitRow]:
    return rows(ping(command, ARGUMENTS, timeout, git=True), folder)


def rows(result: Ping, folder: Path) -> list[LimitRow]:
    if result.timed_out:
        return [LimitRow(status="ping timed out")]
    # A quota error names the time to try again.
    text = result.error + "\n" + result.output
    quota = next((line for line in text.splitlines() if re.search("hit your usage limit", line, re.IGNORECASE)), None)
    if quota is not None:
        retry = RETRY.search(quota)
        return [LimitRow(resets=retry.group(1) if retry else "unknown", status="limit reached")]
    if result.exit_code != 0:
        return [LimitRow(status=ping_failure(result, "usage limit"))]
    limits = _session_limits(folder / "sessions", result.folder) or RateLimits()
    found = []
    for name, window in (("primary", limits.primary), ("secondary", limits.secondary)):
        if window is None:
            continue
        used = format_used_percent(window.used_percent) if window.used_percent is not None else "unknown"
        resets = format_reset_time(window.resets_at) if window.resets_at else "unknown"
        found.append(LimitRow(window=window_name(window.window_minutes, name), used=used, resets=resets))
    return found or [LimitRow(status="no limit readout")]


# The window name from its length in minutes: 300 is 5h, 10080 is 7d.
def window_name(minutes: Optional[int], fallback: str) -> str:
    if not minutes:
        return fallback
    if minutes % 1440 == 0:
        return f"{minutes // 1440}d"
    if minutes % 60 == 0:
        return f"{minutes // 60}h"
    return f"{minutes}m"


# Only the ping's disposable working folder can identify its session; timestamps cannot.
# A record of another shape is skipped like unreadable JSON, and a file that cannot be read or decoded like a foreign one.
def _session_limits(sessions: Path, ping_folder: Path) -> Optional[RateLimits]:
    for file in sorted(sessions.rglob("*.jsonl")):
        try:
            if not file.is_file():
                continue
            with file.open(encoding="utf-8") as lines:
                if not _is_session_of(lines.readline(), ping_folder):
                    continue
                limits = None
                for line in lines:
                    found = _rate_limits(line) if '"rate_limits"' in line else None
                    if found:
                        limits = found
        except (OSError, UnicodeDecodeError):
            continue
        return limits
    return None


def _rate_limits(line: str) -> Optional[RateLimits]:
    try:
        record = RateLimitsRecord.model_validate_json(line)
    except ValidationError:
        return None
    return (record.payload and record.payload.rate_limits) or record.rate_limits


def _is_session_of(first_line: str, ping_folder: Path) -> bool:
    try:
        metadata = SessionMeta.model_validate_json(first_line)
    except ValidationError:
        return False
    cwd = metadata.payload.cwd if metadata.type == "session_meta" and metadata.payload else None
    return bool(cwd) and os.path.normcase(Path(cwd).resolve()) == os.path.normcase(ping_folder)
