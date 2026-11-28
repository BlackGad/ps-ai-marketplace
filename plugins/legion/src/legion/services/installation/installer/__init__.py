# Install, update and remove Legion through the tool catalog.

import os
import re
import sys
from collections.abc import Callable
from contextlib import nullcontext
from functools import cmp_to_key
from pathlib import Path
from typing import Optional

import click
import httpx
from pydantic import ValidationError

from legion.services.installation import _user_path
from legion.services.lifecycle import _plugins, _targets
from legion.services.installation import _knowledge_hub
from legion.services.installation import _uv_tool
from legion.services.installation._update import compare_versions
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


def reconcile_knowledge(home: Path, catalog: ToolsCatalog, dry_run: bool, lines: list[str], progress: Callable[[str], None] | None = None) -> None:
    # Re-read the choice after acquiring the lock in case setup turned knowledge off during an update.
    with nullcontext() if dry_run else _settings_io.writer(home, require_existing=False):
        settings = _personalisation(home)
        if settings and settings.knowledge_enabled:
            _reconcile_knowledge(home, catalog, settings.agents, dry_run, lines, progress)


def _reconcile_knowledge(home: Path, catalog: ToolsCatalog, agents: list[Agent], dry_run: bool, lines: list[str], progress: Callable[[str], None] | None = None) -> None:
    pin = catalog.wiki
    if pin is None:
        return
    if progress is not None:
        _plugins.flush_progress(lines, progress)
        progress("Checking llm-wiki in registered accounts...")
    if not dry_run:
        try:
            _knowledge_hub.initialize(home, lines)
        except (OSError, ValueError, TypeError, RuntimeError) as error:
            lines.append(f"knowledge: hub setup failed: {error}")
    results: dict[tuple[str, str], str | None] = {}
    for agent in agents:
        try:
            target = _wiki_target(home, catalog, agent)
            if target is None:
                continue
            entry, folder = target
            if entry is None:
                raise InstallerError(f"{agent.tool} command is missing")
            key = entry.id, _targets.folder_key(folder)
            if key not in results:
                try:
                    _plugins.ensure(entry, folder, pin.source, pin.tag, dry_run, lines, pin=pin, progress=progress)
                    results[key] = None
                except (OSError, ValueError, TypeError, RuntimeError) as error:
                    results[key] = str(error)
            if results[key] is not None:
                lines.append(f"knowledge: {agent.id}: {results[key]}")
        except (OSError, ValueError, RuntimeError) as error:
            lines.append(f"knowledge: {agent.id}: {error}")
        _plugins.flush_progress(lines, progress)


# One row per tool and folder, so a long install ends with what happened where.
# Hand-built, reason: a three-column text table is plain str.ljust; no table library is pinned.
def _results_table(rows: list[tuple[str, str, str]]) -> list[str]:
    table = [("Tool", "Folder", "Result"), *rows]
    widths = [max(len(row[column]) for row in table) for column in (0, 1)]
    return ["Results:", *(f"{tool.ljust(widths[0])}  {folder.ljust(widths[1])}  {result}".rstrip() for tool, folder, result in table)]


# One uv install serves all update targets. The newest plugin version this update reached wins.
def newest_source(roots: list[tuple[str, Path]]) -> Path:
    return max(roots, key=cmp_to_key(lambda left, right: compare_versions(left[0], right[0])))[1]


def _install_tool(
    home: Path,
    roots: list[tuple[str, Path]],
    lines: list[str],
    rows: list[tuple[str, str, str]],
    dry_run: bool,
    *,
    updating: bool,
    update_shell: bool = False,
    progress: Callable[[str], None] | None = None,
) -> str | None:
    if not roots:
        return None
    root = newest_source(roots)
    try:
        lines.extend(_uv_tool.install(root, home, dry_run=dry_run, update_shell=update_shell, updating=updating, progress=progress))
    except Exception as error:
        rows.append(("legion", str(home), f"commands not refreshed: {error}"))
        return f"commands not refreshed: {error}; run legion setup"
    return None


def apply_hint(yes_flag: str = "--yes") -> str:
    return f"Run again with {yes_flag} to apply."


