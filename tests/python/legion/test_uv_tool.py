# Install, update and uninstall of the legion command through a recording fake uv. No test starts the real uv.
import os
import shutil
import tempfile
from pathlib import Path

import pytest
from app_fakes import FakeUv, make_source

from legion.services.installation import _uv_tool


@pytest.fixture
def uv(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> FakeUv:
    return FakeUv(monkeypatch, tmp_path / "uv bin")


def test_install_exports_the_lock_then_installs_non_editable_with_the_extra_and_updates_the_path(tmp_path: Path, uv: FakeUv) -> None:
    source = make_source(tmp_path)
    assert _uv_tool.install(source) == ["legion command 1.0.0 installed"]
    export = next(call for call in uv.calls if call[0] == "export")
    assert export[:7] == ["export", "--frozen", "--no-default-groups", "--extra", "mcp", "--no-emit-project", "--no-hashes"]
    assert export[export.index("--project") + 1] == str(source)
    constraints = export[export.index("--output-file") + 1]
    assert uv.installs() == [["tool", "install", f"{source}[mcp]", "--constraints", constraints, "--reinstall"]]
    assert ["tool", "update-shell"] in uv.calls
    assert not Path(constraints).parent.exists()
    assert os.environ["PATH"].split(os.pathsep)[0] == str(uv.bin)


def test_a_repeat_of_the_installed_version_prints_skip_and_changes_nothing(tmp_path: Path, uv: FakeUv) -> None:
    source = make_source(tmp_path)
    _uv_tool.install(source)
    uv.calls.clear()
    assert _uv_tool.install(source) == ["skip: legion command 1.0.0 (already done)"]
    assert uv.calls == [["tool", "list"]]


def test_a_new_plugin_version_replaces_the_installed_one(tmp_path: Path, uv: FakeUv) -> None:
    uv.installed = "0.9.0"
    assert _uv_tool.install(make_source(tmp_path))[0] == "legion command 1.0.0 installed"
    assert uv.installed == "1.0.0"


def test_a_detached_install_starts_the_helper_and_runs_no_install_itself(tmp_path: Path, uv: FakeUv) -> None:
    source = make_source(tmp_path)
    lines = _uv_tool.install(source, detached=True)
    assert lines[0] == "legion command 1.0.0 is installed when this command ends"
    assert uv.installs() == []
    ((command, remove),) = uv.detached
    assert command[:3] == ["uv", "tool", "install"]
    assert command[3] == f"{source}[mcp]"
    assert remove is not None
    assert command[command.index("--constraints") + 1] == str(remove / "constraints.txt")
    assert (remove / "constraints.txt").read_text(encoding="utf-8") == "mcp==1.0.0\n"
    shutil.rmtree(remove)


def test_a_dry_run_shows_the_commands_and_changes_nothing(tmp_path: Path, uv: FakeUv) -> None:
    lines = _uv_tool.install(make_source(tmp_path), dry_run=True)
    assert "tool install" in lines[0]
    assert "[mcp]" in lines[0]
    assert "--reinstall" in lines[0]
    assert "tool update-shell" in lines[1]
    assert uv.calls == [["tool", "list"]]
    assert uv.detached == []


def test_a_failed_install_reports_the_exit_code_and_leaves_no_constraints_file(tmp_path: Path, uv: FakeUv) -> None:
    uv.fail["tool install"] = 2
    with pytest.raises(_uv_tool.UvToolError, match="exited 2"):
        _uv_tool.install(make_source(tmp_path))
    assert not list(Path(tempfile.gettempdir()).glob("legion-constraints-*"))


def test_a_failed_export_stops_before_installing(tmp_path: Path, uv: FakeUv) -> None:
    uv.fail["export --frozen"] = 1
    with pytest.raises(_uv_tool.UvToolError, match="uv export exited 1"):
        _uv_tool.install(make_source(tmp_path))
    assert uv.installs() == []


def test_a_failed_update_shell_is_a_warning_not_an_error(tmp_path: Path, uv: FakeUv) -> None:
    uv.fail["tool update-shell"] = 1
    lines = _uv_tool.install(make_source(tmp_path))
    assert any("update-shell exited 1" in line for line in lines)
    assert uv.installed == "1.0.0"


def test_without_uv_install_says_so_and_runs_nothing(tmp_path: Path, uv: FakeUv, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_uv_tool, "find_uv", lambda: None)
    assert _uv_tool.install(make_source(tmp_path)) == [_uv_tool.UV_MISSING]
    assert uv.calls == []


def test_uninstall_hands_only_the_tool_removal_to_the_helper(uv: FakeUv) -> None:
    uv.installed = "1.0.0"
    assert _uv_tool.uninstall() == ["legion command is removed when this command ends"]
    assert uv.detached == [(["uv", "tool", "uninstall", "legion"], None)]
    assert uv.calls == [["tool", "list"]]


def test_uninstall_of_a_missing_tool_does_nothing(uv: FakeUv) -> None:
    assert _uv_tool.uninstall() == []
    assert uv.detached == []


def test_uninstall_dry_run_shows_the_command_and_starts_nothing(uv: FakeUv) -> None:
    uv.installed = "1.0.0"
    assert _uv_tool.uninstall(dry_run=True) == ["uv tool uninstall legion"]
    assert uv.detached == []


# uv is a global helper like git: no command legion runs ever removes or replaces it.
def test_no_legion_command_touches_uv_itself(tmp_path: Path, uv: FakeUv) -> None:
    uv.installed = "0.9.0"
    _uv_tool.install(make_source(tmp_path))
    _uv_tool.install(make_source(tmp_path / "again", "2.0.0"), detached=True)
    _uv_tool.uninstall()
    for arguments in [*uv.calls, *(command[1:] for command, _remove in uv.detached)]:
        assert arguments[0] in {"tool", "export"}
        assert arguments[:2] != ["tool", "uninstall"] or arguments[2:] == ["legion"]
        assert "self" not in arguments
