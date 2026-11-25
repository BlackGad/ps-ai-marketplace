import importlib
import re
import shutil
import sys
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Literal

from filelock import FileLock, Timeout

from legion.core import _plugin
from legion.core._generated import is_owned
from legion.core._home import footprint_index, full_path, home_path, is_under, owner_path_safe, resolve_directory, same_path, tree_has_reparse
from legion.core._settings_models import SchemaVersion, SettingsModel, Text, ToolDescriptor

FootprintKind = Literal["file", "folder", "link", "path-entry", "edit", "app", "app-version"]


class Footprint(SettingsModel):
    kind: FootprintKind
    path: Text
    key: str = ""
    value: str = ""
    owners: list[str]


class FootprintIndex(SettingsModel):
    schema_version: SchemaVersion
    entries: list[Footprint]


class FootprintError(Exception):
    pass


def target_owner(tool: ToolDescriptor | str, folder: Path | str | None, home: Path | None = None) -> str:
    if isinstance(tool, ToolDescriptor):
        if home is None:
            raise ValueError("home is required for a tool descriptor")
        folder = folder or tool.plugin.default_config_dir or ""
        path = home_path(str(folder), home)
        tool_id = tool.id
    else:
        if folder is None:
            raise ValueError("folder is required for a tool id")
        path = Path(folder)
        tool_id = tool
    owner = f"{tool_id}:{str(resolve_directory(path)).rstrip('/\\')}"
    return owner.lower() if sys.platform == "win32" else owner


def same_owner(left: str, right: str) -> bool:
    def spelling(value: str) -> str:
        tool_id, separator, folder = value.partition(":")
        if separator and tool_id in ("claude", "codex", "copilot") and Path(folder).is_absolute():
            return target_owner(tool_id, Path(folder))
        return value

    return spelling(left) == spelling(right)


@contextmanager
def lock(home: Path) -> Iterator[None]:
    index = footprint_index(home)
    if not owner_path_safe(index, home):
        raise FootprintError("Footprint index contains a link; resolve it before writing")
    index.parent.mkdir(parents=True, exist_ok=True)
    file_lock = FileLock(str(index) + ".lock", timeout=30)
    try:
        try:
            file_lock.acquire()
        except FileNotFoundError:
            # Purge can remove an empty .legion after releasing this lock while a writer waits.
            if not owner_path_safe(index, home):
                raise FootprintError("Footprint index contains a link; resolve it before writing") from None
            index.parent.mkdir(parents=True, exist_ok=True)
            file_lock.acquire()
    except Timeout:
        raise FootprintError("Footprint index is busy; another legion command is still running") from None
    try:
        yield
    finally:
        file_lock.release()


def read(home: Path) -> FootprintIndex:
    index = footprint_index(home)
    if not index.exists():
        return FootprintIndex.model_validate({"schemaVersion": 1, "entries": []})
    return FootprintIndex.model_validate_json(index.read_text(encoding="utf-8-sig"))


def _write(home: Path, data: FootprintIndex) -> None:
    index = footprint_index(home)
    temporary: Path | None = None
    try:
        with tempfile.NamedTemporaryFile("wb", dir=index.parent, prefix=f".{index.name}.", suffix=".tmp", delete=False) as file:
            temporary = Path(file.name)
            file.write((data.model_dump_json(by_alias=True, indent=2) + "\n").encode("utf-8"))
        temporary.replace(index)
    finally:
        if temporary is not None:
            temporary.unlink(missing_ok=True)


def stored_path(home: Path, path: Path | str) -> str:
    if str(path) == "user PATH":
        return "user PATH"
    full = full_path(home_path(str(path), home))
    if is_under(full, home):
        return "~/" + full.relative_to(full_path(home)).as_posix()
    return str(full)


def add(home: Path, kind: FootprintKind, path: Path | str, owner: str, key: str = "", value: str = "") -> None:
    stored = stored_path(home, path)
    with lock(home):
        data = read(home)
        for entry in data.entries:
            if entry.kind == kind and same_path(Path(entry.path), Path(stored)) and entry.key == key and entry.value == value:
                if not any(same_owner(owner, existing) for existing in entry.owners):
                    entry.owners.append(owner)
                    _write(home, data)
                return
        data.entries.append(Footprint(kind=kind, path=stored, key=key, value=value, owners=[owner]))
        _write(home, data)


def remove_entry(home: Path, kind: FootprintKind, path: Path | str) -> None:
    target = full_path(home_path(str(path), home))
    with lock(home):
        data = read(home)
        kept = [entry for entry in data.entries if entry.kind != kind or not same_path(full_path(home_path(entry.path, home)), target)]
        if len(kept) != len(data.entries):
            _write(home, data.model_copy(update={"entries": kept}))


