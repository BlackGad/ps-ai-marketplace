# Install, update and remove Legion through the tool catalog.

import json
import os
import re
import shutil
import sys
import tempfile
from functools import cmp_to_key
from pathlib import Path
from typing import Optional

import click
import httpx
from pydantic import ValidationError

from legion.services.accounts._launchers import command_prefix, registered_command
from legion.services.installation import _user_path
from legion.services.installation import _installed_runtime
from legion.services.installation import _handover
from legion.services.installation import _refresh
from legion.services.installation._update import compare_versions
from legion.core import _settings_io
from legion.core._http import HttpsError, failure_text, get_bytes
from legion.core._home import (
    bin_folder,
    full_path,
    is_reparse,
    is_under,
    path_contains,
    resolve_directory,
    same_path,
    settings_path,
)
from legion.core._plugin import PLUGIN_ROOT
from legion.core._run import display_command, run_command
from legion.core._settings_models import (
    Agent,
    CatalogTool,
    JsonListing,
    ToolsCatalog,
)


DEFAULT_SOURCE = "BlackGad/ps-legion-marketplace"


class InstallerError(ValueError):
    pass


def _catalog(source: str | Path, ref: str, catalog: Optional[ToolsCatalog]) -> ToolsCatalog:
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


def _tool(catalog: ToolsCatalog, tool_id: str) -> CatalogTool:
    for entry in catalog.tools:
        if entry.id == tool_id:
            return entry
    raise InstallerError(f"unknown tool '{tool_id}'")


def _config_path(home: Path, value: str) -> Path:
    if value == "~":
        return full_path(home)
    if value.startswith(("~/", "~\\")):
        return full_path(home / value[2:])
    return full_path(Path(value))


def _agents(home: Path, skip_lines: Optional[list[str]] = None) -> list[Agent]:
    path = settings_path(home)
    if not path.exists():
        return []
    try:
        return _settings_io.load_unchecked(home).agents
    except _settings_io.SettingsError as error:
        if skip_lines is None:
            raise InstallerError(f"Fix invalid settings in {path}: {error}") from error
        reason = " ".join(str(error).split()).split("; ", 1)[0]
        skip_lines.append(f"skip: account folders (settings invalid: {reason})")
        return []


def _target_tool(home: Path, entry: CatalogTool, agents: list[Agent], folder: Optional[Path] = None) -> Optional[CatalogTool]:
    if folder is not None:
        folder = resolve_directory(folder)
    for agent in agents:
        if agent.tool != entry.id:
            continue
        command = registered_command(agent, home)
        if command is None:
            continue
        if folder is None or same_path(folder, resolve_directory(_config_path(home, agent.config_dir))):
            return entry.model_copy(update={"command": str(command)})
    return entry if shutil.which(entry.command) else None


def _folders(home: Path, entry: CatalogTool, selected: Path | None, agents: list[Agent]) -> list[Path]:
    if selected is not None:
        return [full_path(selected)]
    folders: list[Path] = []
    for agent in agents:
        if agent.tool == entry.id:
            folder = _config_path(home, agent.config_dir)
            if not any(same_path(folder, previous) for previous in folders):
                folders.append(folder)
    override = os.getenv(entry.config_env)
    if override and not same_path(home, Path.home()) and not is_under(_config_path(home, override), home, allow_equal=True):
        override = None
    value = override or entry.plugin.default_config_dir
    if value:
        default = _config_path(home, value)
        if not any(same_path(default, previous) for previous in folders):
            folders.insert(0, default)
    return folders


def ensure_path(home: Path, dry_run: bool, lines: list[str]) -> None:
    bin_path = bin_folder(home)
    if sys.platform == "win32":
        if not dry_run and not path_contains(os.environ.get("PATH", ""), bin_path):
            os.environ["PATH"] = str(bin_path) + os.pathsep + os.environ.get("PATH", "")
        added = not path_contains(_user_path.user_path(), bin_path) if dry_run else _user_path.add(home, bin_path)
        lines.append(f"add {bin_path} to your user PATH" if added else "skip: path (already done)")
        return
    try:
        lines.extend(_user_path.shell_profile_lines(home, dry_run=dry_run))
    except _user_path.PathError as error:
        raise InstallerError(str(error)) from None


def _execute(entry: CatalogTool, arguments: list[str], folder: Path, listing: bool = False) -> str:
    env = dict(os.environ)
    env[entry.config_env] = str(folder)
    if listing:
        env.update(entry.plugin.listing_env or {})
    command = entry.command if Path(entry.command).is_absolute() else shutil.which(entry.command) or entry.command
    program, prefix = command_prefix(Path(command))
    result = run_command(str(program), [*prefix, *arguments], env=env, cwd=Path(tempfile.gettempdir()))
    if result.exit_code:
        detail = result.error.strip() or result.output.strip()
        raise InstallerError(f"{entry.command} {'listing ' if listing else ''}exited {result.exit_code}" + (f"\n{detail}" if detail else ""))
    return result.output


