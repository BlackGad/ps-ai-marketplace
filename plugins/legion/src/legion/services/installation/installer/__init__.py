# Install, update and remove Legion through the tool catalog.

import json
import os
import re
import shutil
import tempfile
import tomllib
from contextlib import nullcontext
from functools import cmp_to_key
from pathlib import Path
from typing import Optional

import click
import httpx
from pydantic import ValidationError

from legion.services.accounts._launchers import command_prefix, registered_command
from legion.services.installation import _user_path
from legion.services.installation import _handover
from legion.services.installation import _knowledge_hub
from legion.services.installation import _refresh
from legion.services.installation import _uv_tool
from legion.services.installation._update import compare_versions
from legion.core import _settings_io
from legion.core._http import HttpsError, failure_text, get_bytes
from legion.core._home import (
    full_path,
    is_reparse,
    is_under,
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
    PersonalisationSettings,
    Plugin,
    PluginManifest,
    PluginPin,
    ToolsCatalog,
)


DEFAULT_SOURCE = "BlackGad/ps-legion-marketplace"
LEGION_MARKETPLACE = "ps-legion-marketplace"
LEGION_PLUGIN = "legion@ps-legion-marketplace"


class InstallerError(ValueError):
    pass


class _MissingAccountCommandError(InstallerError):
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
            if not any(same_path(resolve_directory(folder), resolve_directory(previous)) for previous in folders):
                folders.append(folder)
    override = os.getenv(entry.config_env)
    if override and not same_path(home, Path.home()) and not is_under(_config_path(home, override), home, allow_equal=True):
        override = None
    value = override or entry.plugin.default_config_dir
    if value:
        default = _config_path(home, value)
        if not any(same_path(resolve_directory(default), resolve_directory(previous)) for previous in folders):
            folders.insert(0, default)
    return folders


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


def _marketplace_item(entry: CatalogTool, folder: Path, name: str) -> dict[str, object]:
    output = _listing(entry, folder, "marketplace")
    if not output:
        return {}
    try:
        data = json.loads(output)
        listing = entry.plugin.marketplace_listing
        if listing.collection_field is not None:
            data = data[listing.collection_field]
        for item in data:
            if isinstance(item, dict) and item.get(listing.name_field) == name:
                return item
        return {}
    except (ValueError, TypeError, KeyError) as error:
        raise InstallerError(f"{entry.id} marketplace listing returned invalid JSON") from error


def _marketplace(entry: CatalogTool, folder: Path, require_root: bool = False) -> bool:
    item = _marketplace_item(entry, folder, LEGION_MARKETPLACE)
    field = entry.plugin.marketplace_listing.root_field
    if require_root and field is not None:
        root = item.get(field)
        return isinstance(root, str) and bool(root) and Path(root).is_dir()
    return bool(item)


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
def _plugin_state(entry: CatalogTool, folder: Path, plugin_id: str = LEGION_PLUGIN) -> tuple[bool, bool, list[Path], str]:
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
        if not isinstance(items, list):
            raise InstallerError(f"{entry.id} plugin listing returned invalid JSON")
        matches = [item for item in items if isinstance(item, dict) and item.get(listing.id_field) == plugin_id and isinstance(item.get(listing.enabled_field), bool)]
        for item in matches:
            if item.get("installPath"):
                paths.append(Path(item["installPath"]))
            version = item.get("version") or version
        return bool(matches), any(item[listing.enabled_field] for item in matches), paths, version
    lines = [line for line in output.splitlines() if _row_id(line) == plugin_id and "not installed" not in line]
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
            manifest = _manifest(path)
            if manifest.name == "legion" and (not version or manifest.version == version):
                roots.append(path)
        except (OSError, ValueError):
            continue
    if len(roots) != 1:
        raise InstallerError(f"{entry.id} installed legion folder could not be identified uniquely.")
    return roots[0]


def _manifest(root: Path) -> PluginManifest:
    return PluginManifest.model_validate_json((root / "plugin.json").read_text(encoding="utf-8-sig"))


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