def remove_exact(home: Path, kind: FootprintKind, path: Path | str, key: str, value: str) -> None:
    target = full_path(home_path(str(path), home))
    with lock(home):
        data = read(home)
        kept = [entry for entry in data.entries if entry.kind != kind or not same_path(full_path(home_path(entry.path, home)), target) or entry.key != key or entry.value != value]
        if len(kept) != len(data.entries):
            _write(home, data.model_copy(update={"entries": kept}))


def is_safe(entry: Footprint, home: Path) -> bool:
    if re.search(r"(^|[/\\])\.\.([/\\]|$)|[?*]", entry.path):
        return False
    path = full_path(home_path(entry.path, home))
    walked = path.parent if entry.kind == "link" else path
    if not is_under(path, home / ".legion") or not owner_path_safe(walked, home):
        return False
    if entry.kind == "link":
        try:
            target = str(path.readlink())
            # PowerShell's LinkTarget omits the Windows extended-path prefix.
            return target == entry.value or (sys.platform == "win32" and target.removeprefix("\\\\?\\") == entry.value)
        except FileNotFoundError:
            return True
        except OSError:
            return False
    if not path.exists():
        return True
    if entry.kind == "file":
        return is_owned(path, "owner command")
    if not path.is_dir():
        return False
    # A linked child can escape the recorded folder, so inspect without following links.
    return not tree_has_reparse(path)


# Hand-built, reason: an app version and its uv environment must be removed as one safe unit after the last target owner leaves.
def _remove_orphan_app(home: Path, kept: list[Footprint], lines: list[str]) -> bool:
    orphan_app = [entry for entry in kept if entry.kind == "app" and not entry.owners]
    if not orphan_app:
        return False
    # Import at use time because app imports footprint helpers while its module is initialized.
    app = importlib.import_module("legion.services._app")
    changed = False
    versions = [entry for entry in kept if entry.kind == "app-version"]
    for entry in versions:
        path = full_path(home_path(entry.path, home))
        if is_under(_plugin.PLUGIN_ROOT, path, allow_equal=True):
            lines.append(f"Kept app version in use: {path} (close legion, then run uninstall again)")
            continue
        if not app.version_safe(path, home):
            lines.append(f"skip: {path} (linked or not legion's)")
            continue
        if not app._remove_version(path, home):
            lines.append(f"Kept app version in use: {path} (close legion, then run uninstall again)")
            continue
        kept.remove(entry)
        lines.append(f"Remove app version: {path}")
        changed = True
    if not any(entry.kind == "app-version" for entry in kept):
        app_folder = home / ".legion" / "app"
        sync_lock = app_folder / ".sync.lock"
        if app_folder.is_dir() and sync_lock.is_file() and not sync_lock.is_symlink() and list(app_folder.iterdir()) == [sync_lock]:
            try:
                with FileLock(str(sync_lock), timeout=0):
                    pass
            except Timeout:
                lines.append(f"Kept app lock in use: {sync_lock}")
            else:
                sync_lock.unlink(missing_ok=True)
        if app_folder.is_dir() and not any(app_folder.iterdir()):
            app_folder.rmdir()
        if not app_folder.exists():
            for entry in orphan_app:
                kept.remove(entry)
                changed = True
    return changed


def remove_owner(home: Path, owners: list[str]) -> list[str]:
    index = footprint_index(home)
    if not index.exists():
        return []
    lines: list[str] = []
    with lock(home):
        data = read(home)
        kept: list[Footprint] = []
        changed = False
        for entry in data.entries:
            remaining = [owner for owner in entry.owners if not any(same_owner(owner, selected) for selected in owners)]
            if len(remaining) == len(entry.owners):
                kept.append(entry)
                continue
            changed = True
            entry.owners = remaining
            if remaining or entry.kind not in ("file", "folder"):
                kept.append(entry)
                continue
            path = home_path(entry.path, home)
            if not is_safe(entry, home):
                lines.append(f"skip: {path} (linked or not legion's)")
                kept.append(entry)
                continue
            if path.exists():
                lines.append(f"Remove {entry.kind}: {path}")
                if entry.kind == "folder":
                    shutil.rmtree(full_path(path))
                else:
                    path.unlink()
        changed = _remove_orphan_app(home, kept, lines) or changed
        if changed:
            _write(home, data.model_copy(update={"entries": kept}))
    return lines
