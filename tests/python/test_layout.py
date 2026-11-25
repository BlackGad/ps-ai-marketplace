from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PACKAGE = ROOT / "plugins/legion/src/legion"


def test_runtime_modules_live_in_packages() -> None:
    assert sorted(path.name for path in PACKAGE.glob("_*.py")) == ["__init__.py", "_self_uninstall.py"]
    assert (PACKAGE / "cli/__init__.py").is_file()
    assert (PACKAGE / "hook/__init__.py").is_file()
    assert (PACKAGE / "services/installer/__init__.py").is_file()


def test_console_target_uses_cli_package() -> None:
    project = (ROOT / "plugins/legion/pyproject.toml").read_text(encoding="utf-8")
    assert 'legion = "legion.cli:main"' in project


def test_powershell_checks_are_grouped_by_subject() -> None:
    assert not list((ROOT / "tests").glob("*.Tests.ps1"))
    assert list((ROOT / "tests/repository").glob("*.Tests.ps1"))
