# Legion runs as a uv tool, installed from the plugin copy a CLI has just installed (offline, the same version as the plugin).
# uv is a global helper like git: legion installs and removes only its own tool, never uv.

import os
import shutil
import sys
import tempfile
from pathlib import Path
from typing import Optional

from legion.core._home import path_contains
from legion.core._run import display_command, run_command
from legion.core._settings_models import PluginManifest
from legion.services.installation import _handover

UV_MISSING = "uv is missing. Ask the owner before installing it, then run the legion installer again."
TOOL = "legion"


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


def tool_executable(uv: str) -> Optional[Path]:
    folder = bin_directory(uv)
    return folder / ("legion.exe" if sys.platform == "win32" else "legion") if folder else None


# True when the tool's legion answers `run --help`, so accounts can start through it.
def has_account_run(uv: str) -> bool:
    executable = tool_executable(uv)
    if executable is None or not executable.is_file():
        return False
    try:
        return run_command(str(executable), ["run", "--help"], timeout=60).exit_code == 0
    except OSError:
        return False


# Private helper, to merge with the uv.lock export of the wheel task: the exact versions the plugin's lock file pins.
# The file lives in a folder of its own, which the caller removes.
def _export_constraints(uv: str, plugin_root: Path) -> Path:
    folder = Path(tempfile.mkdtemp(prefix="legion-constraints-"))
    arguments = [
        "export",
        "--frozen",
        "--no-default-groups",
        "--extra",
        "mcp",
        "--no-emit-project",
        "--no-hashes",
        "--quiet",
        "--project",
        str(plugin_root),
        "--output-file",
        str(folder / "constraints.txt"),
    ]
    result = run_command(uv, arguments)
    if result.exit_code != 0:
        shutil.rmtree(folder, ignore_errors=True)
        raise _failure("uv export", result.error, result.exit_code)
    return folder


# The saved PATH is uv's to write; the current process learns the folder from uv. A failed update-shell is only a warning.
def _path_lines(uv: str) -> list[str]:
    lines: list[str] = []
    result = run_command(uv, ["tool", "update-shell"])
    if result.exit_code != 0:
        lines.append(f"uv tool update-shell exited {result.exit_code}; add the uv tool folder to your PATH yourself")
    folder = bin_directory(uv)
    if folder is not None and not path_contains(os.environ.get("PATH", ""), folder):
        os.environ["PATH"] = str(folder) + os.pathsep + os.environ.get("PATH", "")
    return lines


# Replaces legion with the plugin at `plugin_root`. A repeat of the installed version changes nothing.
# `detached` leaves the uv step to a helper that starts after this process exits: Windows cannot replace a running legion.exe.
def install(plugin_root: Path, dry_run: bool = False, detached: bool = False) -> list[str]:
    uv = find_uv()
    if uv is None:
        return [UV_MISSING]
    version = plugin_version(plugin_root)
    if installed_version(uv) == version:
        return [f"skip: legion command {version} (already done)"]
    spec = f"{plugin_root}[mcp]"
    if dry_run:
        return [display_command([uv, "tool", "install", spec, "--constraints", "<exported uv.lock>", "--reinstall"]), display_command([uv, "tool", "update-shell"])]
    folder = _export_constraints(uv, plugin_root)
    command = [uv, "tool", "install", spec, "--constraints", str(folder / "constraints.txt"), "--reinstall"]
    if detached:
        _handover.start_command(command, folder)
        lines = [f"legion command {version} is installed when this command ends"]
    else:
        try:
            result = run_command(uv, command[1:])
        finally:
            shutil.rmtree(folder, ignore_errors=True)
        if result.exit_code != 0:
            raise _failure("uv tool install", result.error, result.exit_code)
        lines = [f"legion command {version} installed"]
    return [*lines, *_path_lines(uv)]


# Removes the legion tool after this process exits; uv itself stays. Returns no line when there is nothing to remove.
def uninstall(dry_run: bool = False) -> list[str]:
    uv = find_uv()
    if uv is None or installed_version(uv) is None:
        return []
    command = [uv, "tool", "uninstall", TOOL]
    if dry_run:
        return [display_command(command)]
    _handover.start_command(command)
    return ["legion command is removed when this command ends"]
