# The Windows user PATH entries of portable tools legion installs. No real registry is touched.
import sys
from pathlib import Path

import pytest

from legion.services.installation import _user_path
from legion.services.repository import _footprints


@pytest.fixture
def home(tmp_path: Path) -> Path:
    (tmp_path / "home").mkdir()
    return tmp_path / "home"


def saved_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, text: str) -> Path:
    saved = tmp_path / "user-path.txt"
    saved.write_text(text, encoding="utf-8")
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(saved))
    return saved


@pytest.mark.skipif(sys.platform != "win32", reason="Windows saved PATH")
def test_adding_a_portable_tool_folder_records_it_once(home: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    saved = saved_path(tmp_path, monkeypatch, "other;")
    folder = home / ".legion" / "tools" / "claude"
    assert _user_path.add(home, folder)
    assert not _user_path.add(home, folder)
    assert saved.read_text(encoding="utf-8") == f"other;{folder}"
    assert [entry.value for entry in _footprints.read(home).entries] == [str(folder)]


@pytest.mark.skipif(sys.platform != "win32", reason="Windows saved PATH")
def test_plain_uninstall_keeps_a_portable_tools_path_entry_and_purge_removes_it(home: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    portable = home / ".legion" / "tools" / "claude"
    saved = saved_path(tmp_path, monkeypatch, f"other;{portable}")
    _footprints.add(home, "path-entry", "user PATH", "legion", value=str(portable))
    assert _user_path.remove(home) == []
    assert saved.read_text(encoding="utf-8") == f"other;{portable}"
    assert _user_path.remove(home, purge=True, dry_run=True) == [f"Remove user PATH entry: {portable}"]
    assert saved.read_text(encoding="utf-8") == f"other;{portable}"
    _user_path.remove(home, purge=True)
    assert saved.read_text(encoding="utf-8") == "other"
    assert _footprints.read(home).entries == []
    assert _user_path.remove(home, purge=True) == []


@pytest.mark.skipif(sys.platform != "win32", reason="Windows saved PATH")
def test_one_recorded_occurrence_goes_and_its_record_is_retired(home: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    portable = home / ".legion" / "tools" / "claude"
    saved = saved_path(tmp_path, monkeypatch, f"{portable};other;{portable}")
    _footprints.add(home, "path-entry", "user PATH", "legion", value=str(portable))
    _user_path.remove(home, purge=True)
    assert saved.read_text(encoding="utf-8") == f"other;{portable}"
    assert _footprints.read(home).entries == []


def test_an_uninstall_on_other_systems_changes_no_shell_profile(home: Path) -> None:
    profile = home / ".zshrc"
    profile.write_text('# Added by legion\nexport PATH="$HOME/.legion/bin:$PATH"\n', encoding="utf-8")
    if sys.platform != "win32":
        assert _user_path.remove(home, purge=True) == []
    assert profile.read_text(encoding="utf-8").startswith("# Added by legion")
