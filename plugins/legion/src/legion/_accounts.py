# Owner accounts: subscription and Foundry add, register, rename, remove and models.

import os
import re
import shutil
from pathlib import Path
from typing import Optional

from . import _footprints, _generated, _launchers, _settings_io
from ._home import full_path, home_path, same_path
from ._settings_models import NAME_PATTERN, Agent, PersonalisationSettings, ToolDescriptor
from ._validate import load_descriptors, settings_issues
from .foundry import RECIPES, _discovery, recipe

POSIX = os.name != "nt"


class AccountError(Exception):
    pass


def get_tool(tool_id: str) -> ToolDescriptor:
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
        command = full_path(expanded)
    else:
        found = shutil.which(str(expanded))
        if found is None:
            raise AccountError(f"target needed: {account}; ask the owner for an existing executable")
        command = full_path(Path(found))
    if any(same_path(command, path) for path in _launchers.launcher_paths(account, home)):
        raise _launchers.LauncherError("wrapper target would recurse")
    if POSIX and command.suffix.lower() != ".ps1" and not os.access(command, os.X_OK):
        raise AccountError(f"target is not executable: {command}")
    return command


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


def _ensure_config_folder(folder: Path) -> list[str]:
    if folder.is_dir():
        return []
    folder.mkdir(parents=True, exist_ok=True)
    return [f"created: config folder {folder}"]


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
            lines = [f"wrote: launcher {path}" for path in repaired]
            lines.extend(_ensure_config_folder(folder))
            return lines or [f"skip: account {existing.id} (already done)"]
        if state == "partial":
            raise _launchers.LauncherError(f"target needed: {existing.id}; ask the owner for the registered executable")
    _launchers.plan_subscription(existing, tool, home)
    if settings_changed:
        _settings_io.save_locked(home, settings)
    lines = [f"wrote: launcher {path}" for path in _launchers.write_subscription(existing, tool, home)]
    lines.extend(_ensure_config_folder(folder))
    if settings_changed:
        lines.append(f"wrote: command of account {existing.id}")
    return lines or [f"skip: account {existing.id} (already done)"]


def add_subscription(home: Path, account: str, tool_id: str, command: Optional[str], config_dir: Optional[str]) -> list[str]:
    _check_id(account)
    tool = get_tool(tool_id)
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


def add_foundry(home: Path, account: str, tool_id: str, endpoint: str, names: list[str], default: Optional[str], aliases: Optional[list[str]], use_standard: bool, list_only: bool) -> list[str]:
    _check_id(account)
    tool = get_tool(tool_id)
    if tool.foundry is None or tool_id not in RECIPES:
        raise AccountError(f"tool '{tool_id}' does not support Foundry")
    endpoint = _discovery.endpoint_url(endpoint)
    before = _settings_io.load_or_empty(home)
    existing = _find(before, account)
    if not list_only and existing and existing.tool == tool_id and existing.provider and existing.provider.kind == "foundry" and existing.provider.endpoint == endpoint:
        with _settings_io.writer(home):
            current = _find(_settings_io.load(home), account)
            if current and current.tool == tool_id and current.provider and current.provider.kind == "foundry" and current.provider.endpoint == endpoint:
                if _launchers.launcher_state(current, home) != "none" or not _launchers.ready_versions(home):
                    return [f"skip: account {account} (already done)"]
                written = _launchers.write_foundry(current, home)
                return [f"wrote: launcher {path}" for path in written] or [f"skip: account {account} (already done)"]
    if not list_only:
        _check_new_id(before, account, home)
        provisional = Agent.model_construct(id=account, tool=tool_id, config_dir=str(home / ".legion" / "agents" / account))
        _launchers.plan_foundry(provisional, home)
    discovery = _discovery.discover(endpoint, tool)
    if list_only:
        return [_discovery.listing(discovery, []).model_dump_json(indent=2)]
    provider = _discovery.provider_block(endpoint, tool, names, default, aliases, discovery, use_standard=use_standard)
    with _settings_io.writer(home, require_existing=False):
        settings = _settings_io.load_or_empty(home)
        _check_new_id(settings, account, home)
        agent = Agent.model_validate({"id": account, "tool": tool_id, "configDir": str(home / ".legion" / "agents" / account), "provider": provider.model_dump(by_alias=True, exclude_none=True)})
        _launchers.plan_foundry(agent, home)
        settings.agents.append(agent)
        issues = settings_issues(settings)
        if issues:
            raise _settings_io.SettingsError("; ".join(issues))
        recipe(agent).configure(agent, home)
        _settings_io.save_locked(home, settings)
        _launchers.write_foundry(agent, home)
    return [f"Run '{account}' in a terminal; it signs in to Azure through az when needed."]


