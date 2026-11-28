from pathlib import Path

import pytest
from launcher_fakes import (
    WINDOWS,
    agent,
    fake_cli,
    only_on_path,
    tool,
)

from legion.services.accounts import _launchers
from legion.core._settings_models import ToolDescriptor

# The home name holds what shells and cmd.exe treat as syntax; every lookup must keep it literal.
HOME_NAME = "owner $(echo x) & 100%x'q"
windows_only = pytest.mark.skipif(not WINDOWS, reason="Windows file names")


@pytest.fixture
def home(tmp_path: Path, stock: Path) -> Path:
    # Every lookup test finds the stock CLI on a PATH of its own.
    assert stock.is_file()
    path = tmp_path / HOME_NAME
    path.mkdir()
    return path


@pytest.fixture
def stock(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    command = fake_cli(tmp_path / "stock bin", "codex")
    only_on_path(monkeypatch, command.parent)
    monkeypatch.chdir(tmp_path)
    return command


def codex() -> ToolDescriptor:
    return tool("codex")


def test_target_is_the_agents_command_when_it_is_a_file(home: Path, tmp_path: Path) -> None:
    custom = fake_cli(tmp_path / "custom", "my-codex")
    assert _launchers.target(agent("codex-a", home / "a", command=str(custom)), codex(), home) == custom
    # '~/' means the legion home root.
    inside = fake_cli(home / "tools", "inside")
    assert _launchers.target(agent("codex-a", home / "a", command="~/tools/" + inside.name), codex(), home) == inside


def test_target_needs_the_owner_when_the_command_is_not_a_file(home: Path, tmp_path: Path) -> None:
    gone = tmp_path / "gone"
    with pytest.raises(_launchers.LauncherError, match=r"^target needed: codex-a; ask the owner for the registered executable$"):
        _launchers.target(agent("codex-a", home / "a", command=str(gone)), codex(), home)


def test_target_is_the_stock_command_without_a_command(home: Path, stock: Path) -> None:
    assert _launchers.target(agent("codex-a", home / "a"), codex(), home) == stock
    assert _launchers.is_stock(stock, codex())
    assert not _launchers.is_stock(stock.parent / "other", codex())


# shutil.which spells the extension as PATHEXT does (codex.CMD); the file is codex.cmd.
@windows_only
def test_target_keeps_the_file_name_as_it_is_on_disk(home: Path, stock: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("PATHEXT", ".COM;.EXE;.BAT;.CMD")
    assert stock.name == "codex.cmd"
    assert _launchers.target(agent("codex-a", home / "a"), codex(), home).name == "codex.cmd"