def _listing(entry: CatalogTool, folder: Path, kind: str) -> str:
    if not folder.is_dir():
        return ""
    arguments = entry.plugin.marketplace_list if kind == "marketplace" else entry.plugin.list_command
    return _execute(entry, arguments, folder, listing=True)


def _marketplace(entry: CatalogTool, folder: Path, require_root: bool = False) -> bool:
    output = _listing(entry, folder, "marketplace")
    if not output:
        return False
    try:
        data = json.loads(output)
        listing = entry.plugin.marketplace_listing
        if listing.collection_field is not None:
            data = data[listing.collection_field]
        for item in data:
            if item.get(listing.name_field) == "ps-legion-marketplace":
                if require_root and listing.root_field is not None:
                    root = item.get(listing.root_field)
                    return isinstance(root, str) and bool(root) and Path(root).is_dir()
                return True
        return False
    except (ValueError, TypeError, KeyError) as error:
        raise InstallerError(f"{entry.id} marketplace listing returned invalid JSON") from error


# The id is the first word of a listing row, or the second after a bullet in any spelling (the Windows console may print it as other
# characters). A continuation line such as "from <path>" has none. tests/integration/run.py keeps an identical copy.
def _row_id(line: str) -> Optional[str]:
    words = line.split()
    if words and "@" in words[0]:
        return words[0]
    if len(words) > 1 and "@" in words[1] and words[0].rstrip(":") != "from":
        return words[1]
    return None


# Hand-built, reason: the three CLIs expose different listing formats described by tools.json.
def _plugin_state(entry: CatalogTool, folder: Path) -> tuple[bool, bool, list[Path], str]:
    output = _listing(entry, folder, "plugin")
    if not output:
        return False, False, [], ""
    listing = entry.plugin.listing
    paths: list[Path] = []
    version = ""
    if isinstance(listing, JsonListing):
        try:
            items = json.loads(output)
        except ValueError as error:
            raise InstallerError(f"{entry.id} plugin listing returned invalid JSON") from error
        matches = [item for item in items if item.get(listing.id_field) == "legion@ps-legion-marketplace" and isinstance(item.get(listing.enabled_field), bool)]
        for item in matches:
            if item.get("installPath"):
                paths.append(Path(item["installPath"]))
            version = item.get("version") or version
        return bool(matches), any(item[listing.enabled_field] for item in matches), paths, version
    lines = [line for line in output.splitlines() if _row_id(line) == "legion@ps-legion-marketplace" and "not installed" not in line]
    for line in lines:
        match = re.search(r"\b(v?\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\b", line)
        if match:
            version = match[1].removeprefix("v")
        match = re.search(r"\s((?:[A-Za-z]:[/\\]|/).+?)\s*$", line)
        if match:
            paths.append(Path(match[1]))
    return bool(lines), any(not re.search(listing.reject_pattern, line) for line in lines), paths, version


def _plugin_root(entry: CatalogTool, folder: Path) -> Path | None:
    listed, _, paths, version = _plugin_state(entry, folder)
    if not listed:
        return None
    settings_path = folder / "settings.json"
    configured_source = None
    if entry.id == "copilot":
        is_legion = False
        if settings_path.is_file():
            try:
                settings = json.loads(settings_path.read_text(encoding="utf-8-sig"))
                source = settings["extraKnownMarketplaces"]["ps-legion-marketplace"]["source"]
                if source["source"] == "directory" and isinstance(source["path"], str) and isinstance(settings["enabledPlugins"]["legion@ps-legion-marketplace"], bool):
                    configured_source = Path(source["path"])
            except (OSError, ValueError, TypeError, KeyError):
                pass
        for line in _listing(entry, folder, "plugin").splitlines():
            row = _row_id(line)
            if row is not None:
                is_legion = row == "legion@ps-legion-marketplace" and "not installed" not in line
            elif line.strip() and not line[:1].isspace():
                is_legion = False
            marketplace = re.match(r"^\s+from (.+?)\s*$", line) if is_legion else None
            if marketplace is None:
                continue
            try:
                root = Path(marketplace[1])
                if settings_path.is_file() and configured_source is None:
                    continue
                if configured_source is not None and not same_path(resolve_directory(root), resolve_directory(configured_source)):
                    continue
                data = json.loads((root / ".claude-plugin/marketplace.json").read_text(encoding="utf-8-sig"))
                if data.get("name") != "ps-legion-marketplace":
                    continue
                for plugin in data["plugins"]:
                    if plugin.get("name") == "legion" and isinstance(plugin.get("source"), str):
                        path = root / plugin["source"]
                        if is_under(resolve_directory(path), resolve_directory(root)):
                            paths.append(path)
            except (OSError, ValueError, TypeError, KeyError):
                continue
    if not paths and entry.plugin.installed_root:
        root = folder / entry.plugin.installed_root
        if root.is_dir():
            paths = [path.parent for path in root.rglob("plugin.json") if path.parent.name not in (".claude-plugin", ".codex-plugin")]
    if entry.id == "copilot" and not paths and settings_path.is_file() and configured_source is None:
        return None
    roots = []
    for path in set(paths):
        try:
            manifest = json.loads((path / "plugin.json").read_text(encoding="utf-8-sig"))
            if manifest.get("name") == "legion" and (not version or manifest.get("version") == version):
                roots.append(path)
        except (OSError, ValueError):
            continue
    if len(roots) != 1:
        raise InstallerError(f"{entry.id} installed legion folder could not be identified uniquely.")
    return roots[0]


