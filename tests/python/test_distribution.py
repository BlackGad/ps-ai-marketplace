import importlib
import os
import re
import runpy
import subprocess
import sys
import tomllib
from fnmatch import fnmatch
from pathlib import Path

import pytest
from click.core import Group
from click.testing import CliRunner

from conftest import fence_git
from legion.core._run import RunResult, run_command
from legion.services.installation import _installed_runtime


ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "plugins/legion"
MAINTAINER_NAMES = {"tests", "tools", "ruff.toml", "pyrightconfig.json", "pytest.ini", ".coveragerc", "conftest.py"}
MAINTAINER_PATTERNS = ("*.Tests.ps1", "test_*.py", "*_test.py")


def maintainer_files(paths: list[Path]) -> list[Path]:
    return [path for path in paths if MAINTAINER_NAMES & set(path.parts) or any(fnmatch(path.name, pattern) for pattern in MAINTAINER_PATTERNS)]


def console_command() -> Group:
    project = tomllib.loads((PLUGIN / "pyproject.toml").read_text(encoding="utf-8"))
    module_name, function_name = project["project"]["scripts"]["legion"].split(":")
    command = getattr(importlib.import_module(module_name), function_name)
    assert isinstance(command, Group)
    return command


def test_plugin_tree_has_no_maintainer_files(monkeypatch: pytest.MonkeyPatch) -> None:
    fence_git(monkeypatch)
    listing = run_command("git", ["-c", "core.quotepath=off", "-C", str(ROOT), "ls-files", "--", "plugins/legion"])
    assert listing.exit_code == 0, listing.error
    tracked = [Path(name).relative_to("plugins/legion") for name in listing.output.splitlines()]
    assert tracked
    assert maintainer_files(tracked) == []


def test_app_copy_has_only_client_files(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_uv(*_arguments: object, **_options: object) -> RunResult:
        return RunResult(exit_code=0, output="", error="", timed_out=False)

    monkeypatch.setattr(_installed_runtime, "find_uv", lambda: "uv")
    monkeypatch.setattr(_installed_runtime, "run_command", fake_uv)
    home = tmp_path / "home"
    _lines, ready, state = _installed_runtime.sync_app(home)
    assert state == "published"
    assert ready is not None
    copied = [path.relative_to(ready) for path in ready.rglob("*") if path.is_file() and "__pycache__" not in path.parts]
    assert Path("plugin.json") in copied
    assert Path("src/legion/cli/__init__.py") in copied
    assert Path("src/legion/_self_uninstall.py") in copied
    assert maintainer_files(copied) == []


@pytest.mark.parametrize("use_uv_copy", [False, True])
def test_owner_commands_from_018_forward_uninstall(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, use_uv_copy: bool) -> None:
    home = tmp_path / "Owner Home"
    app = home / ".legion/app/0.18.1"
    app.mkdir(parents=True)
    bin_dir = home / ".legion/bin"
    bin_dir.mkdir()
    uv_copy = str(tmp_path / "copied uv" / "uv.exe")
    script = PLUGIN / "src/legion/_self_uninstall.py"
    arguments = ["uninstall", "--purge", "--yes"]
    uv_option = ["--uv-copy", uv_copy] if use_uv_copy else []
    monkeypatch.setattr(sys, "argv", [str(script), str(bin_dir / "../app/0.18.1"), *uv_option, *arguments])
    monkeypatch.setenv("UV_PROJECT_ENVIRONMENT", str(tmp_path / "outer-env"))

    def fake_uv(command: list[str], *, env: dict[str, str], check: bool) -> subprocess.CompletedProcess[str]:
        uv = uv_copy if use_uv_copy else "uv"
        assert command == [uv, "run", "--project", str(app), "--frozen", "--quiet", "legion", "--home", str(home), *arguments]
        assert env == {**os.environ, "UV_PROJECT_ENVIRONMENT": str(_installed_runtime.python_environment(app, home))}
        assert not check
        return subprocess.CompletedProcess(command, 23)

    monkeypatch.setattr(subprocess, "run", fake_uv)
    with pytest.raises(SystemExit) as exit_info:
        runpy.run_path(str(script), run_name="__main__")
    assert exit_info.value.code == 23


def test_cli_lists_every_command_from_cli_package() -> None:
    main = console_command()
    result = CliRunner().invoke(main, ["help"])
    assert result.exit_code == 0, result.output
    names = {name for name, command in main.commands.items() if not command.hidden}
    assert {"install", "uninstall", "status", "setup", "help"} <= names
    assert {line.split()[0] for line in result.output.split("Commands:")[1].splitlines() if line.strip()} == names


# Manifests.Tests.ps1 asserts each full command line and its event; here only the exact script path must exist.
def test_fixed_entry_points_exist() -> None:
    scripts = []
    for name in ("hooks.json", "copilot-hooks.json"):
        text = (PLUGIN / "hooks" / name).read_text(encoding="utf-8")
        scripts += re.findall(r'PLUGIN_ROOT\}?[/\\]+(hooks[/\\]+session_start\.py)\\?"', text)
    assert len(scripts) == 4
    for relative in scripts:
        assert (PLUGIN / relative.replace("\\", "/")).is_file(), relative
    console_command()