def _declined(lines: list[str]) -> list[str]:
    yes_flag = "-Yes" if os.environ.get("LEGION_BOOTSTRAP_POWERSHELL") == "1" else "--yes"
    return [*lines, f"Nothing changed. {apply_hint(yes_flag)}"]


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


def install(
    home: Path,
    tools: list[str] | None = None,
    source: str | Path = DEFAULT_SOURCE,
    ref: str = "release",
    config_dir: Path | None = None,
    dry_run: bool = False,
    yes: bool = False,
    update: bool = False,
    uninstall: bool = False,
    purge: bool = False,
    catalog: ToolsCatalog | None = None,
    with_knowledge: bool = True,
    tool_roots: list[tuple[str, Path]] | None = None,
    *,
    progress: Callable[[str], None] | None = None,
) -> list[str]:
    if update and uninstall:
        raise InstallerError("Choose either --update or --uninstall.")
    if purge and not uninstall:
        raise InstallerError("--purge requires --uninstall.")
    home = full_path(home)
    if update and not dry_run and tool_roots is None and sys.platform == "win32" and _stop_event.has_registered_ancestor(home):
        raise InstallerError("Close this Legion session, run `legion update` from a terminal, then reopen Legion.")
    if dry_run:
        progress = None
    if progress is not None:
        progress("Checking Legion installations...")
    catalog = load_catalog(source, ref, catalog)
    lines: list[str] = []
    settings = _personalisation(home, lines if uninstall else None)
    agents = settings.agents if settings else []
    selected = list(dict.fromkeys(part for word in (tools or []) for part in word.split(",") if part))
    targets_by_tool = {entry.id: _targets.folders(home, entry, agents, config_dir) for entry in catalog.tools if not selected or entry.id in selected}
    if not selected:
        selected = [tool_id for tool_id, folders in targets_by_tool.items() if uninstall or any(command for _, command in folders)]
    for tool_id in selected:
        catalog_tool(catalog, tool_id)
    knowledge_enabled = settings is not None and settings.knowledge_enabled is True
    if uninstall:
        wiki_folders = {(agent.tool, _targets.folder_key(_targets.account_folder(home, agent))) for agent in agents} if knowledge_enabled else set()
        _uninstall(home, catalog, selected, config_dir, purge, dry_run, yes, lines, targets_by_tool, catalog.wiki, wiki_folders, progress)
        return lines
    manage_knowledge = update and with_knowledge and knowledge_enabled
    if not selected:
        lines.append("No coding CLI is installed. Run legion setup to install one.")
        for entry in catalog.tools:
            lines.extend([f"skip: {entry.id} (not installed)", entry.install_hint])
        question = "Update the legion command with uv? [y/N]" if update else "Install the legion command with uv and add it to your PATH? [y/N]"
        if not dry_run and not (yes or _confirm(question, lines)):
            return _declined(lines)
        _plugins.flush_progress(lines, progress)
        if manage_knowledge:
            reconcile_knowledge(home, catalog, dry_run, lines, progress)
        _plugins.flush_progress(lines, progress)
        lines.extend(_uv_tool.install(PLUGIN_ROOT, home, dry_run=dry_run, update_shell=not update, updating=update, progress=progress))
        return lines
    if update:
        targets: list[tuple[CatalogTool, Path]] = []
        for tool_id in selected:
            entry = catalog_tool(catalog, tool_id)
            targets.extend(_tool_targets(entry, targets_by_tool[tool_id], lines))
        for entry, folder in targets:
            version = _targets.installed_version(folder, entry) or "not installed"
            lines.append(f"Update legion for {entry.id} in {folder} ({version})")
        if targets:
            lines.append("Running legion sessions (MCP servers and legion runs) end when the legion command is replaced.")
        if (targets or manage_knowledge) and not dry_run and not (yes or _confirm("Update legion? [y/N]", lines)):
            return _declined(lines)
        _plugins.flush_progress(lines, progress)
        rows: list[tuple[str, str, str]] = []
        roots: list[tuple[str, Path]] = []
        try:
            for entry, folder in targets:
                before = _plugins.ensure(entry, folder, source, ref, dry_run, lines, updating=True, progress=progress)
                before_version = before[0] if before else "not installed"
                if dry_run:
                    if before:
                        roots.append(before)
                else:
                    after = _plugins.verified_copy(entry, folder)
                    if after is None:
                        raise InstallerError(f"{entry.id} legion copy is missing after update; generated artifacts were not refreshed.")
                    after_version, after_root = after
                    lines.append(f"legion {before_version} -> {after_version}" if before_version != after_version else f"skip: legion {after_version} (already up to date)")
                    _plugins.flush_progress(lines, progress)
                    rows.append((entry.id, str(folder), f"{before_version} -> {after_version}" if before_version != after_version else f"already up to date ({after_version})"))
                    roots.append((after_version, after_root))
        except BaseException:
            # Plugins already updated need their legion command even when a later account fails.
            # The returned lines are lost with the error, so the install is reported before it propagates.
            failed: list[str] = []
            if tool_roots is None:
                failure = _install_tool(home, roots, failed, rows, dry_run, updating=True, progress=progress)
                if failure is not None:
                    failed.append(failure)
            else:
                tool_roots.extend(roots)
            for line in failed:
                click.echo(line, err=True)
            raise
        command_lines: list[str] = []
        failure = None
        try:
            if manage_knowledge:
                reconcile_knowledge(home, catalog, dry_run, lines, progress)
        finally:
            if tool_roots is None:
                _plugins.flush_progress(lines, progress)
                failure = _install_tool(home, roots, command_lines, rows, dry_run, updating=True, progress=progress)
            else:
                tool_roots.extend(roots)
        if targets and not dry_run:
            lines.extend(_results_table(rows))
        lines.extend(command_lines)
        if failure is not None:
            raise InstallerError(failure, lines=lines)
        return lines
    lines.append(f"Install legion for {', '.join(selected)}")
    if not dry_run and not (yes or _confirm(f"Install legion for {', '.join(selected)} now, and put the legion command on your PATH with uv? [y/N]", lines)):
        return _declined(lines)
    _plugins.flush_progress(lines, progress)
    installed_version = ""
    failure = None
    rows = []
    uv = _uv_tool.find_uv() if not dry_run else None
    from_tool = uv is not None and _uv_tool.running_from_tool(uv)
    deferred_roots: list[tuple[str, Path]] = []
    for tool_id in selected:
        entry = catalog_tool(catalog, tool_id)
        targets = _tool_targets(entry, targets_by_tool[tool_id], lines)
        if not targets:
            rows.append((tool_id, "-", "skipped (not installed)"))
        for target, folder in targets:
            _plugins.ensure(target, folder, source, ref, dry_run, lines, progress=progress)
            if not dry_run:
                try:
                    copy = _plugins.verified_copy(target, folder)
                except (OSError, ValueError):
                    copy = None
                if copy:
                    try:
                        installed_version, root = copy
                        if not from_tool:
                            _plugins.flush_progress(lines, progress)
                            lines.extend(_uv_tool.install(root, home, update_shell=True, progress=progress))
                            _plugins.flush_progress(lines, progress)
                        if from_tool:
                            deferred_roots.append((installed_version, root))
                        rows.append((tool_id, str(folder), f"installed legion {installed_version}"))
                    except Exception as error:
                        failure = f"commands not refreshed for {tool_id} in {folder}: {error}; run legion setup"
                        rows.append((tool_id, str(folder), f"commands not refreshed: {error}"))
                else:
                    failure = f"commands not refreshed for {tool_id} in {folder}; run legion setup"
                    rows.append((tool_id, str(folder), "commands not refreshed"))
        if entry.hooks.hint:
            lines.append(entry.hooks.hint)
        _plugins.flush_progress(lines, progress)
    if dry_run:
        lines.extend(_uv_tool.install(PLUGIN_ROOT, home, dry_run=True, update_shell=True))
    else:
        _plugins.flush_progress(lines, progress)
        failure = _install_tool(home, deferred_roots, lines, rows, dry_run, updating=False, update_shell=True, progress=progress) or failure
        lines.extend(_results_table(rows))
        if failure is not None:
            raise InstallerError(failure, lines=lines)
    if installed_version and not dry_run:
        lines.append("next: legion add claude (or legion in a repository)")
        lines.append(f"installed: legion {installed_version} ({ref})")
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