def _command_line(entry: CatalogTool, arguments: list[str], folder: Path) -> str:
    program, prefix = command_prefix(Path(entry.command))
    return f"{entry.config_env}={display_command([str(folder)])} {display_command([str(program), *prefix, *arguments])}"


def _step(entry: CatalogTool, arguments: list[str], folder: Path, dry_run: bool, lines: list[str]) -> None:
    line = _command_line(entry, arguments, folder)
    if dry_run:
        lines.append(line)
    else:
        output = _execute(entry, arguments, folder)
        lines.extend(output.splitlines())


def _install_steps(entry: CatalogTool, folder: Path, source: str | Path, ref: str, dry_run: bool, lines: list[str]) -> None:
    plugin = entry.plugin
    branch = "main" if ref == "main" else "stable"
    local = Path(source).is_dir()
    if local:
        source = Path(source).resolve().as_posix()
    template = plugin.marketplace_add if local else plugin.marketplace_add_ref
    marketplace_add = [word.replace("{source}", str(source)).replace("{ref}", branch) for word in template]
    installed = _marketplace(entry, folder)
    listed, enabled, _, _ = _plugin_state(entry, folder)
    if installed and enabled and _marketplace(entry, folder, require_root=True):
        lines.extend(f"skip: {display_command([entry.command, *arguments])} (already done)" for arguments in (marketplace_add, plugin.install))
        return
    if not installed:
        _step(entry, marketplace_add, folder, dry_run, lines)
    if plugin.marketplace_update:
        _step(entry, plugin.marketplace_update, folder, dry_run, lines)
    if not installed or not listed or not enabled:
        _step(entry, plugin.install, folder, dry_run, lines)


# One row per tool and folder, so a long install ends with what happened where.
# Hand-built, reason: a three-column text table is plain str.ljust; no table library is pinned.
def _results_table(rows: list[tuple[str, str, str]]) -> list[str]:
    table = [("Tool", "Folder", "Result"), *rows]
    widths = [max(len(row[column]) for row in table) for column in (0, 1)]
    return ["Results:", *(f"{tool.ljust(widths[0])}  {folder.ljust(widths[1])}  {result}".rstrip() for tool, folder, result in table)]


