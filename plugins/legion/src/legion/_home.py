# Where legion keeps its files in the owner's home; status, limits and the inbox share this layout.

import os
import sys
from pathlib import Path
from typing import Optional


# No --home means the owner's real home.
def legion_home(home: Optional[Path]) -> Path:
    return home if home is not None else Path.home()


def settings_path(home: Path) -> Path:
    return home / ".legion" / "configuration" / "personalisation.json"


def footprint_index(home: Path) -> Path:
    return home / ".legion" / "footprints.json"


def full_path(path: Path) -> Path:
    # Link resolution would hide a linked component before the safety walk sees it.
    return Path(os.path.normpath(Path.cwd() / path))


def resolve_directory(path: Path) -> Path:
    return path.resolve(strict=False)


def same_path(left: Path, right: Path) -> bool:
    return os.path.normcase(str(left)) == os.path.normcase(str(right))


def is_under(path: Path, root: Path, allow_equal: bool = False) -> bool:
    candidate, base = full_path(path), full_path(root)
    if same_path(candidate, base):
        return allow_equal
    try:
        return same_path(Path(os.path.commonpath([candidate, base])), base)
    except ValueError:
        return False


def owner_path_safe(path: Path, stop_root: Path) -> bool:
    current, root = full_path(path), full_path(stop_root)
    if not is_under(current, root, allow_equal=True):
        raise ValueError("Path is outside the link-walk stop root")
    while not same_path(current, root):
        if current.is_symlink() or current.is_junction():
            return False
        current = current.parent
    return True


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