def _install_steps(entry: CatalogTool, folder: Path, source: str | Path, ref: str, dry_run: bool, lines: list[str], plugin: Plugin | None = None, pin: PluginPin | None = None) -> None:
    plugin = plugin or entry.plugin
    branch = pin.tag if pin else "main" if ref == "main" else "stable"
    local = Path(source).is_dir()
    if local:
        source = Path(source).resolve().as_posix()
    template = plugin.marketplace_add if local else plugin.marketplace_add_ref
    marketplace_add = [word.replace("{source}", str(source)).replace("{ref}", branch) for word in template]
    if pin is None:
        installed = _marketplace(entry, folder)
        listed, enabled, _, _ = _plugin_state(entry, folder)
        ready = installed and _marketplace(entry, folder, require_root=True) if enabled else False
    else:
        item = _marketplace_item(entry, folder, pin.marketplace)
        installed = bool(item)
        listed, enabled, _, _ = _plugin_state(entry, folder, pin.plugin_id)
        ready = installed and _pinned_marketplace(entry, folder, item, pin)
        if not ready:
            for arguments in _removal_steps(plugin, listed, installed):
                _step(entry, arguments, folder, dry_run, lines)
            installed = False
    if ready and enabled:
        lines.extend(f"skip: {display_command([entry.command, *arguments])} (already done)" for arguments in (marketplace_add, plugin.install))
        return
    if not installed:
        _step(entry, marketplace_add, folder, dry_run, lines)
        if pin is not None and not dry_run and not _pinned_marketplace(entry, folder, _marketplace_item(entry, folder, pin.marketplace), pin):
            raise InstallerError(f"llm-wiki marketplace could not be verified at {pin.tag}")
    if plugin.marketplace_update:
        _step(entry, plugin.marketplace_update, folder, dry_run, lines)
    if not installed or not listed or not enabled:
        _step(entry, plugin.install, folder, dry_run, lines)


def _wiki_recipe(plugin: Plugin, pin: PluginPin) -> Plugin:
    names = {LEGION_MARKETPLACE: pin.marketplace, LEGION_PLUGIN: pin.plugin_id}
    return plugin.model_copy(
        update={
            "install": [names.get(word, word) for word in plugin.install],
            "uninstall": [names.get(word, word) for word in plugin.uninstall],
            "marketplace_remove": [names.get(word, word) for word in plugin.marketplace_remove],
            "marketplace_update": [],
        }
    )


def _pinned_marketplace(entry: CatalogTool, folder: Path, item: dict[str, object], pin: PluginPin) -> bool:
    nested = item.get("marketplaceSource") or item.get("source")
    details = nested if isinstance(nested, dict) else item
    source = details.get("repo") or details.get("url") or details.get("source")
    if not isinstance(source, str):
        return False
    source, _, source_ref = source.partition("#")
    if source.removeprefix("GitHub: ").removesuffix(".git").removeprefix("https://github.com/").removeprefix("git@github.com:") != pin.source:
        return False
    ref = details.get("ref") or item.get("ref") or source_ref
    if not ref:
        # Codex and Copilot can omit the ref from their marketplace listings.
        try:
            if entry.id == "codex":
                ref = tomllib.loads((folder / "config.toml").read_text(encoding="utf-8-sig"))["marketplaces"][pin.marketplace]["ref"]
            elif entry.id == "copilot":
                ref = json.loads((folder / "settings.json").read_text(encoding="utf-8-sig"))["extraKnownMarketplaces"][pin.marketplace]["source"]["ref"]
        except (OSError, ValueError, TypeError, KeyError):
            return False
    return ref == pin.tag


def _removal_steps(plugin: Plugin, listed: bool, registered: bool) -> list[list[str]]:
    return [arguments for present, arguments in ((listed, plugin.uninstall), (registered, plugin.marketplace_remove)) if present]


def _wiki_removal_steps(entry: CatalogTool, folder: Path, pin: PluginPin) -> list[list[str]]:
    return _removal_steps(_wiki_recipe(entry.plugin, pin), _plugin_state(entry, folder, pin.plugin_id)[0], bool(_marketplace_item(entry, folder, pin.marketplace)))