# This process is the old version: the newest version this update confirmed writes the files again with its own templates, once.
def _hand_over(home: Path, confirmed: list[str], lines: list[str], rows: list[tuple[str, str, str]]) -> None:
    if not confirmed:
        return
    version = max(confirmed, key=cmp_to_key(compare_versions))
    try:
        lines.extend(_installed_runtime.refresh_with_new_app(home, version))
    except Exception as error:
        lines.append(f"commands not refreshed: {error}; run legion setup")
        rows.append(("legion", str(home), f"commands not refreshed: {error}"))


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
) -> list[str]:
    if update and uninstall:
        raise InstallerError("Choose either --update or --uninstall.")
    if purge and not uninstall:
        raise InstallerError("--purge requires --uninstall.")
    home = full_path(home)
    catalog = _catalog(source, ref, catalog)
    lines: list[str] = []
    agents = _agents(home, lines if uninstall else None)
    selected = list(dict.fromkeys(part for word in (tools or []) for part in word.split(",") if part))
    if not selected:
        selected = [entry.id for entry in catalog.tools if uninstall or _target_tool(home, entry, agents) is not None]
    for tool_id in selected:
        _tool(catalog, tool_id)
    if uninstall:
        _uninstall(home, catalog, selected, config_dir, purge, dry_run, yes, lines, agents)
        return lines
    if not selected:
        lines.append("No coding CLI is installed. Run legion setup to install one.")
        for entry in catalog.tools:
            lines.extend([f"skip: {entry.id} (not installed)", entry.install_hint])
        if not dry_run and not (yes or _confirm("Install the legion command and add ~/.legion/bin to your PATH? [y/N]", lines)):
            return [*lines, "Nothing changed. Run again with --yes to apply."]
        ensure_path(home, dry_run, lines)
        if not dry_run:
            lines.extend(_refresh.refresh(home, source=PLUGIN_ROOT))
        return lines
    if update:
        targets: list[tuple[CatalogTool, Path]] = []
        for tool_id in selected:
            entry = _tool(catalog, tool_id)
            if _target_tool(home, entry, agents) is None:
                lines.extend([f"skip: {tool_id} (not installed)", entry.install_hint])
                continue
            for folder in _folders(home, entry, config_dir, agents):
                target = _target_tool(home, entry, agents, folder)
                if target is None:
                    lines.append(f"skip: {tool_id} in {folder} (no command for this folder)")
                    continue
                targets.append((target, folder))
        for entry, folder in targets:
            root = _plugin_root(entry, folder)
            version = json.loads((root / "plugin.json").read_text(encoding="utf-8"))["version"] if root else "not installed"
            lines.append(f"Update legion for {entry.id} in {folder} ({version})")
        if targets and not dry_run and not (yes or _confirm("Update legion? [y/N]", lines)):
            return [*lines, "Nothing changed. Run again with --yes to apply."]
        rows: list[tuple[str, str, str]] = []
        confirmed: list[str] = []
        try:
            for entry, folder in targets:
                before = _plugin_root(entry, folder)
                before_version = json.loads((before / "plugin.json").read_text(encoding="utf-8"))["version"] if before else "not installed"
                if before:
                    for arguments in (entry.plugin.marketplace_update, entry.plugin.update):
                        if arguments:
                            _step(entry, arguments, folder, dry_run, lines)
                else:
                    _install_steps(entry, folder, source, ref, dry_run, lines)
                if not dry_run:
                    after = _plugin_root(entry, folder)
                    if after is None:
                        raise InstallerError(f"{entry.id} legion is absent from the post-update listing; generated artifacts were not refreshed.")
                    try:
                        lines.extend(_refresh.refresh(home, source=after))
                    except Exception as error:
                        lines.append(f"commands not refreshed for {entry.id} in {folder}: {error}; run legion setup")
                        rows.append((entry.id, str(folder), f"commands not refreshed: {error}"))
                        continue
                    after_version = json.loads((after / "plugin.json").read_text(encoding="utf-8"))["version"]
                    lines.append(f"legion {before_version} -> {after_version}" if before_version != after_version else f"skip: legion {after_version} (already up to date)")
                    rows.append((entry.id, str(folder), f"{before_version} -> {after_version}" if before_version != after_version else f"already up to date ({after_version})"))
                    confirmed.append(after_version)
        except BaseException:
            # Versions already published keep their old templates unless the new app writes them, even when a later account fails.
            # The returned lines are lost with the error, so a failed handoff is printed before it propagates.
            handover: list[str] = []
            _hand_over(home, confirmed, handover, rows)
            for line in handover:
                click.echo(line, err=True)
            raise
        _hand_over(home, confirmed, lines, rows)
        if targets and not dry_run:
            lines.extend(_results_table(rows))
            lines.append("done: restart your sessions; run legion in the repository")
        return lines
    lines.append(f"Install legion for {', '.join(selected)}")
    path_description = "user PATH" if sys.platform == "win32" else "shell profile PATH"
    if not dry_run and not (yes or _confirm(f"Install legion for {', '.join(selected)} now, and add ~/.legion/bin to your {path_description}? [y/N]", lines)):
        return [*lines, "Nothing changed. Run again with --yes to apply."]
    ensure_path(home, dry_run, lines)
    installed_version = ""
    rows = []
    for tool_id in selected:
        entry = _tool(catalog, tool_id)
        if _target_tool(home, entry, agents) is None:
            lines.extend([f"skip: {tool_id} (not installed)", entry.install_hint])
            rows.append((tool_id, "-", "skipped (not installed)"))
            continue
        for folder in _folders(home, entry, config_dir, agents):
            target = _target_tool(home, entry, agents, folder)
            if target is None:
                lines.append(f"skip: {tool_id} in {folder} (no command for this folder)")
                continue
            if not dry_run:
                folder.mkdir(parents=True, exist_ok=True)
            _install_steps(target, folder, source, ref, dry_run, lines)
            if not dry_run:
                try:
                    root = _plugin_root(target, folder)
                except Exception:
                    root = None
                if root:
                    try:
                        lines.extend(_refresh.refresh(home, source=root))
                        installed_version = json.loads((root / "plugin.json").read_text(encoding="utf-8"))["version"]
                        rows.append((tool_id, str(folder), f"installed legion {installed_version}"))
                    except Exception as error:
                        lines.append(f"commands not refreshed for {tool_id} in {folder}: {error}; run legion setup")
                        rows.append((tool_id, str(folder), f"commands not refreshed: {error}"))
                else:
                    lines.append(f"commands not refreshed for {tool_id} in {folder}; run legion setup")
                    rows.append((tool_id, str(folder), "commands not refreshed"))
        if entry.hooks.hint:
            lines.append(entry.hooks.hint)
    if not dry_run:
        lines.extend(_results_table(rows))
    if installed_version and not dry_run:
        lines.append(f"installed: legion {installed_version} ({ref})")
        lines.append("next: legion add claude (or legion in a repository)")
    return lines


