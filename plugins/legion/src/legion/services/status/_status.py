from __future__ import annotations

import os
import re
import stat
import sys
from pathlib import Path
from typing import TYPE_CHECKING, Literal, Optional

import psutil
from pydantic import BaseModel, Field, JsonValue

from legion.core import _process
from legion.core._generated import is_owned
from legion.core._home import home_path, path_contains
from legion.core._settings_models import (
    ChannelDescriptor,
    PersonalisationSettings,
    PluginManifest,
    ToolDescriptor,
)
from legion.services.installation._update import compare_versions
from legion.core._validate import load_descriptors, read_text

if TYPE_CHECKING:
    from legion.services.status import RepositoryStatus, StatusReport


class MarketplaceSource(BaseModel):
    source: str
    path: Path


class MarketplaceRegistration(BaseModel):
    source: MarketplaceSource


class CopilotMarketplaces(BaseModel):
    legion: MarketplaceRegistration = Field(alias="ps-legion-marketplace")


class CopilotSettings(BaseModel):
    enabled_plugins: dict[str, JsonValue] = Field(alias="enabledPlugins")
    marketplaces: CopilotMarketplaces = Field(alias="extraKnownMarketplaces")


class MarketplacePlugin(BaseModel):
    name: str
    source: JsonValue


class Marketplace(BaseModel):
    plugins: list[MarketplacePlugin]


def _copilot_manifest(folder: Path) -> Optional[Path]:
    try:
        settings = CopilotSettings.model_validate_json(read_text(folder / "settings.json"))
        if "legion@ps-legion-marketplace" not in settings.enabled_plugins:
            return None
        source = settings.marketplaces.legion.source
        if source.source != "directory":
            return None
        marketplace = Marketplace.model_validate_json(read_text(source.path / ".claude-plugin" / "marketplace.json"))
        for plugin in marketplace.plugins:
            if plugin.name == "legion" and isinstance(plugin.source, str):
                return source.path / plugin.source / "plugin.json"
    except (OSError, ValueError):
        pass
    return None


def installed_version(folder: Path, tool: ToolDescriptor) -> Optional[str]:
    files = list((folder / tool.plugin.installed_root).rglob("plugin.json")) if tool.plugin.installed_root else []
    local = _copilot_manifest(folder) if tool.id == "copilot" else None
    if local is not None:
        files = [local]
    highest = None
    for file in files:
        try:
            manifest = PluginManifest.model_validate_json(read_text(file))
            if manifest.name != "legion":
                continue
            newer = compare_versions(manifest.version, highest or manifest.version) > 0
            if highest is None or newer:
                highest = manifest.version
        except (OSError, ValueError):
            pass  # Interrupted installs can leave incomplete manifests beside working versions.
    return highest


# The state of each legion command file: missing, blocked (another file is there), permission or owned.
def command_states(folder: Path) -> list[tuple[Path, str]]:
    states = []
    for suffix in ("", ".cmd") if sys.platform == "win32" else ("",):
        path = folder / f"legion{suffix}"
        if not path.exists():
            states.append((path, "missing"))
            continue
        try:
            if not is_owned(path, "owner command"):
                states.append((path, "blocked"))
            elif sys.platform != "win32" and not path.stat().st_mode & stat.S_IXUSR:
                states.append((path, "permission"))
            else:
                states.append((path, "owned"))
        except (OSError, ValueError):
            states.append((path, "blocked"))
    return states


def command_status(folder: Path) -> Literal["yes", "blocked", "missing", "not executable"]:
    states = [state for _path, state in command_states(folder)]
    if "blocked" in states:
        return "blocked"
    if "missing" in states:
        return "missing"
    if "permission" in states:
        return "not executable"
    return "yes"


def _path_key(path: Path) -> str:
    # Resolve linked ancestors before applying the platform's path comparer.
    return os.path.normcase(str(path.resolve()))


def on_path(folder: Path) -> bool:
    return path_contains(os.environ.get("PATH", ""), folder)


def repository_line(repository: RepositoryStatus) -> str:
    if repository.mode == "none":
        return "repo none"
    return f"repo {repository.mode}   lease: {repository.lease}   handoff: {'yes' if repository.handoff else 'no'}"


def _read_command_line(pid: int) -> str:
    try:
        return " ".join(psutil.Process(pid).cmdline())
    except psutil.Error:
        return ""


def _session() -> Optional[tuple[str, str]]:
    if sys.platform != "win32":
        return None
    owner = _process.owner_process()
    return owner.name.removesuffix(".exe"), _read_command_line(owner.pid)


def channel_warnings(settings: PersonalisationSettings, home: Path, tools: list[ToolDescriptor]) -> list[str]:
    if os.environ.get("LEGION_ROLE", "").lower() == "member" and os.environ.get("LEGION_TASK"):
        return []
    try:
        if not any(os.environ.get(tool.config_env) for tool in tools):
            return []
        session = _session()
        if not session or not session[1]:
            return []
        matches = [tool for tool in tools if tool.command == session[0] and os.environ.get(tool.config_env)]
        if len(matches) != 1:
            return []
        tool = matches[0]
        folder = _path_key(home_path(os.environ[tool.config_env], home))
        accounts = [agent for agent in settings.agents if agent.tool == tool.id and _path_key(home_path(agent.config_dir, home)) == folder]
        if len(accounts) != 1:
            return []
        descriptors = load_descriptors(ChannelDescriptor, "channel.json")
        warnings = []
        for channel in settings.channels:
            if accounts[0].id not in channel.accounts:
                continue
            kinds = [kind for kind in descriptors if kind.id == channel.kind]
            launch = kinds[0].launch.get(tool.id, []) if len(kinds) == 1 else []
            if not launch or not re.match(r"^--?[a-z]", launch[0]) or launch[0] in session[1]:
                continue
            warnings.append(f"legion: channel {channel.id} is bound to this account but not connected in this session; restart with legion to connect it.")
        return warnings
    except Exception:
        return []  # Uncertain sessions and descriptors must never interrupt status or warn.


def status_lines(report: StatusReport) -> list[str]:
    settings = report.settings
    if settings.state == "ok":
        lines = ["accounts", *(f"  {agent.id}  {agent.tool}  {agent.config_dir}  legion {agent.legion_version or 'missing'}" for agent in report.accounts)]
    elif settings.state == "missing":
        lines = ["no legion settings yet"]
    else:
        problem = "cannot be read" if settings.state == "unreadable" else "are not valid"
        lines = [f"legion settings {problem}: {settings.path}; run legion setup"]
    commands = "yes" if report.commands == "yes" else f"{report.commands} legion"
    lines.extend([f"path ~/.legion/bin on PATH: {'yes' if report.on_path else 'no'}", f"commands: {commands}"])
    lines.extend(f"channels {channel.id} ({channel.kind}) -> {', '.join(channel.accounts)}" for channel in report.channels)
    lines.extend([repository_line(report.repository), *report.warnings])
    return lines
