import hashlib
import json
import os
import shutil
import sys
import uuid
from collections.abc import Iterator
from contextlib import contextmanager
from dataclasses import dataclass
from functools import cmp_to_key
from pathlib import Path
from typing import Literal, NamedTuple, Optional

from filelock import FileLock, Timeout

from legion.services.repository._footprints import (
    Footprint,
    add,
    read,
    remove_entry,
)
from legion.core._generated import (
    header,
    is_owned,
    shell_literal,
    write_generated,
)
from legion.core._home import (
    bin_folder,
    full_path,
    home_path,
    is_under,
    owner_path_safe,
    resolve_directory,
    same_path,
    tree_has_reparse,
)
from legion.core._plugin import PLUGIN_ROOT
from legion.core._run import run_command
from legion.services.installation._update import compare_versions

UV_MISSING = "uv is missing. Ask the owner before installing it, then run the legion installer again."
MARKER = ".legion-app-ready"


class AppError(ValueError):
    pass


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


def find_uv() -> Optional[str]:
    return shutil.which("uv")


def _recorded(path: Path, home: Path) -> bool:
    return any(entry.kind == "app-version" and same_path(full_path(home_path(entry.path, home)), path) for entry in read(home).entries)


# What a sync did: "published" made `ready` the new version now, "confirmed" found the wanted or a newer version
# already in place, and "fell back" left `ready` as an older ready version, or None.
class AppSync(NamedTuple):
    lines: list[str]
    ready: Optional[Path]
    state: Literal["published", "confirmed", "fell back"]


# One sync, command write and prune at a time; the next one waits, then compares versions again.
# Yields False when another one still holds the lock after `timeout` seconds.
@contextmanager
def app_lock(home: Path, timeout: float = 60) -> Iterator[bool]:
    app = home / ".legion" / "app"
    if not owner_path_safe(app, home):
        raise AppError("The legion app folder contains a link; resolve it before refreshing")
    app.mkdir(parents=True, exist_ok=True)
    lock = FileLock(str(app / ".sync.lock"), timeout=timeout)
    try:
        lock.acquire()
    except Timeout:
        yield False
        return
    try:
        yield True
    finally:
        lock.release()


# The owner command runs a copy of this plugin in ~/.legion/app/<version>, with that version's own environment.
# The copy is staged, recorded, renamed into place and then synced there (the project installs as editable);
# the marker is written only after uv sync succeeds and the version still holds no link. A recorded folder
# without the marker is unfinished: never run, repaired by the next sync of its version or removed with the
# older ones. Returns the lines to print and the ready version the commands should run, or None.
def sync_app(home: Path, source: Path = PLUGIN_ROOT) -> AppSync:
    version = json.loads((source / "plugin.json").read_text(encoding="utf-8-sig"))["version"]
    try:
        compare_versions(version, version)
    except ValueError as error:
        raise AppError(f"The plugin version '{version}' is not a version") from error
    app = full_path(home / ".legion" / "app")
    target = app / version
    environment = python_environment(target, home)
    ready = ready_versions(home)
    ready_path = ready[0].path if ready else None
    if ready and compare_versions(ready[0].version, version) > 0:
        return AppSync([f"skip: legion app {version} (newer {ready[0].version} in place)"], ready_path, "confirmed")
    if ready and same_path(ready[0].path, target):
        return AppSync([f"skip: legion app {version} (already done)"], ready_path, "confirmed")
    if os.path.lexists(target) and not _recorded(target, home):
        return AppSync([f"skip: {target} (not legion's)"], ready_path, "fell back")
    if not owner_path_safe(target, home) or not owner_path_safe(environment, home):
        return AppSync([f"skip: {target} (linked version or environment)"], ready_path, "fell back")
    uv = find_uv()
    if uv is None:
        return AppSync([UV_MISSING], ready_path, "fell back")
    if not target.exists():
        staging = app / f".staging-{os.urandom(16).hex()}"
        app.mkdir(parents=True, exist_ok=True)
        # The source may itself be a published app: its ready marker says nothing about this home's environment.
        shutil.copytree(source, staging, symlinks=True, ignore=shutil.ignore_patterns(MARKER))
        add(home, "app-version", target, "legion")
        staging.rename(target)
    # An unfinished version may hold a link; uv reads the project, so the tree is checked before it runs.
    if not version_safe(target, home):
        return AppSync([f"skip: {target} (linked)"], ready_path, "fell back")
    result = run_command(uv, ["sync", "--project", str(target), "--frozen", "--extra", "mcp", "--quiet"], env={**os.environ, "UV_PROJECT_ENVIRONMENT": str(environment)})
    if result.exit_code != 0:
        lines = [result.error.strip()] if result.error.strip() else []
        return AppSync([*lines, f"legion app {version} not ready (uv sync exited {result.exit_code}); run legion setup again"], ready_path, "fell back")
    if not version_safe(target, home):
        return AppSync([f"skip: {target} (linked)"], ready_path, "fell back")
    write_generated(target / MARKER, environment.name, executable=False)
    return AppSync([f"legion app {version} ready"], target, "published")


