# uv installs Legion from the plugin copy, using its version and locked dependencies.

import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Optional

from legion.core import _settings_io, _stop_event
from legion.core._home import (
    owner_path_safe,
    path_contains,
    resolve_directory,
    same_path,
    settings_path,
)
from legion.core._run import display_command, run_command
from legion.core._settings_models import PluginManifest
from legion.services.installation import _handover, _user_path
from legion.services.installation._constraints import export_constraints

UV_MISSING = "uv is missing. Ask the owner before installing it, then run the legion installer again."
TOOL = "legion"
STOP_NOTICE = "stop     running legion sessions (mcp servers and runs) end first"


class UvToolError(ValueError):
    pass


def find_uv() -> Optional[str]:
    return shutil.which("uv")


def _failure(action: str, result_error: str, exit_code: int) -> UvToolError:
    detail = result_error.strip()
    return UvToolError(f"{action} exited {exit_code}" + (f"\n{detail}" if detail else ""))


def plugin_version(plugin_root: Path) -> str:
    return PluginManifest.model_validate_json((plugin_root / "plugin.json").read_text(encoding="utf-8-sig")).version


# The version of the installed legion tool, or None when uv lists none.
def installed_version(uv: str) -> Optional[str]:
    result = run_command(uv, ["tool", "list"])
    if result.exit_code != 0:
        return None
    for line in result.output.splitlines():
        words = line.split()
        if len(words) > 1 and words[0] == TOOL and words[1].startswith("v"):
            return words[1].removeprefix("v")
    return None


def bin_directory(uv: str) -> Optional[Path]:
    result = run_command(uv, ["tool", "dir", "--bin"])
    return Path(result.output.strip()) if result.exit_code == 0 and result.output.strip() else None


def path_missing(uv: str) -> bool:
    folder = bin_directory(uv)
    return folder is not None and not path_contains(_saved_path(), folder)


def _saved_path() -> str:
    if sys.platform == "win32":
        return os.pathsep.join(_user_path.persistent_folders())
    return os.environ.get("PATH", "")


# The lock file's exact versions, written into a folder of its own, which the caller removes.
def _write_constraints(uv: str, plugin_root: Path) -> Path:
    folder = Path(tempfile.mkdtemp(prefix="legion-constraints-"))
    try:
        (folder / "constraints.txt").write_text(export_constraints(plugin_root, uv), encoding="utf-8")
    except (RuntimeError, OSError) as error:
        shutil.rmtree(folder, ignore_errors=True)
        raise UvToolError(str(error)) from error
    return folder


# True when this process runs from the legion tool itself, whose files uv is about to replace.
def running_from_tool(uv: str) -> bool:
    result = run_command(uv, ["tool", "dir"])
    return result.exit_code == 0 and bool(result.output.strip()) and same_path(resolve_directory(Path(sys.prefix)), resolve_directory(Path(result.output.strip()) / TOOL))


# Waits for registered processes that can be stopped. On a timeout, lift the stop event before reporting the failure.
def stop_running(home: Path) -> None:
    if not owner_path_safe(_stop_event.stop_path(home), home):
        raise UvToolError("The legion stop file path contains a link; resolve it before continuing")
    remaining = _stop_event.stop_all(home)
    if remaining:
        _stop_event.clear_stop(home)
        ids = ", ".join(str(pid) for pid in remaining)
        raise UvToolError(f"legion is still running after {_stop_event.WAIT_SECONDS:g} seconds (process {ids}); close those sessions and run the command again")


def _hand_over(home: Path, command: list[str], cleanup: list[Path], purge: list[Path]) -> None:
    log = home / ".legion/temp/uv-tool.log"
    if not owner_path_safe(log, home):
        if command:
            raise UvToolError("The uv tool log path contains a link; resolve it before continuing")
        # A cleanup-only purge can remove the link without writing through it.
        _handover.start(command, cleanup, purge=purge, log=None)
        return
    if purge and log.parent not in purge and log.parent.parent not in purge:
        # Keeping the hub can leave a new log directory outside the original purge list.
        purge = [*purge, log.parent]
    _handover.start(command, cleanup, purge=purge, log=log)