def _confirm(question: str, lines: list[str]) -> bool:
    for line in lines:
        print(line)
    lines.clear()
    try:
        return click.confirm(question, default=False, prompt_suffix=" ", show_default=False)
    except click.Abort:
        return False


def _uninstall(home: Path, catalog: ToolsCatalog, selected: list[str], config_dir: Optional[Path], purge: bool, dry_run: bool, yes: bool, lines: list[str], agents: list[Agent]) -> None:
    # The tools' own commands remove the plugin and marketplace; nothing in a tool's files is edited here.
    steps: list[tuple[CatalogTool, Path, list[str]]] = []
    for tool_id in selected:
        entry = _tool(catalog, tool_id)
        if _target_tool(home, entry, agents) is None:
            lines.append(f"skip: {tool_id} (not installed)")
            continue
        for folder in _folders(home, entry, config_dir, agents):
            target = _target_tool(home, entry, agents, folder)
            if target is None:
                lines.append(f"skip: {tool_id} in {folder} (no command for this folder)")
                continue
            for what, listed, arguments in (
                ("plugin", folder.is_dir() and _plugin_state(target, folder)[0], entry.plugin.uninstall),
                ("marketplace", folder.is_dir() and _marketplace(target, folder), entry.plugin.marketplace_remove),
            ):
                if listed:
                    steps.append((target, folder, arguments))
                    lines.append(_command_line(target, arguments, folder))
                else:
                    lines.append(f"skip: {tool_id} {what} in {folder} (not installed)")
    # Only an uninstall of every tool, without --config-dir, removes legion's own folders.
    everything = config_dir is None and {entry.id for entry in catalog.tools} <= set(selected)
    if purge and not everything:
        raise InstallerError("--purge removes all of legion; run it without --tool and --config-dir.")
    folders = _legion_folders(home, purge, with_knowledge=False) if everything else []
    lines.extend(f"Remove folder: {folder}" for folder in folders)
    if everything:
        lines.extend(_user_path.remove(home, dry_run=True))
        if purge and (home / ".legion/knowledge").exists():
            lines.append("Asked separately: the knowledge hub in ~/.legion/knowledge")
    if not steps and not folders:
        lines.append("skip: uninstall (already done)")
        return
    if dry_run:
        return
    if not (yes or _confirm("Purge legion and all its data now? [y/N]" if purge else "Uninstall legion now? [y/N]", lines)):
        lines.append("Uninstall cancelled.")
        return
    for entry, folder, arguments in steps:
        _step(entry, arguments, folder, False, lines)
    if everything:
        lines.extend(_user_path.remove(home))
        with_knowledge = purge and (home / ".legion/knowledge").exists() and _confirm("Also delete the knowledge hub in ~/.legion/knowledge? [y/N]", lines)
        _handover.start(_legion_folders(home, purge, with_knowledge))
        lines.append("done: legion folders are removed when this command ends")


# Deleting never follows a link: a linked folder is removed as the link only.
def _legion_folders(home: Path, purge: bool, with_knowledge: bool) -> list[Path]:
    legion = home / ".legion"
    if not purge:
        return [folder for folder in (legion / "app", legion / "bin", legion / "python") if os.path.lexists(folder)]
    knowledge = legion / "knowledge"
    if is_reparse(legion) or with_knowledge or not knowledge.exists():
        return [legion] if os.path.lexists(legion) else []
    return [child for child in legion.iterdir() if child != knowledge]
