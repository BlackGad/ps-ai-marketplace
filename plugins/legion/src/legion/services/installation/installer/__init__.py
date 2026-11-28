# Uninstall Legion through the tool catalog.

import os
import re
from collections.abc import Callable
from pathlib import Path
from typing import Optional

import click
import httpx
from pydantic import ValidationError

from legion.services.installation import _user_path
from legion.services.lifecycle import _plugins, _targets
from legion.services.installation import _knowledge_hub
from legion.services.installation import _uv_tool
from legion.core import _settings_io, _stop_event
from legion.core._http import HttpsError, failure_text, get_bytes
from legion.core._home import (
    full_path,
    is_reparse,
    owner_path_safe,
    run_folder,
    settings_path,
)
from legion.core._plugin import PLUGIN_ROOT
from legion.core._settings_models import (
    Agent,
    CatalogTool,
    PersonalisationSettings,
    PluginPin,
    ToolsCatalog,
)


DEFAULT_SOURCE = "BlackGad/ps-legion-marketplace"


class InstallerError(ValueError):
    def __init__(self, message: str, *, lines: list[str] | None = None) -> None:
        super().__init__(message)
        self.lines = lines if lines is not None else []


def load_catalog(source: str | Path, ref: str, catalog: ToolsCatalog | None = None) -> ToolsCatalog:
    if catalog is not None:
        return catalog
    if Path(source).is_dir():
        data = (Path(source) / "plugins/legion/tools.json").read_bytes()
    elif str(source) == DEFAULT_SOURCE and ref != "main":
        data = (PLUGIN_ROOT / "tools.json").read_bytes()
    elif re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", str(source)):
        branch = "main" if ref == "main" else "stable"
        url = f"https://raw.githubusercontent.com/{source}/{branch}/plugins/legion/tools.json"
        try:
            data = get_bytes(url, 30)
        except (HttpsError, httpx.HTTPError) as error:
            raise InstallerError(f"could not read the tools catalog {url}: {failure_text(error)}") from error
    else:
        raise InstallerError(f"unsupported marketplace source '{source}'")
    try:
        return ToolsCatalog.model_validate_json(data)
    except ValidationError as error:
        raise InstallerError(f"invalid tools catalog: {error}") from error


def catalog_tool(catalog: ToolsCatalog, tool_id: str) -> CatalogTool:
    for entry in catalog.tools:
        if entry.id == tool_id:
            return entry
    raise InstallerError(f"unknown tool '{tool_id}'")


def _personalisation(home: Path, skip_lines: Optional[list[str]] = None) -> PersonalisationSettings | None:
    path = settings_path(home)
    if not path.exists():
        return None
    try:
        return _settings_io.load_unchecked(home)
    except _settings_io.SettingsError as error:
        if skip_lines is None:
            raise InstallerError(f"Fix invalid settings in {path}: {error}") from error
        reason = " ".join(str(error).split()).split("; ", 1)[0]
        skip_lines.append(f"skip: account folders (settings invalid: {reason})")
        return None


def _wiki_target(home: Path, catalog: ToolsCatalog, agent: Agent) -> tuple[CatalogTool | None, Path] | None:
    entry = catalog_tool(catalog, agent.tool)
    folder = _targets.account_folder(home, agent)
    if _targets.is_default_folder(home, entry, folder):
        return None
    command = _targets.account_command(home, entry, agent.command)
    return (entry.model_copy(update={"command": command}) if command else None), folder


def remove_knowledge(home: Path, catalog: ToolsCatalog, agents: list[Agent], lines: list[str], progress: Callable[[str], None] | None = None) -> None:
    pin = catalog.wiki
    if pin is None:
        return
    seen: set[tuple[str, str]] = set()
    for agent in agents:
        try:
            target = _wiki_target(home, catalog, agent)
            if target is None:
                continue
            entry, folder = target
            if entry is None:
                lines.append(f"skip: knowledge: {agent.id} ({agent.tool} command is missing)")
                _plugins.flush_progress(lines, progress)
                continue
            key = entry.id, _targets.folder_key(folder)
            if key not in seen:
                for arguments in _plugins.removal_steps(entry, folder, pin):
                    _plugins.run_step(entry, arguments, folder, False, lines, progress)
                seen.add(key)
        except (OSError, ValueError) as error:
            raise InstallerError(f"knowledge: {agent.id}: {error}") from error


def _tool_targets(entry: CatalogTool, folders: list[tuple[Path, str | None]], lines: list[str], *, hint: bool = True) -> list[tuple[CatalogTool, Path]]:
    if not any(command for _, command in folders):
        lines.append(f"skip: {entry.id} (not installed)")
        if hint:
            lines.append(entry.install_hint)
        return []
    targets = []
    for folder, command in folders:
        if command is None:
            lines.append(f"skip: {entry.id} in {folder} (no command for this folder)")
        else:
            targets.append((entry.model_copy(update={"command": command}), folder))
    return targets


def uninstall(
    home: Path,
    tools: list[str] | None = None,
    source: str | Path = DEFAULT_SOURCE,
    ref: str = "release",
    config_dir: Path | None = None,
    dry_run: bool = False,
    yes: bool = False,
    purge: bool = False,
    catalog: ToolsCatalog | None = None,
    *,
    progress: Callable[[str], None] | None = None,
) -> list[str]:
    home = full_path(home)
    if dry_run:
        progress = None
    if progress is not None:
        progress("Checking Legion installations...")
    catalog = load_catalog(source, ref, catalog)
    lines: list[str] = []
    settings = _personalisation(home, lines)
    agents = settings.agents if settings else []
    selected = list(dict.fromkeys(part for word in (tools or []) for part in word.split(",") if part))
    targets = {entry.id: _targets.folders(home, entry, agents, config_dir) for entry in catalog.tools if not selected or entry.id in selected}
    for tool_id in selected:
        catalog_tool(catalog, tool_id)
    wiki_folders = {(agent.tool, _targets.folder_key(_targets.account_folder(home, agent))) for agent in agents} if settings and settings.knowledge_enabled else set()
    _uninstall(home, catalog, selected or list(targets), config_dir, purge, dry_run, yes, lines, targets, catalog.wiki, wiki_folders, progress)
    return lines