def models(home: Path, account: str, names: list[str], default: Optional[str], aliases: Optional[list[str]], use_standard: bool, list_only: bool) -> list[str]:
    settings = _settings_io.load(home)
    agent = _find(settings, account)
    if agent is None:
        raise AccountError(f"unknown account '{account}'")
    if agent.provider is None or agent.provider.kind != "foundry":
        raise AccountError(f"account '{account}' is not a Foundry agent")
    tool = get_tool(agent.tool)
    discovery = _discovery.discover(agent.provider.endpoint, tool)
    if list_only:
        return [_discovery.listing(discovery, agent.provider.deployments).model_dump_json(indent=2)]
    discovered_endpoint = agent.provider.endpoint
    discovered_tool = agent.tool
    with _settings_io.writer(home):
        settings = _settings_io.load(home)
        agent = _find(settings, account)
        if agent is None or agent.provider is None or agent.provider.kind != "foundry":
            raise AccountError(f"unknown account '{account}'")
        if agent.provider.endpoint != discovered_endpoint or agent.tool != discovered_tool:
            raise AccountError(f"account '{account}' changed during discovery; run the command again")
        provider = _discovery.provider_block(agent.provider.endpoint, tool, names, default, aliases, discovery, agent.provider, use_standard)
        if agent.provider == provider:
            return [f"skip: models {account} (no changes)"]
        agent.provider = provider
        issues = settings_issues(settings)
        if issues:
            raise _settings_io.SettingsError("; ".join(issues))
        recipe(agent).configure(agent, home)
        _settings_io.save_locked(home, settings)
        _launchers.write_foundry(agent, home)
    return []


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
        for path in _launchers.launcher_paths(new_id, home):
            if (path.exists() or path.is_symlink()) and not _generated.is_owned(path, f"account {new_id}"):
                raise _launchers.LauncherError(f"wrapper collision '{path}'")
        _rebind(settings, account, new_id)
        old.id = new_id
        if old.provider is not None:
            _launchers.write_foundry(old, home)
            _launchers.remove(account, home)
        else:
            _launchers.move(account, new_id, home)
        lines = _move_footprints(home, account, new_id)
        _settings_io.save_locked(home, settings)
    return [*lines, f"Config folder kept at {old.config_dir}; rename it yourself only if you want to."]


def remove(home: Path, account: str) -> list[str]:
    with _settings_io.writer(home):
        settings = _settings_io.load_unchecked(home)
        agent = _find(settings, account)
        if agent is None:
            return [f"skip: account remove {account} (already done)"]
        original = settings.model_copy(deep=True)
        _rebind(settings, account, None)
        settings.agents = [other for other in settings.agents if other.id != account]
        issues = settings_issues(settings)
        if issues:
            raise _settings_io.SettingsError("; ".join(issues))
        _launchers.remove(account, home)
        _settings_io.save_locked(home, settings)
        try:
            lines = _footprints.remove_owner(home, [f"account:{account}"])
        except Exception:
            _settings_io.save_locked(home, original)
            raise
    return [*lines, f"Config folder kept at {agent.config_dir}."]
