from pathlib import Path

import pytest
from app_fakes import FakeUv, make_link, make_source

from legion.core import _settings_io
from legion.core._home import settings_path
from legion.services.installation import _refresh


# Every test runs against a fake uv, so no test can start the real one.
pytestmark = pytest.mark.usefixtures("uv")


@pytest.fixture
def uv(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> FakeUv:
    return FakeUv(monkeypatch, tmp_path / "uv bin")


def run(home: Path, detached: bool | None = None) -> list[str]:
    return _refresh.refresh(home, make_source(home.parent / f"source-{home.name}"), detached)


def test_refresh_with_no_settings_file_installs_the_tool_and_a_repeat_skips(tmp_path: Path, uv: FakeUv) -> None:
    assert run(tmp_path)[0] == "legion command 1.0.0 installed"
    assert run(tmp_path) == ["skip: legion command 1.0.0 (already done)"]
    assert len(uv.installs()) == 1


def test_refresh_passes_the_consent_for_update_shell_on(tmp_path: Path, uv: FakeUv) -> None:
    _refresh.refresh(tmp_path, make_source(tmp_path / "source"))
    assert ["tool", "update-shell"] not in uv.calls
    _refresh.refresh(tmp_path, make_source(tmp_path / "other", "2.0.0"), update_shell=True)
    assert ["tool", "update-shell"] in uv.calls


def test_refresh_with_a_broken_settings_file_still_fails_before_uv_runs(tmp_path: Path, uv: FakeUv) -> None:
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_text("{", encoding="utf-8")
    with pytest.raises(_settings_io.SettingsError):
        run(tmp_path)
    assert uv.calls == []


def test_a_linked_legion_folder_is_refused_before_settings_lock(tmp_path: Path, uv: FakeUv) -> None:
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / "home" / ".legion", elsewhere)
    with pytest.raises(_settings_io.SettingsError, match="link"):
        run(tmp_path / "home")
    assert list(elsewhere.iterdir()) == []
    assert uv.calls == []


def test_a_detached_refresh_hands_the_install_over(tmp_path: Path, uv: FakeUv) -> None:
    lines = run(tmp_path, detached=True)
    assert "legion command 1.0.0 is installed when this command ends" in lines
    assert uv.installs() == []
    assert len(uv.detached) == 1
