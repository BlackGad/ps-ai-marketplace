# The legacy runtime layout: version folders in ~/.legion/app with hashed environments in ~/.legion/python.
# Nothing creates it any more (legion is a uv tool); the migration reads and removes it with these helpers.

import hashlib
import shutil
import sys
import uuid
from dataclasses import dataclass
from functools import cmp_to_key
from pathlib import Path

from legion.services.repository._footprints import read, remove_entry
from legion.core._home import (
    full_path,
    home_path,
    owner_path_safe,
    resolve_directory,
    same_path,
    tree_has_reparse,
)
from legion.services.installation._update import compare_versions

MARKER = ".legion-app-ready"


@dataclass(frozen=True)
class AppVersion:
    version: str
    path: Path


def python_environment(plugin_root: Path, home: Path) -> Path:
    key = str(resolve_directory(plugin_root)).rstrip("/\\")
    if sys.platform == "win32":
        key = key.lower()
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:12]
    return home / ".legion" / "python" / f"env-{digest}"


def version_safe(path: Path, home: Path) -> bool:
    app = full_path(home / ".legion" / "app")
    if not same_path(full_path(path.parent), app):
        return False
    environment = python_environment(path, home)
    if not owner_path_safe(path, home) or not owner_path_safe(environment, home):
        return False
    return not path.exists() or not tree_has_reparse(path)


def ready_versions(home: Path) -> list[AppVersion]:
    ready: list[AppVersion] = []
    for entry in read(home).entries:
        if entry.kind != "app-version":
            continue
        path = full_path(home_path(entry.path, home))
        try:
            compare_versions(path.name, path.name)
        except ValueError:
            continue
        if (path / MARKER).is_file() and version_safe(path, home):
            ready.append(AppVersion(path.name, path))
    return sorted(ready, key=cmp_to_key(lambda left, right: -compare_versions(left.version, right.version)))


# Rename both trees before deleting either. On Windows, an open file blocks the whole folder rename,
# so a running version remains complete. Hand-built, reason: shutil.rmtree can partially delete a locked tree.
def _remove_version(path: Path, home: Path) -> bool:
    environment = python_environment(path, home)
    suffix = uuid.uuid4().hex
    moved_path = path.with_name(f".pruning-{path.name}-{suffix}")
    moved_environment = environment.with_name(f".pruning-{environment.name}-{suffix}")
    try:
        if path.exists():
            path.replace(moved_path)
        if environment.exists():
            environment.replace(moved_environment)
    except OSError:
        if moved_path.exists():
            moved_path.replace(path)
        return False
    try:
        # Once deletion starts, a restored environment may be incomplete and must not qualify as ready.
        (moved_path / MARKER).unlink(missing_ok=True)
        if moved_environment.exists():
            shutil.rmtree(moved_environment)
        if moved_path.exists():
            shutil.rmtree(moved_path)
    except OSError:
        if moved_environment.exists():
            moved_environment.replace(environment)
        if moved_path.exists():
            moved_path.replace(path)
        return False
    return True


# After the commands run `keep`: removes recorded versions older than it, except the previous ready one, which
# a running legion may still use. A version that cannot go yet stays recorded for the next sync.
def prune_old_versions(keep: Path, home: Path) -> list[str]:
    keep_version = keep.name
    previous = next((item for item in ready_versions(home) if compare_versions(item.version, keep_version) < 0), None)
    lines: list[str] = []
    for entry in read(home).entries:
        if entry.kind != "app-version":
            continue
        path = full_path(home_path(entry.path, home))
        try:
            if compare_versions(path.name, keep_version) >= 0:
                continue
        except ValueError:
            continue
        if previous and same_path(path, previous.path):
            continue
        if not version_safe(path, home):
            lines.append(f"skip: {path} (linked or not legion's)")
        elif not _remove_version(path, home):
            lines.append(f"skip: legion app {path.name} (in use; removed at the next sync)")
        else:
            remove_entry(home, "app-version", path)
            lines.append(f"removed legion app {path.name}")
    return lines
