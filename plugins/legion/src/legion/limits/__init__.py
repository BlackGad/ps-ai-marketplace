# Account limits: each tool's recipe is chosen by its tool id; Foundry accounts report the Azure token check.

import stat
import sys
from collections.abc import Callable
from pathlib import Path

from .._settings_models import Agent
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

__all__ = ["LimitRow", "account_rows"]

Reader = Callable[[str, Path, float], list[LimitRow]]
READERS: dict[str, Reader] = {"claude": claude.read, "codex": codex.read, "copilot": copilot.read}


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
