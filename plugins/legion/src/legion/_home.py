# Where legion keeps its files in the owner's home; status, limits and the inbox share this layout.

import os
import stat
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
    return Path(os.path.normpath(path.absolute()))


def resolve_directory(path: Path) -> Path:
    return full_path(path).resolve(strict=False)


def is_reparse(path: Path) -> bool:
    # Other reparse types beyond symlinks and junctions must be refused, as PowerShell does.
    try:
        info = path.lstat()
    except FileNotFoundError:
        return False
    except OSError:
        return True
    return stat.S_ISLNK(info.st_mode) or bool(getattr(info, "st_file_attributes", 0) & getattr(stat, "FILE_ATTRIBUTE_REPARSE_POINT", 0))


def tree_has_reparse(path: Path) -> bool:
    # os.walk reports unreadable descendants; rglob can silently omit them during a deletion check.
    failed = False

    def on_error(_error: OSError) -> None:
        nonlocal failed
        failed = True

    for root, folders, files in os.walk(path, followlinks=False, onerror=on_error):
        if any(is_reparse(Path(root) / name) for name in folders + files):
            return True
    return failed


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


# Hand-built, reason: check every lexical path component with is_reparse before a link can hide it.
def owner_path_safe(path: Path, stop_root: Path) -> bool:
    current, root = full_path(path), full_path(stop_root)
    if not is_under(current, root, allow_equal=True):
        raise ValueError("Path is outside the link-walk stop root")
    while not same_path(current, root):
        if is_reparse(current):
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
