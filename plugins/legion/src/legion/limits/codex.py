# Codex prints no limits; its session file in the account folder holds the last rate_limits it saw.

import json
import os
import re
from pathlib import Path
from typing import Any, Optional

from ._ping import (
    LimitRow,
    Ping,
    format_reset_time,
    format_used_percent,
    ping,
    ping_failure,
)

ARGUMENTS = ["exec", "ping"]
RETRY = re.compile(r"try again at (.+?)\.?\s*$", re.IGNORECASE)


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
    limits = _session_limits(folder / "sessions", result.folder) or {}
    found = []
    for name in ("primary", "secondary"):
        window = limits.get(name)
        if window is None:
            continue
        used = format_used_percent(window["used_percent"]) if window.get("used_percent") is not None else "unknown"
        resets = format_reset_time(window["resets_at"]) if window.get("resets_at") else "unknown"
        found.append(LimitRow(window=window_name(window.get("window_minutes"), name), used=used, resets=resets))
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
def _session_limits(sessions: Path, ping_folder: Path) -> Optional[dict[str, Any]]:
    for file in sorted(sessions.rglob("*.jsonl")):
        if not file.is_file():
            continue
        with file.open(encoding="utf-8") as lines:
            if not _is_session_of(lines.readline(), ping_folder):
                continue
            limits = None
            for line in lines:
                if '"rate_limits"' not in line:
                    continue
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(record, dict):
                    continue
                found = (record.get("payload") or {}).get("rate_limits") or record.get("rate_limits")
                if found:
                    limits = found
            return limits
    return None


def _is_session_of(first_line: str, ping_folder: Path) -> bool:
    try:
        metadata = json.loads(first_line)
    except ValueError:
        return False
    if not isinstance(metadata, dict):
        return False
    cwd = (metadata.get("payload") or {}).get("cwd") if metadata.get("type") == "session_meta" else None
    return bool(cwd) and os.path.normcase(Path(cwd).resolve()) == os.path.normcase(ping_folder)
