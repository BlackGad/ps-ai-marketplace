import importlib
import json
import subprocess
import sys
import tomllib
from pathlib import Path

from click.core import Group


ROOT = Path(__file__).resolve().parents[2]
PLUGIN = ROOT / "plugins/legion"


def test_client_plugin_tree_excludes_maintainer_files() -> None:
    assert not list(PLUGIN.rglob("*.Tests.ps1"))
    assert not list(PLUGIN.rglob("conftest.py"))
    for name in ("tests", "tools", "ruff.toml", "pyrightconfig.json", "pytest.ini", ".coveragerc"):
        assert not (PLUGIN / name).exists()


def test_console_entry_point_resolves_and_lists_commands() -> None:
    project = tomllib.loads((PLUGIN / "pyproject.toml").read_text(encoding="utf-8"))
    module_name, function_name = project["project"]["scripts"]["legion"].split(":")
    command = getattr(importlib.import_module(module_name), function_name)
    assert isinstance(command, Group)
    result = subprocess.run([sys.executable, "-m", module_name, "--help"], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
    assert "status" in result.stdout


def test_a_plain_uv_sync_installs_the_mcp_sdk_through_the_extra() -> None:
    # The released 0.17.0 updater syncs a new app with `uv sync --frozen` and no extra, then never runs it.
    # Only a default group reaches that sync; it names the extra, so the SDK constraint has one home.
    project = tomllib.loads((PLUGIN / "pyproject.toml").read_text(encoding="utf-8"))
    groups = project["tool"]["uv"]["default-groups"]
    assert [requirement for group in groups for requirement in project["dependency-groups"][group]] == ["legion[mcp]"]
    assert [requirement for requirement in project["project"]["optional-dependencies"]["mcp"] if requirement.startswith("mcp")] == ["mcp>=1.30,<2"]
    lock = tomllib.loads((PLUGIN / "uv.lock").read_text(encoding="utf-8"))
    legion = next(package for package in lock["package"] if package["name"] == "legion")
    assert {"name": "legion", "extra": ["mcp"]} in legion["dev-dependencies"][groups[0]]


def test_fixed_file_entries_exist() -> None:
    assert (PLUGIN / "hooks/session_start.py").is_file()
    assert (PLUGIN / "src/legion/_self_uninstall.py").is_file()
    claude = json.loads((PLUGIN / "hooks/hooks.json").read_text(encoding="utf-8"))
    copilot = json.loads((PLUGIN / "hooks/copilot-hooks.json").read_text(encoding="utf-8"))
    assert "hooks/session_start.py" in claude["hooks"]["SessionStart"][0]["hooks"][0]["command"]
    assert "hooks/session_start.py" in copilot["hooks"]["sessionStart"][0]["bash"]


def test_hook_import_stays_in_standard_library() -> None:
    script = "import sys; import legion.hook; assert not {'pydantic', 'click', 'filelock', 'mcp', 'psutil'} & sys.modules.keys()"
    result = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
