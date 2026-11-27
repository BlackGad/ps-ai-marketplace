import ast
import importlib
from pathlib import Path
from typing import get_args

import pytest

from legion import cli
from legion.core import _home
from legion.services.accounts import _launchers
from legion.services.installation import _user_path
from legion.services.repository import _footprints


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "plugins/legion/src/legion"


def test_runtime_modules_live_in_packages() -> None:
    assert sorted(path.name for path in PACKAGE.glob("_*.py")) == ["__init__.py"]
    assert (PACKAGE / "cli/__init__.py").is_file()
    assert (PACKAGE / "hook/__init__.py").is_file()
    assert (PACKAGE / "services/installation/installer/__init__.py").is_file()
    assert (PACKAGE / "services/installation/_uv_tool.py").is_file()
    assert (PACKAGE / "core/_stop_event.py").is_file()


def test_the_legacy_runtime_layout_and_old_launcher_helpers_are_gone() -> None:
    assert not (PACKAGE / "services/installation/_installed_runtime.py").exists()
    assert not (PACKAGE / "_self_uninstall.py").exists()
    for name in ("services.installation._installed_runtime", "_self_uninstall"):
        with pytest.raises(ModuleNotFoundError):
            importlib.import_module(f"legion.{name}")
    assert not hasattr(_home, "bin_folder")
    for name in ("candidates", "remove_old_launchers", "old_launchers_may_remain", "launcher_paths"):
        assert not hasattr(_launchers, name)
    for name in ("shell_profile", "shell_profile_lines"):
        assert not hasattr(_user_path, name)
    assert "app-version" not in get_args(_footprints.FootprintKind)


def test_the_hidden_refresh_command_is_gone() -> None:
    assert "refresh" not in cli.main.commands


def test_services_are_grouped_by_area() -> None:
    services = PACKAGE / "services"
    assert sorted(path.name for path in services.glob("*.py")) == ["__init__.py"]
    for area in ("accounts", "installation", "repository", "channels", "foundry", "limits", "status"):
        assert (services / area / "__init__.py").is_file()


def test_core_and_services_import_only_lower_layers() -> None:
    for layer, forbidden in (("core", ("legion.services", "legion.cli", "legion.hook")), ("services", ("legion.cli", "legion.hook"))):
        for source in (PACKAGE / layer).rglob("*.py"):
            tree = ast.parse(source.read_text(encoding="utf-8"))
            imported = [f"{node.module}.{alias.name}" for node in ast.walk(tree) if isinstance(node, ast.ImportFrom) and node.module for alias in node.names]
            imported += [alias.name for node in ast.walk(tree) if isinstance(node, ast.Import) for alias in node.names]
            imported += [
                node.args[0].value
                for node in ast.walk(tree)
                if isinstance(node, ast.Call)
                and isinstance(node.func, ast.Attribute)
                and node.func.attr == "import_module"
                and node.args
                and isinstance(node.args[0], ast.Constant)
                and isinstance(node.args[0].value, str)
            ]
            assert not any(name == prefix or name.startswith(prefix + ".") for name in imported for prefix in forbidden), source


def test_console_target_uses_cli_package() -> None:
    project = (ROOT / "plugins/legion/pyproject.toml").read_text(encoding="utf-8")
    assert 'legion = "legion.cli:main"' in project


def test_only_bootstrap_repository_checks_use_powershell() -> None:
    assert not list((ROOT / "tests").glob("*.Tests.ps1"))
    assert [path.name for path in (ROOT / "tests/repository").glob("*.Tests.ps1")] == ["Bootstrap.Tests.ps1"]
