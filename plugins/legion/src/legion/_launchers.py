# Account launchers: the files in <home>/.legion/bin that start an account's CLI with its own config folder.
# Text is built from settings and the tool descriptor; only the one ownership header line is ever read back.

import os
import shutil
import stat
import sys
from pathlib import Path
from typing import Literal, Optional

from ._generated import cmd_escape, header, is_owned, shell_literal, write_generated
from ._home import bin_folder, full_path, home_path, owner_path_safe, same_path
from ._settings_models import Agent, ToolDescriptor

# intact: every launcher is there and ours; none: no launcher file at all; partial: anything between.
LauncherState = Literal["intact", "none", "partial"]


class LauncherError(Exception):
    pass


def _owner_name(account: str) -> str:
    return f"account {account}"


# <id> everywhere, and <id>.cmd beside it on Windows.
def launcher_paths(account: str, home: Path) -> list[Path]:
    names = [account, f"{account}.cmd"] if sys.platform == "win32" else [account]
    return [bin_folder(home) / name for name in names]


def _target_needed(account: str) -> LauncherError:
    return LauncherError(f"target needed: {account}; ask the owner for the registered executable")


# shutil.which spells the extension as PATHEXT does (codex.CMD); the folder entry has the file's own spelling.
def _on_disk(path: Path) -> Path:
    for entry in path.parent.iterdir():
        if os.path.normcase(entry.name) == os.path.normcase(path.name):
            return entry
    return path


# A command on PATH, never one of legion's own launchers.
def find_command(name: str, home: Path) -> Optional[Path]:
    own = full_path(bin_folder(home))
    folders = [entry for entry in os.environ.get("PATH", "").split(os.pathsep) if not same_path(full_path(Path(entry)), own)]
    found = shutil.which(name, path=os.pathsep.join(folders))
    return _on_disk(Path(found).absolute()) if found else None


def stock_command(tool: ToolDescriptor, home: Path) -> Optional[Path]:
    return find_command(tool.command, home)


def is_stock(command: Path, tool: ToolDescriptor, home: Path) -> bool:
    stock = stock_command(tool, home)
    return stock is not None and same_path(full_path(command), stock)


def target(agent: Agent, tool: ToolDescriptor, home: Path) -> Path:
    if agent.command is not None:
        command = full_path(home_path(agent.command, home))
        if command.is_file():
            return command
        raise _target_needed(agent.id)
    stock = stock_command(tool, home)
    if stock is None:
        raise _target_needed(agent.id)
    return stock


# Hand-built, reason: cmd.exe has no quoting the standard library offers (subprocess.list2cmdline targets the C runtime).
# Ids match ^[a-z][a-z0-9-]*$ and Windows paths cannot hold a double quote, so doubling % is the only escape.
def subscription_text(account: str, variable: str, folder: str, target: str, windows: bool) -> str:
    extension = Path(target).suffix.lower()
    if windows:
        escaped = cmd_escape(target)
        if extension == ".ps1":
            run = f'@pwsh -NoProfile -File "{escaped}" %*'
        elif extension in (".cmd", ".bat"):
            run = f'@call "{escaped}" %*'
        else:
            run = f'@"{escaped}" %*'
        lines = [header(_owner_name(account), True), "@setlocal", f'@set "{variable}={cmd_escape(folder)}"', run, "@exit /b %errorlevel%"]
        return "\r\n".join(lines) + "\r\n"
    literal = shell_literal(target)
    if extension == ".ps1":
        literal = "pwsh -NoProfile -File " + literal
    lines = ["#!/bin/sh", header(_owner_name(account), False), f'{variable}={shell_literal(folder)} exec {literal} "$@"']
    return "\n".join(lines) + "\n"


def _owned(path: Path, account: str, home: Path) -> bool:
    return owner_path_safe(path, home) and is_owned(path, _owner_name(account))


def launcher_state(agent: Agent, home: Path) -> LauncherState:
    paths = launcher_paths(agent.id, home)
    if not any(os.path.lexists(path) for path in paths):
        return "none"
    return "intact" if all(_owned(path, agent.id, home) for path in paths) else "partial"


# Gives a launcher of ours its execute permission back without reading or changing its text; returns what it fixed.
def restore_execute(agent: Agent, home: Path) -> list[Path]:
    if sys.platform == "win32":
        return []
    lacking = [path for path in launcher_paths(agent.id, home) if _owned(path, agent.id, home) and not path.stat().st_mode & stat.S_IXUSR]
    for path in lacking:
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return lacking


# Every check a write needs, then the text of each launcher; nothing is written.
def plan_subscription(agent: Agent, tool: ToolDescriptor, home: Path) -> dict[Path, str]:
    real = target(agent, tool, home)
    paths = launcher_paths(agent.id, home)
    if any(same_path(real, path) for path in paths):
        raise LauncherError("wrapper target would recurse")
    for path in paths:
        if not owner_path_safe(path, home):
            raise LauncherError(f"linked wrapper path '{path}'")
        if os.path.lexists(path) and not is_owned(path, _owner_name(agent.id)):
            raise LauncherError(f"wrapper collision '{path}'")
    folder = str(full_path(home_path(agent.config_dir, home)))
    return {path: subscription_text(agent.id, tool.config_env, folder, str(real), windows=path.suffix == ".cmd") for path in paths}


# Writes the launchers from settings and returns the files that changed.
def write_subscription(agent: Agent, tool: ToolDescriptor, home: Path) -> list[Path]:
    return [path for path, text in plan_subscription(agent, tool, home).items() if write_generated(path, text, executable=path.suffix != ".cmd")]


# The launchers keep their text; only the account named on the header line changes.
def move(old: str, new: str, home: Path) -> None:
    moves = [(source, destination) for source, destination in zip(launcher_paths(old, home), launcher_paths(new, home), strict=True) if _owned(source, old, home)]
    for _, destination in moves:
        if not owner_path_safe(destination, home):
            raise LauncherError(f"linked wrapper path '{destination}'")
        if os.path.lexists(destination):
            raise LauncherError(f"wrapper collision '{destination}'")
    for source, destination in moves:
        windows = source.suffix == ".cmd"
        text = source.read_bytes().decode("utf-8").replace(header(_owner_name(old), windows), header(_owner_name(new), windows), 1)
        write_generated(destination, text, executable=not windows)
        source.unlink()


def remove(account: str, home: Path) -> list[Path]:
    removed = [path for path in launcher_paths(account, home) if _owned(path, account, home)]
    for path in removed:
        path.unlink()
    return removed
