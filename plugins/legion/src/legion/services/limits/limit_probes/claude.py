# Claude Code prints a rate_limit_event in its stream; each unified window has a utilization (0 to 1) and a reset time.

from pathlib import Path
from typing import Optional

from pydantic import BaseModel, Field, ValidationError

from legion.services.limits.limit_probes._ping import LimitRow, Ping, format_reset_time, format_used_percent, ping, ping_failure

ARGUMENTS = ["-p", "--output-format", "stream-json", "--verbose", "ping"]


class UnifiedWindow(BaseModel):
    utilization: Optional[float] = None
    resets_at: Optional[float] = Field(default=None, alias="resetsAt")
    status: Optional[str] = None


class RateLimitInfo(BaseModel):
    status: Optional[str] = None
    resets_at: Optional[float] = Field(default=None, alias="resetsAt")
    rate_limit_type: Optional[str] = Field(default=None, alias="rateLimitType")
    unified_windows: Optional[dict[str, UnifiedWindow]] = Field(default=None, alias="unifiedWindows")


# Every line of the stream is an event; only a rate_limit_event carries rate_limit_info.
class RateLimitEvent(BaseModel):
    type: Optional[str] = None
    rate_limit_info: Optional[RateLimitInfo] = None


def read(command: str, _folder: Path, timeout: float) -> list[LimitRow]:
    return rows(ping(command, ARGUMENTS, timeout))


def rows(result: Ping) -> list[LimitRow]:
    info = _last_rate_limit_info(result.output)
    if info and info.unified_windows:
        return [_window_row(name, window) for name, window in info.unified_windows.items()]
    if info:
        resets = format_reset_time(info.resets_at) if info.resets_at else "unknown"
        return [LimitRow(window=info.rate_limit_type or "-", resets=resets, status=info.status or "unknown")]
    if result.exit_code == 0:
        return [LimitRow(status="no limit readout")]
    return [LimitRow(status=ping_failure(result, "usage limit|rate limit"))]


# A line that is not an event of the expected shape is skipped.
def _last_rate_limit_info(output: str) -> Optional[RateLimitInfo]:
    info = None
    for line in output.splitlines():
        try:
            event = RateLimitEvent.model_validate_json(line)
        except ValidationError:
            continue
        if event.type == "rate_limit_event":
            info = event.rate_limit_info
    return info


def _window_row(name: str, window: UnifiedWindow) -> LimitRow:
    used = format_used_percent(window.utilization * 100) if window.utilization is not None else "unknown"
    resets = format_reset_time(window.resets_at) if window.resets_at else "unknown"
    return LimitRow(window=name, used=used, resets=resets, status=window.status or "unknown")