def _account_target(home: Path, catalog: ToolsCatalog, agent: Agent) -> tuple[CatalogTool, Path]:
    entry = _tool(catalog, agent.tool)
    command = registered_command(agent, home) if agent.command is not None else shutil.which(entry.command)
    if command is None:
        raise _MissingAccountCommandError(f"{agent.tool} command is missing")
    return entry.model_copy(update={"command": str(command)}), _config_path(home, agent.config_dir)


def remove_knowledge(home: Path, catalog: ToolsCatalog, agents: list[Agent], lines: list[str]) -> None:
    pin = catalog.wiki
    if pin is None:
        return
    seen: set[tuple[str, str]] = set()
    for agent in agents:
        try:
            entry, folder = _account_target(home, catalog, agent)
            key = entry.id, os.path.normcase(str(resolve_directory(folder)))
            if key not in seen:
                for arguments in _wiki_removal_steps(entry, folder, pin):
                    _step(entry, arguments, folder, False, lines)
                seen.add(key)
        except _MissingAccountCommandError as error:
            lines.append(f"skip: knowledge: {agent.id} ({error})")
        except (OSError, ValueError) as error:
            raise InstallerError(f"knowledge: {agent.id}: {error}") from error


def reconcile_knowledge(home: Path, catalog: ToolsCatalog, dry_run: bool, lines: list[str]) -> None:
    # Re-read the choice after acquiring the lock in case setup turned knowledge off during an update.
    with nullcontext() if dry_run else _settings_io.writer(home, require_existing=False):
        settings = _personalisation(home)
        if settings and settings.knowledge_enabled:
            _reconcile_knowledge(home, catalog, settings.agents, dry_run, lines)


def _reconcile_knowledge(home: Path, catalog: ToolsCatalog, agents: list[Agent], dry_run: bool, lines: list[str]) -> None:
    pin = catalog.wiki
    if pin is None:
        return
    if not dry_run:
        try:
            _knowledge_hub.initialize(home, lines)
        except (OSError, ValueError, TypeError, RuntimeError) as error:
            lines.append(f"knowledge: hub setup failed: {error}")
    results: dict[tuple[str, str], str | None] = {}
    for agent in agents:
        try:
            entry, folder = _account_target(home, catalog, agent)
            key = entry.id, os.path.normcase(str(resolve_directory(folder)))
            if key not in results:
                try:
                    if not dry_run:
                        folder.mkdir(parents=True, exist_ok=True)
                    _install_steps(entry, folder, pin.source, pin.tag, dry_run, lines, _wiki_recipe(entry.plugin, pin), pin)
                    results[key] = None
                except (OSError, ValueError, TypeError, RuntimeError) as error:
                    results[key] = str(error)
            if results[key] is not None:
                lines.append(f"knowledge: {agent.id}: {results[key]}")
        except (OSError, ValueError, RuntimeError) as error:
            lines.append(f"knowledge: {agent.id}: {error}")


# One row per tool and folder, so a long install ends with what happened where.
# Hand-built, reason: a three-column text table is plain str.ljust; no table library is pinned.
def _results_table(rows: list[tuple[str, str, str]]) -> list[str]:
    table = [("Tool", "Folder", "Result"), *rows]
    widths = [max(len(row[column]) for row in table) for column in (0, 1)]
    return ["Results:", *(f"{tool.ljust(widths[0])}  {folder.ljust(widths[1])}  {result}".rstrip() for tool, folder, result in table)]


