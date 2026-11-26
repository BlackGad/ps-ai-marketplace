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


# Files in the bin folder that are not account launchers: the owner commands and the uv that install.sh may publish.
OTHER_NAMES = ("legion", "uv")


# The files in the bin folder named like an account; none when the folder is missing or linked.
def candidates(home: Path) -> list[Path]:
    folder = bin_folder(home)
    if not folder.is_dir() or not owner_path_safe(folder, home):
        return []
    names = [(path, path.name.removesuffix(".cmd")) for path in sorted(folder.iterdir())]
    return [path for path, name in names if re.fullmatch(NAME_PATTERN, name) and name not in OTHER_NAMES]


def _is_old_launcher(path: Path, home: Path) -> bool:
    return owner_path_safe(path, home) and is_owned(path, _owner_name(path.name.removesuffix(".cmd")))


# True while an old launcher legion wrote may still be in the bin folder: one is there, or the folder is linked and
# cannot be looked into safely. Such a launcher may run an older app's legion, so older apps stay.
def old_launchers_may_remain(home: Path) -> bool:
    folder = bin_folder(home)
    if os.path.lexists(folder) and not owner_path_safe(folder, home):
        return True
    return any(_is_old_launcher(path, home) for path in candidates(home))


# A file in the bin folder whose header names the account it is called after is an old launcher of legion's.
# It goes, with any footprint of it, once legion can start that account itself: the account is gone or its program is found.
# It stays while an account's own command is that file, and every other file stays; each kept candidate is reported.
def remove_old_launchers(agents: list[Agent], home: Path) -> list[str]:
    tools = {tool.id: tool for tool in load_descriptors(ToolDescriptor, "tool.json")}
    configured = {agent.id: agent for agent in agents}
    # The real files the accounts' own commands run, links followed.
    programs = {agent.id: Path(os.path.realpath(full_path(home_path(agent.command, home)))) for agent in agents if agent.command is not None}
    lines: list[str] = []
    for path in candidates(home):
        name = path.name.removesuffix(".cmd")
        if not owner_path_safe(path, home):
            lines.append(f"skip: {path} (linked)")
            continue
        if not is_owned(path, _owner_name(name)):
            lines.append(f"skip: {path} (not legion's)")
            continue
        user = next((account for account, program in programs.items() if same_path(program, Path(os.path.realpath(path)))), None)
        if user is not None:
            lines.append(f"skip: {path} (account {user} runs it)")
            continue
        if name in configured:
            try:
                target(configured[name], tools[configured[name].tool], home)
            except LauncherError as error:
                lines.append(f"skip: {path} ({error})")
                continue
        # The footprint goes first: if that fails, the file is still there for the next refresh to find.
        _footprints.remove_entry(home, "file", path)
        path.unlink()
        lines.append(f"removed {path}")
    return lines