def app_executable(app: Path, home: Path) -> Path:
    return python_environment(app, home) / ("Scripts/legion.exe" if sys.platform == "win32" else "bin/legion")


# The app's own legion, when it is a file reached without a link; None otherwise.
def safe_executable(app: Path, home: Path) -> Optional[Path]:
    executable = app_executable(app, home)
    return executable if executable.is_file() and owner_path_safe(executable, home) else None


# True when the app's own legion answers `run --help`, so accounts can start through it.
def has_account_run(app: Path, home: Path) -> bool:
    executable = safe_executable(app, home)
    if executable is None:
        return False
    try:
        return run_command(str(executable), ["run", "--help"], timeout=60).exit_code == 0
    except OSError:
        return False


# An update runs old code. The version it confirmed writes every generated file again with its own templates.
def refresh_with_new_app(home: Path, version: str) -> list[str]:
    ready = next((item for item in ready_versions(home) if item.version == version), None)
    if ready is None:
        raise AppError(f"legion {version} is not ready")
    executable = safe_executable(ready.path, home)
    if executable is None:
        raise AppError(f"legion {version} executable is missing")
    result = run_command(str(executable), ["--home", str(home), "refresh"])
    if result.exit_code != 0:
        raise AppError(f"legion {version} refresh exited {result.exit_code}: {(result.error or result.output).strip()}")
    return result.output.splitlines()


def shim_home_argument(home: Path, windows: bool) -> str:
    if same_path(full_path(home), full_path(Path.home())):
        return ""
    return ' --home "%~dp0..\\.."' if windows else f" --home {shell_literal(str(full_path(home)))}"