# The uv step runs after this process exits, so it can replace the legion that is running it. One install serves every target:
# the newest plugin version this update reached wins.
def _install_tool(home: Path, roots: list[tuple[str, Path]], lines: list[str], rows: list[tuple[str, str, str]], dry_run: bool) -> None:
    if not roots:
        return
    root = max(roots, key=cmp_to_key(lambda left, right: compare_versions(left[0], right[0])))[1]
    try:
        if dry_run:
            lines.extend(_uv_tool.install(root, home, dry_run=True))
        else:
            lines.extend(_refresh.refresh(home, source=root, detached=True))
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
    with_knowledge: bool = True,
) -> list[str]:
    if update and uninstall:
        raise InstallerError("Choose either --update or --uninstall.")
    if purge and not uninstall:
        raise InstallerError("--purge requires --uninstall.")
    home = full_path(home)
    catalog = _catalog(source, ref, catalog)
    lines: list[str] = []
    settings = _personalisation(home, lines if uninstall else None)
    agents = settings.agents if settings else []
    selected = list(dict.fromkeys(part for word in (tools or []) for part in word.split(",") if part))
    if not selected:
        selected = [entry.id for entry in catalog.tools if uninstall or _target_tool(home, entry, agents) is not None]
    for tool_id in selected:
        _tool(catalog, tool_id)
    knowledge_enabled = settings is not None and settings.knowledge_enabled is True
    if uninstall:
        _uninstall(home, catalog, selected, config_dir, purge, dry_run, yes, lines, agents, catalog.wiki if knowledge_enabled else None)
        return lines
    manage_knowledge = update and with_knowledge and knowledge_enabled
    if not selected:
        lines.append("No coding CLI is installed. Run legion setup to install one.")
        for entry in catalog.tools:
            lines.extend([f"skip: {entry.id} (not installed)", entry.install_hint])
        if not dry_run and not (yes or _confirm("Install the legion command with uv and add it to your PATH? [y/N]", lines)):
            return [*lines, "Nothing changed. Run again with --yes to apply."]
        lines.extend(_uv_tool.install(PLUGIN_ROOT, home, dry_run=True, update_shell=True) if dry_run else _refresh.refresh(home, source=PLUGIN_ROOT, update_shell=True))
        if manage_knowledge:
            reconcile_knowledge(home, catalog, dry_run, lines)
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
                if knowledge_enabled and target.id == "codex" and target.plugin.marketplace_update == ["plugin", "marketplace", "upgrade"]:
                    # Codex's unqualified upgrade would also refresh the pinned wiki and could block Legion on a wiki error.
                    plugin = target.plugin.model_copy(update={"marketplace_update": [*target.plugin.marketplace_update, LEGION_MARKETPLACE]})
                    target = target.model_copy(update={"plugin": plugin})
                targets.append((target, folder))
        for entry, folder in targets:
            root = _plugin_root(entry, folder)
            version = _manifest(root).version if root else "not installed"
            lines.append(f"Update legion for {entry.id} in {folder} ({version})")
        if targets:
            lines.append("Running legion sessions (MCP servers and legion runs) end when the legion command is replaced.")
        if (targets or manage_knowledge) and not dry_run and not (yes or _confirm("Update legion? [y/N]", lines)):
            return [*lines, "Nothing changed. Run again with --yes to apply."]
        rows: list[tuple[str, str, str]] = []
        roots: list[tuple[str, Path]] = []
        try:
            for entry, folder in targets:
                before = _plugin_root(entry, folder)
                before_version = _manifest(before).version if before else "not installed"
                if before:
                    for arguments in (entry.plugin.marketplace_update, entry.plugin.update):
                        if arguments:
                            _step(entry, arguments, folder, dry_run, lines)
                else:
                    _install_steps(entry, folder, source, ref, dry_run, lines)
                if dry_run:
                    if before:
                        roots.append((before_version, before))
                else:
                    after = _plugin_root(entry, folder)
                    if after is None:
                        raise InstallerError(f"{entry.id} legion is absent from the post-update listing; generated artifacts were not refreshed.")
                    after_version = _manifest(after).version
                    lines.append(f"legion {before_version} -> {after_version}" if before_version != after_version else f"skip: legion {after_version} (already up to date)")
                    rows.append((entry.id, str(folder), f"{before_version} -> {after_version}" if before_version != after_version else f"already up to date ({after_version})"))
                    roots.append((after_version, after))
        except BaseException:
            # Plugins already updated need their legion command even when a later account fails.
            # The returned lines are lost with the error, so the install is reported before it propagates.
            failed: list[str] = []
            _install_tool(home, roots, failed, rows, dry_run)
            for line in failed:
                click.echo(line, err=True)
            raise
        _install_tool(home, roots, lines, rows, dry_run)
        if manage_knowledge:
            reconcile_knowledge(home, catalog, dry_run, lines)
        if targets and not dry_run:
            lines.extend(_results_table(rows))
            lines.append("done: restart your sessions; run legion in the repository")
        return lines
    lines.append(f"Install legion for {', '.join(selected)}")
    if not dry_run and not (yes or _confirm(f"Install legion for {', '.join(selected)} now, and put the legion command on your PATH with uv? [y/N]", lines)):
        return [*lines, "Nothing changed. Run again with --yes to apply."]
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
                        lines.extend(_refresh.refresh(home, source=root, update_shell=True))
                        installed_version = _manifest(root).version
                        rows.append((tool_id, str(folder), f"installed legion {installed_version}"))
                    except Exception as error:
                        lines.append(f"commands not refreshed for {tool_id} in {folder}: {error}; run legion setup")
                        rows.append((tool_id, str(folder), f"commands not refreshed: {error}"))
                else:
                    lines.append(f"commands not refreshed for {tool_id} in {folder}; run legion setup")
                    rows.append((tool_id, str(folder), "commands not refreshed"))
        if entry.hooks.hint:
            lines.append(entry.hooks.hint)
    if dry_run:
        lines.extend(_uv_tool.install(PLUGIN_ROOT, home, dry_run=True, update_shell=True))
    else:
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


