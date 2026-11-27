# What every tool's recipe shares: the limits row, its formats and the ping from a disposable folder.

import re
import shutil
import tempfile
import time
from collections.abc import Sequence
from datetime import UTC, datetime
from pathlib import Path

from pydantic import BaseModel, ConfigDict, computed_field

from legion.core._run import RunResult, run_command
from legion.services.accounts._launch import AccountCommand


# One row of the limits table; every field a tool does not expose stays 'unknown'.
class LimitRow(BaseModel):
    model_config = ConfigDict(frozen=True)

    window: str = "-"
    used: str = "unknown"
    resets: str = "unknown"
    status: str = "unknown"

    # What is left of the window: 100 minus the used percent; 'unknown' and '-' pass through.
    @computed_field
    @property
    def left(self) -> str:
        if not self.used.endswith("%"):
            return self.used
        return f"{min(100, max(0, 100 - int(self.used.removesuffix('%'))))}%"


# A finished ping. folder is the resolved ping folder, which a Codex session names as its working folder.
class Ping(RunResult):
    folder: Path


def format_reset_time(unix_seconds: float) -> str:
    return datetime.fromtimestamp(unix_seconds, UTC).astimezone().strftime("%Y-%m-%d %H:%M")


# round() rounds half to even, as PowerShell's [math]::Round does.
def format_used_percent(percent: float) -> str:
    return f"{round(percent)}%"


def first_line(text: str) -> str:
    return next((line.strip() for line in text.splitlines() if line.strip()), "")


def find_executable(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise RuntimeError(f"{name} is not installed")
    return path


# A fresh empty folder keeps a ping away from every project's settings, rules and hooks.
# The git init a Codex ping needs and the ping itself share one deadline.
def ping(command: AccountCommand, arguments: Sequence[str], timeout: float, *, git: bool = False) -> Ping:
    deadline = time.monotonic() + timeout
    work = Path(tempfile.mkdtemp(prefix="legion-limits-"))
    try:
        if git:
            initialised = run_command(find_executable("git"), ["-C", str(work), "init", "-q"], timeout=timeout)
            if initialised.timed_out:
                raise RuntimeError("git init timed out")
            if initialised.exit_code != 0:
                raise RuntimeError(f"git init failed (exit code {initialised.exit_code})")
        words = command.words(arguments)
        result = run_command(words[0], words[1:], timeout=max(0.0, deadline - time.monotonic()), env=command.environment(), cwd=work)
        return Ping(**result.model_dump(), folder=work.resolve())
    finally:
        shutil.rmtree(work, ignore_errors=True)


# The status of a ping that gave no readout. Only the tool's own quota wording counts as 'limit reached'.
def ping_failure(result: Ping, quota_pattern: str) -> str:
    if result.timed_out:
        return "ping timed out"
    text = result.error + "\n" + result.output
    if any(re.search(quota_pattern, line, re.IGNORECASE) for line in text.splitlines()):
        return "limit reached"
    return "ping failed: " + first_line(result.error)
