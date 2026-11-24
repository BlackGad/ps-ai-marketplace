import hashlib
import sys
from dataclasses import dataclass
from functools import cmp_to_key
from pathlib import Path

from ._footprints import read
from ._home import full_path, home_path, owner_path_safe, resolve_directory, same_path, tree_has_reparse
from ._update import compare_versions


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
        if (path / ".legion-app-ready").is_file() and version_safe(path, home):
            ready.append(AppVersion(path.name, path))
    return sorted(ready, key=cmp_to_key(lambda left, right: -compare_versions(left.version, right.version)))