def _uninstall(
    home: Path, catalog: ToolsCatalog, selected: list[str], config_dir: Optional[Path], purge: bool, dry_run: bool, yes: bool, lines: list[str], agents: list[Agent], pin: PluginPin | None
) -> None:
    # The tools' own commands remove the plugin and marketplace; nothing in a tool's files is edited here.
    steps: list[tuple[CatalogTool, Path, list[str], bool]] = []
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
                    steps.append((target, folder, arguments, False))
                    lines.append(_command_line(target, arguments, folder))
                else:
                    lines.append(f"skip: {tool_id} {what} in {folder} (not installed)")
            if pin is not None:
                try:
                    for arguments in _wiki_removal_steps(target, folder, pin):
                        steps.append((target, folder, arguments, True))
                        lines.append(_command_line(target, arguments, folder))
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
    failed_wiki: set[tuple[str, Path]] = set()
    for entry, folder, arguments, wiki in steps:
        if not wiki:
            _step(entry, arguments, folder, False, lines)
        elif (entry.id, folder) not in failed_wiki:
            try:
                _step(entry, arguments, folder, False, lines)
            except (OSError, ValueError) as error:
                failed_wiki.add((entry.id, folder))
                lines.append(f"knowledge: {entry.id} in {folder}: {error}")
    if everything:
        lines.extend(_user_path.remove(home, purge))
        with_knowledge = hub and _confirm("Also delete the knowledge hub in ~/.legion/knowledge? [y/N]", lines)
        if with_knowledge:
            _knowledge_hub.purge(home, lines)
        # The stop event ends every running legion first; if one stays, nothing is deleted.
        lines.extend(_uv_tool.uninstall(home))
        remaining = _legion_folders(home, purge, with_knowledge)
        _handover.start(remaining)
        lines.append("done: legion folders are removed when this command ends" if remaining else "done: legion is uninstalled")


# Deleting never follows a link: a linked folder is removed as the link only.
def _legion_folders(home: Path, purge: bool, with_knowledge: bool) -> list[Path]:
    if not purge:
        return []
    legion = home / ".legion"
    knowledge = legion / "knowledge"
    if is_reparse(legion) or with_knowledge or not os.path.lexists(knowledge):
        return [legion] if os.path.lexists(legion) else []
    return [child for child in legion.iterdir() if child != knowledge]
