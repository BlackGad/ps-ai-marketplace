# The Windows user PATH saved in the registry: read it, add one folder, and find commands on it.
# On macOS and Linux the PATH line goes into the shell profile.
# LEGION_TEST_USER_PATH_FILE stands in for the registry value in tests.

import contextlib
import ctypes
import ntpath
import os
import re
import shutil
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

from legion.services.repository import _footprints
from legion.core._home import owner_path_safe
from legion.core._text import TextFormat, decode_text

if sys.platform == "win32":
    import winreg

USER_ENVIRONMENT = "Environment"
MACHINE_ENVIRONMENT = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
PROFILE_MARKER = "# Added by legion"
PROFILE_LINE = 'export PATH="$HOME/.legion/bin:$PATH"'


class PathError(Exception):
    pass


# Windows compares without case and expands %VARIABLES%; ntpath does that on every system.
def has_entry(path: str, folder: str) -> bool:
    target = folder.rstrip("\\/").lower()
    return any(ntpath.expandvars(part).rstrip("\\/").lower() == target for part in path.split(";"))


def _registry_path(machine: bool) -> str:
    assert sys.platform == "win32"
    root, subkey = (winreg.HKEY_LOCAL_MACHINE, MACHINE_ENVIRONMENT) if machine else (winreg.HKEY_CURRENT_USER, USER_ENVIRONMENT)
    try:
        with winreg.OpenKey(root, subkey) as key:
            # The raw value: an entry such as %USERPROFILE%\bin stays unexpanded.
            return str(winreg.QueryValueEx(key, "Path")[0])
    except FileNotFoundError:
        return ""


def user_path() -> str:
    test_file = os.environ.get("LEGION_TEST_USER_PATH_FILE")
    if test_file:
        return Path(test_file).read_text(encoding="utf-8") if Path(test_file).exists() else ""
    return _registry_path(machine=False)


# Hand-built, reason: the standard library has no call that tells running programs the environment changed, so
# the registry write is followed by the same WM_SETTINGCHANGE broadcast that Windows' own settings dialog sends.
def set_user_path(value: str) -> None:
    test_file = os.environ.get("LEGION_TEST_USER_PATH_FILE")
    if test_file:
        Path(test_file).write_text(value, encoding="utf-8")
        return
    assert sys.platform == "win32"
    with winreg.CreateKey(winreg.HKEY_CURRENT_USER, USER_ENVIRONMENT) as key:
        # Keep the existing value type (normally REG_EXPAND_SZ).
        kind = winreg.REG_EXPAND_SZ
        with contextlib.suppress(FileNotFoundError):
            kind = winreg.QueryValueEx(key, "Path")[1]
        winreg.SetValueEx(key, "Path", 0, kind, value)
    broadcast = 0xFFFF
    setting_change = 0x1A
    abort_if_hung = 2
    result = ctypes.c_size_t()
    ctypes.WinDLL("user32").SendMessageTimeoutW(broadcast, setting_change, 0, USER_ENVIRONMENT, abort_if_hung, 5000, ctypes.byref(result))


# Add a folder once; callers get consent before calling. Returns whether the PATH changed.
def add(home: Path, folder: Path) -> bool:
    current = user_path()
    if has_entry(current, str(folder)):
        return False
    _footprints.add(home, "path-entry", "user PATH", "legion", value=str(folder).rstrip("\\/"))
    set_user_path(current.rstrip(";") + ";" + str(folder) if current else str(folder))
    return True


# The folders on the saved user and machine PATH, expanded. A new install shows up here before a new terminal.
def persistent_folders() -> list[str]:
    folders: list[str] = []
    for path in (user_path(), _registry_path(machine=True)):
        for entry in path.split(";"):
            folder = ntpath.expandvars(entry.strip().strip('"'))
            if folder:
                folders.append(folder)
    return folders


# A command found only on the saved PATH. Nothing is run: a sanitized shell may leave these folders out on purpose.
def find_persistent_command(name: str) -> Optional[str]:
    return shutil.which(name, path=os.pathsep.join(persistent_folders()))


@dataclass(frozen=True)
class ShellProfile:
    path: Path
    text: str
    line: str
    has_path: bool
    # Marked: the line sits under legion's marker, so legion added it; a bare line is the owner's.
    marked: bool


# macOS and Linux: the profile of the owner's shell receives one PATH line.
def shell_profile(home: Path) -> ShellProfile:
    name = {"zsh": ".zshrc", "bash": ".bashrc"}.get(Path(os.environ.get("SHELL", "")).name, ".profile")
    path = home / name
    text = _read_profile(path)[0] if path.exists() else ""
    marked = re.search(rf"^{re.escape(PROFILE_MARKER)}\r?\n{re.escape(PROFILE_LINE)}\r?$", text, re.MULTILINE) is not None
    return ShellProfile(path, text, PROFILE_LINE, PROFILE_LINE in re.split(r"\r?\n", text), marked)


def _read_profile(path: Path) -> tuple[str, TextFormat]:
    try:
        return decode_text(path.read_bytes())
    except UnicodeError:
        raise PathError("File encoding is not lossless; resolve it manually before editing") from None


# Adds the PATH line to the shell profile once; callers get consent before calling. With dry_run it only says what it would do.
def shell_profile_lines(home: Path, dry_run: bool = False) -> list[str]:
    profile = shell_profile(home)
    if not owner_path_safe(profile.path, home):
        raise PathError("Shell profile contains a link; resolve it before writing")
    if profile.has_path:
        if profile.marked and not dry_run:
            stored = _footprints.stored_path(home, profile.path)
            recorded = [entry for entry in _footprints.read(home).entries if entry.kind == "path-entry" and entry.value == profile.line and entry.path == stored]
            _footprints.add(home, "path-entry", profile.path, "legion", key=recorded[0].key if recorded else "", value=profile.line)
        return ["skip: shell profile PATH (already done)"]
    lines = [f"add {PROFILE_MARKER} and {profile.line} to {profile.path}"]
    if dry_run:
        return lines
    # Record a separating newline too, so purge restores a file without a final newline exactly.
    separator = "\n" if profile.text and not profile.text.endswith("\n") else ""
    _footprints.add(home, "path-entry", profile.path, "legion", key=separator, value=profile.line)
    addition = f"{separator}{PROFILE_MARKER}\n{profile.line}\n"
    if profile.path.exists():
        # Appending keeps every original byte, in the codec the file already uses.
        with profile.path.open("ab") as file:
            file.write(addition.encode(_read_profile(profile.path)[1].encoding))
    else:
        profile.path.write_text(addition, encoding="utf-8", newline="")
    return lines