def _confirm(question: str, lines: list[str]) -> bool:
    for line in lines:
        print(line)
    lines.clear()
    try:
        return click.confirm(question, default=False, prompt_suffix=" ", show_default=False)
    except click.Abort:
        return False


def _uninstall(
    home: Path,
    catalog: ToolsCatalog,
    selected: list[str],
    config_dir: Optional[Path],
    purge: bool,
    dry_run: bool,
    yes: bool,
    lines: list[str],
    targets_by_tool: dict[str, list[tuple[Path, str | None]]],
    pin: PluginPin | None,
    wiki_folders: set[tuple[str, str]],
    progress: Callable[[str], None] | None,
) -> None:
    # The tools' own commands remove the plugin and marketplace; nothing in a tool's files is edited here.
    steps: list[tuple[CatalogTool, Path, list[str], bool]] = []
    preview = progress is None or not yes
    for tool_id in selected:
        entry = catalog_tool(catalog, tool_id)
        for target, folder in _tool_targets(entry, targets_by_tool[tool_id], lines, hint=False):
            removal = _plugins.removal_steps(target, folder)
            for what, arguments in (("plugin", entry.plugin.uninstall), ("marketplace", entry.plugin.marketplace_remove)):
                if arguments not in removal:
                    lines.append(f"skip: {tool_id} {what} in {folder} (not installed)")
            steps.extend((target, folder, arguments, False) for arguments in removal)
            if preview:
                lines.extend(_plugins.command_line(target, arguments, folder) for arguments in removal)
            if pin is not None and (tool_id, _targets.folder_key(folder)) in wiki_folders and not _targets.is_default_folder(home, entry, folder):
                try:
                    for arguments in _plugins.removal_steps(target, folder, pin):
                        steps.append((target, folder, arguments, True))
                        if preview:
                            lines.append(_plugins.command_line(target, arguments, folder))
                except (OSError, ValueError) as error:
                    lines.append(f"knowledge: {tool_id} in {folder}: {error}")
    # Only an uninstall of every tool, without --config-dir, removes legion's own folders.
    everything = config_dir is None and {entry.id for entry in catalog.tools} <= set(selected)
    if purge and not everything:
        raise InstallerError("--purge removes all of legion; run it without --tool and --config-dir.")
    folders = _legion_folders(home, purge, with_knowledge=False) if everything else []
    lines.extend(f"Remove folder: {folder}" for folder in folders)
    path_lines = _user_path.remove(home, purge, dry_run=True) if everything else []
    tool_lines = _uv_tool.uninstall(home, dry_run=True) if everything else []
    hub = everything and purge and os.path.lexists(home / ".legion/knowledge")
    if everything:
        lines.extend(path_lines or ["skip: path (already done)"])
        lines.extend(tool_lines)
        if hub:
            lines.append("Asked separately: the knowledge hub in ~/.legion/knowledge")
    if not (steps or folders or path_lines or tool_lines or hub):
        lines.append("skip: uninstall (already done)")
        return
    if dry_run:
        return
    if not (yes or _confirm("Purge legion and all its data now? [y/N]" if purge else "Uninstall legion now? [y/N]", lines)):
        lines.append("Uninstall cancelled.")
        return
    _plugins.flush_progress(lines, progress)
    stopped = everything and (bool(tool_lines) or (owner_path_safe(_stop_event.stop_path(home), home) and run_folder(home).is_dir()))
    if stopped:
        if progress is not None:
            progress("Waiting for running Legion sessions to exit...")
        _uv_tool.stop_running(home)
    handed_over = False
    try:
        failed_wiki: set[tuple[str, Path]] = set()
        for entry, folder, arguments, wiki in steps:
            if not wiki:
                _plugins.run_step(entry, arguments, folder, False, lines, progress)
            elif (entry.id, folder) not in failed_wiki:
                try:
                    _plugins.run_step(entry, arguments, folder, False, lines, progress)
                except (OSError, ValueError) as error:
                    failed_wiki.add((entry.id, folder))
                    lines.append(f"knowledge: {entry.id} in {folder}: {error}")
        if everything:
            lines.extend(_user_path.remove(home, purge))
            _plugins.flush_progress(lines, progress)
            with_knowledge = hub and _confirm("Also delete the knowledge hub in ~/.legion/knowledge? [y/N]", lines)
            if with_knowledge:
                _knowledge_hub.purge(home, lines)
            remaining = _legion_folders(home, purge, with_knowledge)
            result = _uv_tool.uninstall(home, stopped=stopped, purge=remaining)
            handed_over = bool(result)
            lines.extend(result)
            if not result:
                lines.append("done: legion is uninstalled")
        else:
            lines.append("done: legion is uninstalled from the selected accounts")
    finally:
        if stopped and not handed_over:
            _stop_event.clear_stop(home)


# Deleting never follows a link: a linked folder is removed as the link only.
def _legion_folders(home: Path, purge: bool, with_knowledge: bool) -> list[Path]:
    if not purge:
        return []
    legion = home / ".legion"
    knowledge = legion / "knowledge"
    if is_reparse(legion) or with_knowledge or not os.path.lexists(knowledge):
        return [legion] if os.path.lexists(legion) else []
    return [child for child in legion.iterdir() if child != knowledge]
