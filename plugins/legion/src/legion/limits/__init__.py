# Account limits: each tool's recipe is chosen by its tool id; Foundry accounts report the Azure token check.

import stat
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Optional

from .._settings_models import Agent, PersonalisationSettings
from .._validate import _read_text
from . import (
    claude,
    codex,
    copilot,
    foundry,
)
from ._ping import (
    LimitRow,
    first_line,
)

__all__ = ["LimitRow", "LimitsError", "account_rows", "report_lines"]

Reader = Callable[[str, Path, float], list[LimitRow]]
READERS: dict[str, Reader] = {"claude": claude.read, "codex": codex.read, "copilot": copilot.read}
COLUMNS = ["Account", "Tool", "Window", "Used", "Resets at", "Status"]
DEFAULT_TIMEOUT = 120


class LimitsError(Exception):
    pass


# The limits table of every account, or of one.
def report_lines(home: Path, account: Optional[str] = None, timeout: float = DEFAULT_TIMEOUT) -> list[str]:
    file = home / ".legion" / "configuration" / "personalisation.json"
    if not file.is_file():
        raise LimitsError("No legion settings yet; run legion setup.")
    try:
        agents = PersonalisationSettings.model_validate_json(_read_text(file)).agents
    except (OSError, ValueError) as error:
        raise LimitsError("legion settings are not valid: " + first_line(str(error))) from None
    if account is not None:
        agents = [agent for agent in agents if agent.id == account]
        if not agents:
            raise LimitsError(f"unknown account '{account}'")
    rows = [[agent.id, agent.tool, row.window, row.used, row.resets, row.status] for agent in agents for row in account_rows(agent, home, timeout)]
    if not rows:
        return ["No accounts yet; run legion add."]
    return table_lines(rows)


# As PowerShell's Format-Table -AutoSize: a blank line, the header, dashes, then the rows;
# columns as wide as their longest text, one space apart, the last one not padded.
def table_lines(rows: list[list[str]]) -> list[str]:
    table = [COLUMNS, ["-" * len(name) for name in COLUMNS], *rows]
    widths = [max(len(row[column]) for row in table) for column in range(len(COLUMNS))]
    lines = [""]
    for row in table:
        cells = [cell.ljust(width) for cell, width in zip(row, widths, strict=True)]
        lines.append(" ".join([*cells[:-1], row[-1]]))
    return lines


# The rows of one account; an unexpected failure becomes an 'error:' row instead of stopping the table.
def account_rows(agent: Agent, home: Path, timeout: float) -> list[LimitRow]:
    try:
        if agent.provider and agent.provider.kind == "foundry":
            check = foundry.check_token(timeout)
            return [LimitRow(used="-", resets="-", status="token ok" if check.ok else first_line(check.error))]
        reader = READERS.get(agent.tool)
        if reader is None:
            return [LimitRow(status=f"no limits script for {agent.tool}")]
        command = wrapper_command(agent.id, home)
        if not _is_executable(command):
            return [LimitRow(status="launcher missing; run legion setup")]
        return reader(str(command), home_path(agent.config_dir, home), timeout)
    except Exception as error:
        return [LimitRow(status="error: " + first_line(str(error)))]


def wrapper_command(account: str, home: Path) -> Path:
    name = f"{account}.cmd" if sys.platform == "win32" else account
    return (home / ".legion" / "bin" / name).absolute()


# '~/' or '~\' at the start means the legion home root.
def home_path(path: str, home: Path) -> Path:
    if path[:2] in ("~/", "~\\"):
        return home / path[2:]
    return Path(path)


def _is_executable(path: Path) -> bool:
    if not path.is_file():
        return False
    return sys.platform == "win32" or bool(path.stat().st_mode & stat.S_IXUSR)
