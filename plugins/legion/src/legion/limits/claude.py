# Claude Code prints a rate_limit_event in its stream; each unified window has a utilization (0 to 1) and a reset time.

import json
from pathlib import Path
from typing import Any

from ._ping import (
    LimitRow,
    Ping,
    format_reset_time,
    format_used_percent,
    ping,
    ping_failure,
)

ARGUMENTS = ["-p", "--output-format", "stream-json", "--verbose", "ping"]


def read(command: str, _folder: Path, timeout: float) -> list[LimitRow]:
    return rows(ping(command, ARGUMENTS, timeout))


def rows(result: Ping) -> list[LimitRow]:
    info = _last_rate_limit_info(result.output)
    if info and info.get("unifiedWindows"):
        return [_window_row(name, window) for name, window in info["unifiedWindows"].items()]
    if info:
        resets = format_reset_time(info["resetsAt"]) if info.get("resetsAt") else "unknown"
        return [LimitRow(window=info.get("rateLimitType") or "-", resets=resets, status=info.get("status") or "unknown")]
    if result.exit_code == 0:
        return [LimitRow(status="no limit readout")]
    return [LimitRow(status=ping_failure(result, "usage limit|rate limit"))]


def _last_rate_limit_info(output: str) -> dict[str, Any]:
    info = {}
    for line in output.splitlines():
        try:
            event = json.loads(line)
        except ValueError:
            continue
        if isinstance(event, dict) and event.get("type") == "rate_limit_event":
            info = event.get("rate_limit_info") or {}
    return info


def _window_row(name: str, window: dict[str, Any]) -> LimitRow:
    used = format_used_percent(window["utilization"] * 100) if window.get("utilization") is not None else "unknown"
    resets = format_reset_time(window["resetsAt"]) if window.get("resetsAt") else "unknown"
    return LimitRow(window=name, used=used, resets=resets, status=window.get("status") or "unknown")
