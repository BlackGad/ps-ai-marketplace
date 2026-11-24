# Where legion keeps its files in the owner's home; status, limits and the inbox share this layout.

import sys
from pathlib import Path
from typing import Optional


# No --home means the owner's real home.
def legion_home(home: Optional[Path]) -> Path:
    return home if home is not None else Path.home()


def settings_path(home: Path) -> Path:
    return home / ".legion" / "configuration" / "personalisation.json"


def bin_folder(home: Path) -> Path:
    return home / ".legion" / "bin"


def update_cache_path(home: Path) -> Path:
    return home / ".legion" / "temp" / "update.json"


def inbox_root(home: Path) -> Path:
    return home / ".legion" / "inbox"


def channel_folder(kind: str, channel: str, home: Path) -> Path:
    return home / ".legion" / "channels" / kind / channel


# The command legion writes for an account: <account>.cmd on Windows.
def wrapper_command(account: str, home: Path) -> Path:
    name = f"{account}.cmd" if sys.platform == "win32" else account
    return (bin_folder(home) / name).absolute()


# '~/' or '~\' at the start means the legion home root.
def home_path(path: str, home: Path) -> Path:
    return home / path[2:] if path.startswith(("~/", "~\\")) else Path(path)
