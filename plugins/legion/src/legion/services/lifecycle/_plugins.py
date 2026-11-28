# Apply and inspect plugin registrations using the tools catalog.

import json
import os
import re
import shutil
import tempfile
import tomllib
from collections.abc import Callable
from pathlib import Path

from legion.services.accounts._launchers import command_prefix
from legion.services.lifecycle import _targets
from legion.services.lifecycle._targets import LEGION_MARKETPLACE, LEGION_PLUGIN
from legion.core._run import display_command, run_command
from legion.core._settings_models import (
    CatalogTool,
    JsonListing,
    Plugin,
    PluginPin,
)


def _execute(entry: CatalogTool, arguments: list[str], folder: Path, listing: bool = False, progress: Callable[[str], None] | None = None) -> str:
    env = dict(os.environ)
    env[entry.config_env] = str(folder)
    if listing:
        env.update(entry.plugin.listing_env or {})
    command = entry.command if Path(entry.command).is_absolute() else shutil.which(entry.command) or entry.command
    program, prefix = command_prefix(Path(command))
    result = run_command(str(program), [*prefix, *arguments], env=env, cwd=Path(tempfile.gettempdir()), progress=progress)
    if result.exit_code:
        detail = result.error.strip() or result.output.strip()
        raise ValueError(f"{entry.command} {'listing ' if listing else ''}exited {result.exit_code}" + (f"\n{detail}" if detail else ""))
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
        raise ValueError(f"{entry.id} marketplace listing returned invalid JSON") from error


# The id is the first word of a listing row, or the second after a bullet in any spelling (the Windows console may print it as other
# characters). A continuation line such as "from <path>" has none. tests/integration/run.py keeps an identical copy.
def _row_id(line: str) -> str | None:
    words = line.split()
    if words and "@" in words[0]:
        return words[0]
    if len(words) > 1 and "@" in words[1] and words[0].rstrip(":") != "from":
        return words[1]
    return None


def _plugin_state(entry: CatalogTool, folder: Path, plugin_id: str) -> tuple[bool, bool, str | None]:
    output = _listing(entry, folder, "plugin")
    if not output:
        return False, False, None
    listing = entry.plugin.listing
    if isinstance(listing, JsonListing):
        try:
            items = json.loads(output)
            if not isinstance(items, list):
                raise TypeError("expected a JSON array")
        except (ValueError, TypeError) as error:
            raise ValueError(f"{entry.id} plugin listing returned invalid JSON") from error
        matches = [item for item in items if isinstance(item, dict) and item.get(listing.id_field) == plugin_id and isinstance(item.get(listing.enabled_field), bool)]
        enabled = [item for item in matches if item[listing.enabled_field]]
        version = next((item["version"] for item in enabled or matches if isinstance(item.get("version"), str)), None)
        return bool(matches), bool(enabled), version
    lines = [line for line in output.splitlines() if _row_id(line) == plugin_id and "not installed" not in line]
    enabled = [line for line in lines if not re.search(listing.reject_pattern, line)]
    version = None
    for line in enabled or lines:
        match = re.search(r"\s\(?v?(\d+\.\d+\.\d+(?:[-+][\w.+-]+)?)(?:\)|\s|$)", line)
        if match:
            version = match[1]
            break
    return bool(lines), bool(enabled), version


def verified_copy(entry: CatalogTool, folder: Path) -> tuple[str, Path] | None:
    listed, _, version = _plugin_state(entry, folder, LEGION_PLUGIN)
    return _targets.plugin_copy(folder, entry, version=version) if listed else None


def command_line(entry: CatalogTool, arguments: list[str], folder: Path) -> str:
    program, prefix = command_prefix(Path(entry.command))
    return f"{entry.config_env}={display_command([str(folder)])} {display_command([str(program), *prefix, *arguments])}"


def flush_progress(lines: list[str], progress: Callable[[str], None] | None) -> None:
    if progress is not None:
        for line in lines:
            progress(line)
        lines.clear()


def run_step(entry: CatalogTool, arguments: list[str], folder: Path, dry_run: bool, lines: list[str], progress: Callable[[str], None] | None = None) -> None:
    line = command_line(entry, arguments, folder)
    if dry_run:
        lines.append(line)
        flush_progress(lines, progress)
        return
    flush_progress(lines, progress)
    if progress is not None:
        progress(line)
    lines.extend(_execute(entry, arguments, folder, progress=progress).splitlines())
    flush_progress(lines, progress)


def ensure(
    entry: CatalogTool,
    folder: Path,
    source: str | Path,
    ref: str,
    dry_run: bool,
    say: Callable[[str], None],
    *,
    pin: PluginPin | None = None,
    updating: bool = False,
) -> tuple[str, Path] | None:
    plugin = _wiki_recipe(entry.plugin, pin) if pin else entry.plugin
    marketplace = pin.marketplace if pin else LEGION_MARKETPLACE
    plugin_id = pin.plugin_id if pin else LEGION_PLUGIN
    branch = pin.tag if pin else "main" if ref == "main" else "stable"
    local = Path(source).is_dir()
    if local:
        source = Path(source).resolve().as_posix()
    template = plugin.marketplace_add if local else plugin.marketplace_add_ref
    add = [word.replace("{source}", str(source)).replace("{ref}", branch) for word in template]

    item = _marketplace_item(entry, folder, marketplace)
    listed, enabled, version = _plugin_state(entry, folder, plugin_id)
    registered = bool(item)
    before = None
    if pin:
        ready = registered and _pinned_marketplace(entry, folder, item, pin)
        if not ready:
            for arguments in _removal_steps(plugin, listed, registered):
                run_step(entry, arguments, folder, dry_run, [], say)
            registered = False
    else:
        field = plugin.marketplace_listing.root_field
        root = item.get(field) if field else None
        before = _targets.plugin_copy(folder, entry, version=version) if listed else None
        ready = before is not None and registered and (field is None or (isinstance(root, str) and bool(root) and Path(root).is_dir()))

    if ready and updating:
        for arguments in (plugin.marketplace_update, plugin.update):
            if arguments:
                run_step(entry, arguments, folder, dry_run, [], say)
        return before
    if ready and enabled:
        for arguments in (add, plugin.install):
            say(f"skip: {display_command([entry.command, *arguments])} in {folder} (already done)")
        return before
    if not dry_run:
        folder.mkdir(parents=True, exist_ok=True)
    if not registered:
        run_step(entry, add, folder, dry_run, [], say)
        if pin and not dry_run and not _pinned_marketplace(entry, folder, _marketplace_item(entry, folder, marketplace), pin):
            raise ValueError(f"llm-wiki marketplace could not be verified at {pin.tag}")
    if plugin.marketplace_update:
        run_step(entry, plugin.marketplace_update, folder, dry_run, [], say)
    run_step(entry, plugin.install, folder, dry_run, [], say)
    return before


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


def removal_steps(entry: CatalogTool, folder: Path, pin: PluginPin | None = None) -> list[list[str]]:
    plugin = _wiki_recipe(entry.plugin, pin) if pin else entry.plugin
    listed, _, _ = _plugin_state(entry, folder, pin.plugin_id if pin else LEGION_PLUGIN)
    registered = bool(_marketplace_item(entry, folder, pin.marketplace if pin else LEGION_MARKETPLACE))
    return _removal_steps(plugin, listed, registered)
