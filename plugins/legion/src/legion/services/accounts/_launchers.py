# An account's program, found from settings and the tool descriptor, and the per-account launchers that earlier
# legion versions wrote to <home>/.legion/bin. Only the one ownership header line of such a file is ever read.

import os
import re
import shutil
import sys
from pathlib import Path
from typing import Optional

from legion.core._generated import is_owned
from legion.core._home import (
    bin_folder,
    full_path,
    home_path,
    owner_path_safe,
    resolve_directory,
    same_path,
)
from legion.core._settings_models import NAME_PATTERN, Agent, ToolDescriptor
from legion.core._validate import load_descriptors
from legion.services.repository import _footprints


class LauncherError(Exception):
    pass


def _owner_name(account: str) -> str:
    return f"account {account}"


# <id> everywhere, and <id>.cmd beside it on Windows.
def launcher_paths(account: str, home: Path) -> list[Path]:
    names = [account, f"{account}.cmd"] if sys.platform == "win32" else [account]
    return [bin_folder(home) / name for name in names]


# shutil.which spells the extension as PATHEXT does (codex.CMD); the folder entry has the file's own spelling.
def _on_disk(path: Path) -> Path:
    for entry in path.parent.iterdir():
        if os.path.normcase(entry.name) == os.path.normcase(path.name):
            return entry
    return path


# A command on PATH, never one of legion's own launchers.
def find_command(name: str, home: Path) -> Optional[Path]:
    own = resolve_directory(bin_folder(home))
    folders = [entry for entry in os.environ.get("PATH", "").split(os.pathsep) if not same_path(resolve_directory(Path(entry)), own)]
    found = shutil.which(name, path=os.pathsep.join(folders))
    return _on_disk(Path(found).absolute()) if found else None


def stock_command(tool: ToolDescriptor, home: Path) -> Optional[Path]:
    return find_command(tool.command, home)


def is_stock(command: Path, tool: ToolDescriptor, home: Path) -> bool:
    stock = stock_command(tool, home)
    return stock is not None and same_path(resolve_directory(command), resolve_directory(stock))


def target(agent: Agent, tool: ToolDescriptor, home: Path) -> Path:
    if agent.command is not None:
        command = full_path(home_path(agent.command, home))
        if command.is_file():
            return command
        raise LauncherError(f"target needed: {agent.id}; ask the owner for the registered executable")
    stock = stock_command(tool, home)
    if stock is None:
        raise LauncherError(f"{tool.id} is not installed; run legion tool install --tool {tool.id}")
    return stock


# A file in the bin folder whose header names the account it is called after is an old launcher of legion's.
# It goes, with any footprint of it, once legion can start that account itself: the account is gone or its program is found.
# A file of another kind under a configured account's launcher name is not legion's and stays.
def remove_old_launchers(agents: list[Agent], home: Path) -> list[str]:
    folder = bin_folder(home)
    if not folder.is_dir() or not owner_path_safe(folder, home):
        return []
    tools = {tool.id: tool for tool in load_descriptors(ToolDescriptor, "tool.json")}
    configured = {agent.id: agent for agent in agents}
    lines: list[str] = []
    for path in sorted(folder.iterdir()):
        name = path.name.removesuffix(".cmd")
        if not re.fullmatch(NAME_PATTERN, name) or not owner_path_safe(path, home) or not is_owned(path, _owner_name(name)):
            continue
        if name in configured:
            try:
                target(configured[name], tools[configured[name].tool], home)
            except LauncherError as error:
                lines.append(f"skip: {path} ({error})")
                continue
        path.unlink()
        _footprints.remove_entry(home, "file", path)
        lines.append(f"removed {path}")
    for agent in agents:
        lines.extend(f"skip: {path} (not legion's)" for path in launcher_paths(agent.id, home) if os.path.lexists(path) and not is_owned(path, _owner_name(agent.id)))
    return lines
