import re
import shutil
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Literal

from filelock import FileLock, Timeout

from legion.core._atomic_write import atomic_write_bytes
from legion.core._generated import is_owned
from legion.core._home import (
    footprint_index,
    full_path,
    home_path,
    is_under,
    owner_path_safe,
    resolve_directory,
    same_path,
    tree_has_reparse,
)
from legion.core._settings_models import (
    SchemaVersion,
    SettingsModel,
    Text,
    ToolDescriptor,
)

FootprintKind = Literal["file", "folder", "path-entry", "app-version"]


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
            # The legion folder can be deleted while a writer waits.
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
    atomic_write_bytes(index, (data.model_dump_json(by_alias=True, indent=2) + "\n").encode("utf-8"), keep_mode=False)


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
    if not is_under(path, home / ".legion") or not owner_path_safe(path, home):
        return False
    if not path.exists():
        return True
    if entry.kind == "file":
        return is_owned(path, "owner command")
    if not path.is_dir():
        return False
    # A linked child can escape the recorded folder, so inspect without following links.
    return not tree_has_reparse(path)


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
        if changed:
            _write(home, data.model_copy(update={"entries": kept}))
    return lines
