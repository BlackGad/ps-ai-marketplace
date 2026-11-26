import importlib
import re
import subprocess
import sys
import tomllib
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


def maintainer_files(paths: list[Path]) -> list[Path]:
    return [path for path in paths if MAINTAINER_NAMES & set(path.parts) or path.name.endswith(".Tests.ps1")]


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
    assert maintainer_files(copied) == []


def test_cli_lists_every_command_from_cli_package() -> None:
    main = importlib.import_module("legion.cli").main
    assert isinstance(main, Group)
    listed = CliRunner().invoke(main, ["help"]).output
    names = {name for name, command in main.commands.items() if not command.hidden}
    assert {"install", "uninstall", "status", "setup", "help"} <= names
    assert {line.split()[0] for line in listed.split("Commands:")[1].splitlines() if line.strip()} == names


def test_console_entry_point_resolves_and_lists_commands() -> None:
    project = tomllib.loads((PLUGIN / "pyproject.toml").read_text(encoding="utf-8"))
    module_name, function_name = project["project"]["scripts"]["legion"].split(":")
    command = getattr(importlib.import_module(module_name), function_name)
    assert isinstance(command, Group)
    result = subprocess.run([sys.executable, "-m", module_name, "--help"], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
    assert "status" in result.stdout


def test_fixed_entry_points_exist() -> None:
    commands = []
    for name in ("hooks.json", "copilot-hooks.json"):
        text = (PLUGIN / "hooks" / name).read_text(encoding="utf-8")
        commands += re.findall(r"PLUGIN_ROOT\}?[/\\]+(hooks[/\\]+\w+\.py)", text)
    assert len(commands) == 4
    for relative in commands:
        assert (PLUGIN / relative.replace("\\", "/")).is_file(), relative
    assert (PLUGIN / "src/legion/_self_uninstall.py").is_file()
    project = tomllib.loads((PLUGIN / "pyproject.toml").read_text(encoding="utf-8"))
    module_name, function_name = project["project"]["scripts"]["legion"].split(":")
    assert hasattr(importlib.import_module(module_name), function_name)
