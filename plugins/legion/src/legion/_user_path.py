# The Windows user PATH saved in the registry: read it, add one folder, and find commands on it.
# LEGION_TEST_USER_PATH_FILE stands in for the registry value in tests.

import contextlib
import ctypes
import ntpath
import os
import shutil
import sys
from pathlib import Path
from typing import Optional

from . import _footprints

if sys.platform == "win32":
    import winreg

USER_ENVIRONMENT = "Environment"
MACHINE_ENVIRONMENT = r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment"


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