# The saved PATH is uv's to write, and only with the owner's yes. The current process learns the folder from uv.
# A failed update-shell is only a warning.
def _path_lines(uv: str, update_shell: bool) -> list[str]:
    lines: list[str] = []
    if update_shell:
        result = run_command(uv, ["tool", "update-shell"])
        if result.exit_code != 0:
            lines.append(f"uv tool update-shell exited {result.exit_code}; add the uv tool folder to your PATH yourself")
    folder = bin_directory(uv)
    if folder is not None and not path_contains(os.environ.get("PATH", ""), folder):
        os.environ["PATH"] = str(folder) + os.pathsep + os.environ.get("PATH", "")
    return lines


# Replaces legion with the plugin at `plugin_root`. A repeat only repairs PATH if needed and approved.
# The stop event precedes replacement. `detached` leaves the uv step to a helper that starts after
# this process exits, and lifts the stop event after it: Windows cannot replace a running legion.exe.
# By default it is detached when this process runs from the tool. `update_shell` also runs `uv tool update-shell`,
# which edits the owner's shell profile or user PATH: callers pass it only inside the owner's yes.
def install(plugin_root: Path, home: Path, dry_run: bool = False, detached: Optional[bool] = None, update_shell: bool = False) -> list[str]:
    if not dry_run:
        if not owner_path_safe(home / ".legion", home):
            raise _settings_io.SettingsError("The legion folder contains a link; resolve it before installing")
        with _settings_io.writer(home, require_existing=False):
            if settings_path(home).is_file():
                _settings_io.load(home)
    uv = find_uv()
    if uv is None:
        return [UV_MISSING]
    version = plugin_version(plugin_root)
    if installed_version(uv) == version:
        lines = [f"skip: legion command {version} (already done)"]
        if update_shell and path_missing(uv):
            lines.extend([display_command([uv, "tool", "update-shell"])] if dry_run else _path_lines(uv, True))
        return lines
    spec = f"{plugin_root}[mcp]"
    if dry_run:
        shell = [display_command([uv, "tool", "update-shell"])] if update_shell else []
        return [STOP_NOTICE, display_command([uv, "tool", "install", spec, "--constraints", "<exported uv.lock>", "--reinstall"]), *shell]
    if detached is None:
        detached = running_from_tool(uv)
    stop_running(home)
    folder: Optional[Path] = None
    handed_over = False
    try:
        folder = _write_constraints(uv, plugin_root)
        command = [uv, "tool", "install", spec, "--constraints", str(folder / "constraints.txt"), "--reinstall"]
        if detached:
            path_lines = _path_lines(uv, update_shell)
            _hand_over(home, command, [folder, _stop_event.stop_path(home)], [])
            handed_over = True
            return [f"legion command {version} is installed when this command ends", *path_lines]
        result = run_command(uv, command[1:])
        if result.exit_code != 0:
            raise _failure("uv tool install", result.error, result.exit_code)
    finally:
        if not handed_over:
            _stop_event.clear_stop(home)
            if folder is not None:
                shutil.rmtree(folder, ignore_errors=True)
    return [f"legion command {version} installed", *_path_lines(uv, update_shell)]


# Remove the tool and any approved folders after exit. The helper also lifts the stop event.
def uninstall(home: Path, dry_run: bool = False, *, stopped: bool = False, purge: list[Path] | None = None) -> list[str]:
    uv = find_uv()
    command = [uv, "tool", "uninstall", TOOL] if uv is not None and installed_version(uv) is not None else []
    purge = purge or []
    if not (command or purge):
        return []
    if dry_run:
        return [STOP_NOTICE, display_command(command)] if command else []
    if command and not stopped:
        stop_running(home)
        stopped = True
    try:
        _hand_over(home, command, [_stop_event.stop_path(home)] if stopped else [], purge)
    except BaseException:
        if stopped:
            _stop_event.clear_stop(home)
        raise
    lines = ["legion command is removed when this command ends"] if command else []
    if purge:
        lines.append("done: legion folders are removed when this command ends")
    return lines
