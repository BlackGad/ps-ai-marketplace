# Subscription accounts in the owner's settings: add, register, rename and remove, with their launchers and footprints.

import re
import shutil
from pathlib import Path
from typing import Optional

from . import _footprints, _launchers, _settings_io
from ._home import full_path, home_path, same_path
from ._settings_models import NAME_PATTERN, Agent, PersonalisationSettings, ToolDescriptor
from ._validate import load_descriptors


class AccountError(Exception):
    pass


def _tool(tool_id: str) -> ToolDescriptor:
    matches = [descriptor for descriptor in load_descriptors(ToolDescriptor, "tool.json") if descriptor.id == tool_id]
    if not matches:
        raise AccountError(f"unknown tool '{tool_id}'")
    return matches[0]


def _check_id(account: str) -> None:
    if not re.fullmatch(NAME_PATTERN, account):
        raise AccountError(f"id '{account}' must match ^{NAME_PATTERN}$")


def _find(settings: PersonalisationSettings, account: str) -> Optional[Agent]:
    matches = [agent for agent in settings.agents if agent.id == account]
    return matches[0] if matches else None


def _check_new_id(settings: PersonalisationSettings, account: str, home: Path) -> None:
    _check_id(account)
    if account == "legion":
        raise AccountError(f"'{account}' is reserved for an owner command")
    if _find(settings, account) is not None:
        raise AccountError(f"account '{account}' already exists")
    if _launchers.find_command(account, home) is not None:
        raise AccountError(f"'{account}' is already a command")


# A bare name is the account's own launcher when it spells one; the owner names a file, or a command on PATH.
def _resolve_command(text: str, account: str, home: Path) -> Path:
    if text in (account, f"{account}.cmd"):
        raise _launchers.LauncherError("wrapper target would recurse")
    expanded = home_path(text, home)
    if full_path(expanded).is_file():
        return full_path(expanded)
    found = shutil.which(str(expanded))
    if found is None:
        raise AccountError(f"target needed: {account}; ask the owner for an existing executable")
    return full_path(Path(found))


def _config_folder(account: str, config_dir: Optional[str], home: Path) -> Path:
    if config_dir is None:
        return full_path(home / ".legion" / "agents" / account)
    folder = full_path(home_path(config_dir, home))
    if not folder.is_dir():
        raise AccountError("Existing account config folder does not exist.")
    return folder


# The command is stored only when it is not the tool's stock command, which launchers find on their own.
def _stored_command(command: Optional[Path], tool: ToolDescriptor, home: Path) -> Optional[str]:
    if command is None or _launchers.is_stock(command, tool, home):
        return None
    return str(command)


# An account made earlier: written from settings when it has a command or a command was given, else only repaired.
def _repair(settings: PersonalisationSettings, existing: Agent, tool: ToolDescriptor, command: Optional[Path], folder: Path, home: Path) -> list[str]:
    settings_changed = False
    if command is not None:
        wanted = _stored_command(command, tool, home)
        settings_changed = existing.command != wanted
        existing.command = wanted
    elif existing.command is None:
        state = _launchers.launcher_state(existing, home)
        if state == "intact":
            repaired = _launchers.restore_execute(existing, home)
            return [f"wrote: launcher {path}" for path in repaired] or [f"skip: account {existing.id} (already done)"]
        if state == "partial":
            raise _launchers.LauncherError(f"target needed: {existing.id}; ask the owner for the registered executable")
    _launchers.plan_subscription(existing, tool, home)
    if settings_changed:
        _settings_io.save_locked(home, settings)
    lines = [f"wrote: launcher {path}" for path in _launchers.write_subscription(existing, tool, home)]
    folder.mkdir(parents=True, exist_ok=True)
    if settings_changed:
        lines.append(f"wrote: command of account {existing.id}")
    return lines or [f"skip: account {existing.id} (already done)"]


def add_subscription(home: Path, account: str, tool_id: str, command: Optional[str], config_dir: Optional[str]) -> list[str]:
    _check_id(account)
    tool = _tool(tool_id)
    real = _resolve_command(command, account, home) if command is not None else None
    folder = _config_folder(account, config_dir, home)
    with _settings_io.writer(home, require_existing=False):
        settings = _settings_io.load_or_empty(home)
        existing = _find(settings, account)
        if existing is not None and existing.provider is None and existing.tool == tool_id and same_path(full_path(home_path(existing.config_dir, home)), folder):
            return _repair(settings, existing, tool, real, folder, home)
        _check_new_id(settings, account, home)
        agent = Agent.model_construct(id=account, tool=tool_id, config_dir=str(folder), command=_stored_command(real, tool, home))
        _launchers.plan_subscription(agent, tool, home)
        settings.agents.append(agent)
        _settings_io.save_locked(home, settings)
        _launchers.write_subscription(agent, tool, home)
        folder.mkdir(parents=True, exist_ok=True)
    return [f"Existing account folder kept at {config_dir}; use '{account}' to open it."] if config_dir is not None else [f"Run '{account}' in a terminal and log in once."]


# Bindings follow a renamed account; removing an account cannot leave a channel without accounts.
def _rebind(settings: PersonalisationSettings, account: str, new_id: Optional[str]) -> None:
    for channel in settings.channels:
        if new_id is None and channel.accounts == [account]:
            raise AccountError(f"channel '{channel.id}' would have no accounts; rebind or remove it first")
    for channel in settings.channels:
        if new_id is None:
            channel.accounts = [name for name in channel.accounts if name != account]
        else:
            channel.accounts = [new_id if name == account else name for name in channel.accounts]


def _move_footprints(home: Path, account: str, new_id: str) -> list[str]:
    for entry in _footprints.read(home).entries:
        if entry.kind == "folder" and f"account:{account}" in entry.owners:
            _footprints.add(home, "folder", entry.path, f"account:{new_id}")
    return _footprints.remove_owner(home, [f"account:{account}"])


def rename(home: Path, account: str, new_id: str) -> list[str]:
    with _settings_io.writer(home):
        settings = _settings_io.load(home)
        old = _find(settings, account)
        if old is None and _find(settings, new_id) is not None:
            return [f"skip: account rename {account} to {new_id} (already done)"]
        _check_new_id(settings, new_id, home)
        if old is None:
            raise AccountError(f"unknown account '{account}'")
        if old.provider is not None:
            raise AccountError(f"account '{account}' runs through Foundry; rename it after this update")
        for path in _launchers.launcher_paths(new_id, home):
            if path.exists() or path.is_symlink():
                raise _launchers.LauncherError(f"wrapper collision '{path}'")
        _rebind(settings, account, new_id)
        old.id = new_id
        _settings_io.save_locked(home, settings)
        _launchers.move(account, new_id, home)
        lines = _move_footprints(home, account, new_id)
    return [*lines, f"Config folder kept at {old.config_dir}; rename it yourself only if you want to."]


def remove(home: Path, account: str) -> list[str]:
    with _settings_io.writer(home):
        settings = _settings_io.load_unchecked(home)
        agent = _find(settings, account)
        if agent is None:
            return [f"skip: account remove {account} (already done)"]
        _rebind(settings, account, None)
        settings.agents = [other for other in settings.agents if other.id != account]
        _settings_io.save_locked(home, settings)
        _launchers.remove(account, home)
        lines = _footprints.remove_owner(home, [f"account:{account}"])
    return [*lines, f"Config folder kept at {agent.config_dir}."]
