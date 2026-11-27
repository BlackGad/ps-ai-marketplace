# Legion runs as a uv tool, installed from the plugin copy a CLI has just installed (offline, the same version as the plugin).
# uv is a global helper like git: legion installs and removes only its own tool, never uv.

import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Optional

from legion.core import _stop_event
from legion.core._home import path_contains, resolve_directory, same_path
from legion.core._run import display_command, run_command
from legion.core._settings_models import PluginManifest
from legion.services.installation import _handover
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


# Ends every registered legion process, then returns; on a timeout the stop event is lifted again and nothing changes.
def _stop_running(home: Path) -> None:
    remaining = _stop_event.stop_all(home)
    if remaining:
        _stop_event.clear_stop(home)
        ids = ", ".join(str(pid) for pid in remaining)
        raise UvToolError(f"legion is still running after {_stop_event.WAIT_SECONDS:g} seconds (process {ids}); close those sessions and run the command again")


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


# Replaces legion with the plugin at `plugin_root`. A repeat of the installed version changes nothing.
# Every running legion process is stopped first (the stop event). `detached` leaves the uv step to a helper that starts after
# this process exits, and lifts the stop event after it: Windows cannot replace a running legion.exe.
# By default it is detached on Windows when this process runs from the tool. `update_shell` also runs `uv tool update-shell`,
# which edits the owner's shell profile or user PATH: callers pass it only inside the owner's yes.
def install(plugin_root: Path, home: Path, dry_run: bool = False, detached: Optional[bool] = None, update_shell: bool = False) -> list[str]:
    uv = find_uv()
    if uv is None:
        return [UV_MISSING]
    version = plugin_version(plugin_root)
    if installed_version(uv) == version:
        return [f"skip: legion command {version} (already done)"]
    spec = f"{plugin_root}[mcp]"
    if dry_run:
        shell = [display_command([uv, "tool", "update-shell"])] if update_shell else []
        return [STOP_NOTICE, display_command([uv, "tool", "install", spec, "--constraints", "<exported uv.lock>", "--reinstall"]), *shell]
    if detached is None:
        detached = sys.platform == "win32" and running_from_tool(uv)
    _stop_running(home)
    folder: Optional[Path] = None
    handed_over = False
    try:
        folder = _write_constraints(uv, plugin_root)
        command = [uv, "tool", "install", spec, "--constraints", str(folder / "constraints.txt"), "--reinstall"]
        if detached:
            _handover.start_command(command, [folder, _stop_event.stop_path(home)])
            handed_over = True
            lines = [f"legion command {version} is installed when this command ends"]
        else:
            result = run_command(uv, command[1:])
            if result.exit_code != 0:
                raise _failure("uv tool install", result.error, result.exit_code)
            lines = [f"legion command {version} installed"]
    finally:
        if not handed_over:
            _stop_event.clear_stop(home)
            if folder is not None:
                shutil.rmtree(folder, ignore_errors=True)
    return [*lines, *_path_lines(uv, update_shell)]


# Removes the legion tool after this process exits; uv itself stays. Returns no line when there is nothing to remove.
# Every running legion process is stopped first; the helper lifts the stop event after the uv step.
def uninstall(home: Path, dry_run: bool = False) -> list[str]:
    uv = find_uv()
    if uv is None or installed_version(uv) is None:
        return []
    command = [uv, "tool", "uninstall", TOOL]
    if dry_run:
        return [STOP_NOTICE, display_command(command)]
    _stop_running(home)
    _handover.start_command(command, [_stop_event.stop_path(home)])
    return ["legion command is removed when this command ends"]