# The owner command runs the app version in `app` through uv, with that version's environment.
# Hand-built, reason: batch and shell files have no standard-library serializer, and these lines are behaviour.
# Windows: cmd reads a batch file in the console code page, so the text stays ASCII: the command lives in
# <home>/.legion/bin and finds the app, its environment and the home from its own folder (%~dp0).
# One line sets the environment, runs uv and ends the batch with (goto), so a command that an
# update rewrites while it runs still ends cleanly. The hidden %=ExitCode% is uv's real code even
# when the caller has an ERRORLEVEL variable. The shell command on Windows delegates uninstall
# to the batch cleanup path. Its FOR variable keeps the copied uv out of the caller's environment.
def shim_text(app: Path, home: Path, windows: bool) -> str:
    environment = python_environment(app, home)
    home_argument = shim_home_argument(home, windows)
    if windows:
        lines = [
            header("owner command", True),
            f'@if /i "%~1"=="mcp" ("%~dp0..\\python\\{environment.name}\\Scripts\\legion.exe"{home_argument} %* & exit /b)',
            f"@where /q uv || (>&2 echo {UV_MISSING}& exit /b 127)",
            '@if /i "%~1"=="uninstall" goto uninstall',
            (
                f'@set "UV_PROJECT_ENVIRONMENT=%~dp0..\\python\\{environment.name}" & uv run --project "%~dp0..\\app\\{app.name}" --frozen --quiet legion{home_argument} %* & (goto) 2>nul & '
                'set "UV_PROJECT_ENVIRONMENT=%UV_PROJECT_ENVIRONMENT%" & "%COMSPEC%" /d /c "set /a LEGION_EXIT=0x%%=ExitCode%% >nul & call exit %%^LEGION_EXIT%%"'
            ),
            ":uninstall",
            (
                '@for %%T in ("%TEMP%\\legion-uninstall-%RANDOM%-%RANDOM%") do @(md "%%~T" 2>nul || (if exist "%%~T" (goto uninstall) else (goto temp_error)) & '
                'for %%U in (uv.exe) do @copy /b "%%~$PATH:U" "%%~T\\uv.exe" >nul & '
                f'"%%~T\\uv.exe" run --no-project --python ">=3.12" "%~dp0..\\app\\{app.name}\\src\\legion\\_self_uninstall.py" "%~dp0..\\app\\{app.name}" --uv-copy "%%~T\\uv.exe" %* & '
                '(goto) 2>nul & "%COMSPEC%" /d /c "set /a LEGION_EXIT=0x%%=ExitCode%% >nul & del /q """%%~T\\uv.exe""" & rd """%%~T""" & call exit %%^LEGION_EXIT%%")'
            ),
            ":temp_error",
            "@>&2 echo Cannot create temporary uv folder & exit /b 1",
        ]
        return "\r\n".join(lines) + "\r\n"
    lines = [
        "#!/bin/sh",
        header("owner command", False),
    ]
    if sys.platform == "win32":
        lines.append('if [ "$1" = uninstall ]; then exec "$(dirname "$0")/legion.cmd" "$@"; fi')
    lines.extend(
        [
            f'if [ "$1" = mcp ]; then exec {shell_literal(str(app_executable(app, home)))}{home_argument} "$@"; fi',
            f"command -v uv >/dev/null 2>&1 || {{ echo '{UV_MISSING}' >&2; exit 127; }}",
            f'if [ "$1" = uninstall ]; then exec uv run --no-project --python ">=3.12" {shell_literal(str(app / "src/legion/_self_uninstall.py"))} {shell_literal(str(app))} "$@"; fi',
            f"export UV_PROJECT_ENVIRONMENT={shell_literal(str(environment))}",
            # Clear any inherited hint; only MSYS (Git Bash on Windows) has winpid, elsewhere the second line does nothing.
            "unset LEGION_SHELL_WINPID LEGION_SHIM_WINPID",
            "[ -r /proc/$PPID/winpid ] && [ -r /proc/$$/winpid ] && export LEGION_SHELL_WINPID=$(cat /proc/$PPID/winpid) LEGION_SHIM_WINPID=$(cat /proc/$$/winpid)",
            f'exec uv run --project {shell_literal(str(app))} --frozen --quiet legion{home_argument} "$@"',
        ]
    )
    return "\n".join(lines) + "\n"


# Setup and refresh write the same platform command files for one ready app version, preserving unrelated files.
def write_owner_commands(app: Path, home: Path) -> list[Path]:
    changed: list[Path] = []
    for windows in [False, True] if sys.platform == "win32" else [False]:
        path = bin_folder(home) / ("legion.cmd" if windows else "legion")
        if os.path.lexists(path) and not is_owned(path, "owner command"):
            continue
        if not owner_path_safe(path, home):
            continue
        if write_generated(path, shim_text(app, home, windows), executable=not windows):
            changed.append(path)
    return changed


# True when every owner command of this home is legion's, holds no link and runs `app` exactly as written for it.
def owner_commands_run(app: Path, home: Path) -> bool:
    for windows in [False, True] if sys.platform == "win32" else [False]:
        path = bin_folder(home) / ("legion.cmd" if windows else "legion")
        if not owner_path_safe(path, home) or not is_owned(path, "owner command"):
            return False
        if path.read_bytes() != shim_text(app, home, windows).encode("utf-8"):
            return False
    return True


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


# Hand-built, reason: an app version and its uv environment must be removed as one safe unit after the last target owner leaves.
def _remove_orphan_app(home: Path, kept: list[Footprint], lines: list[str]) -> bool:
    orphan_app = [entry for entry in kept if entry.kind == "app" and not entry.owners]
    if not orphan_app:
        return False
    changed = False
    versions = [entry for entry in kept if entry.kind == "app-version"]
    for entry in versions:
        path = full_path(home_path(entry.path, home))
        if is_under(PLUGIN_ROOT, path, allow_equal=True):
            lines.append(f"Kept app version in use: {path} (close legion, then run uninstall again)")
            continue
        if not version_safe(path, home):
            lines.append(f"skip: {path} (linked or not legion's)")
            continue
        if not _remove_version(path, home):
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
