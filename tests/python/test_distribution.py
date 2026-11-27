import importlib
import re
import tomllib
from fnmatch import fnmatch
from pathlib import Path

import pytest
from click.core import Group
from click.testing import CliRunner

from conftest import fence_git
from legion.core._run import run_command


ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "plugins/legion"
MAINTAINER_NAMES = {"tests", "tools", "conftest.py"}
MAINTAINER_PATTERNS = ("*.Tests.ps1", "test_*.py", "*_test.py")


def maintainer_files(paths: list[Path]) -> list[Path]:
    return [
        path
        for path in paths
        if MAINTAINER_NAMES & set(path.parts) or any(fnmatch(path.name, pattern) for pattern in MAINTAINER_PATTERNS) or (path.name == "pyproject.toml" and path != Path("pyproject.toml"))
    ]


def test_repo_tool_config_stays_outside_the_client_project() -> None:
    root = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
    client = tomllib.loads((PLUGIN / "pyproject.toml").read_text(encoding="utf-8"))
    tools = {"ruff", "pyright", "pytest", "coverage"}
    assert "project" not in root
    assert tools <= root["tool"].keys()
    assert not tools & client["tool"].keys()
    standalone = ["ruff.toml", ".ruff.toml", "pyrightconfig.json", "pytest.ini", ".coveragerc", "setup.cfg", "tox.ini"]
    assert [name for name in standalone if (PLUGIN / name).exists()] == []


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


def test_cli_lists_every_command_from_cli_package() -> None:
    main = console_command()
    result = CliRunner().invoke(main, ["help"])
    assert result.exit_code == 0, result.output
    names = {name for name, command in main.commands.items() if not command.hidden}
    assert {"install", "uninstall", "status", "setup", "help"} <= names
    assert {line.split()[0] for line in result.output.split("Commands:")[1].splitlines() if line.strip()} == names


# repository/test_manifests.py::test_hook_commands_use_the_required_root_and_format asserts each full command line and its event; here only the exact script path must exist.
def test_fixed_entry_points_exist() -> None:
    scripts = []
    for name in ("hooks.json", "copilot-hooks.json"):
        text = (PLUGIN / "hooks" / name).read_text(encoding="utf-8")
        scripts += re.findall(r'PLUGIN_ROOT\}?[/\\]+(hooks[/\\]+session_start\.py)\\?"', text)
    assert len(scripts) == 4
    for relative in scripts:
        assert (PLUGIN / relative.replace("\\", "/")).is_file(), relative
    console_command()
