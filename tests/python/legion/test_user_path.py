# The shell profile PATH line that setup adds on macOS and Linux; no real profile or registry is touched.
import codecs
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

from legion.services.repository import _footprints
from legion.services.installation import _user_path

LINE = 'export PATH="$HOME/.legion/bin:$PATH"'
MARKER = "# Added by legion"
PROFILES = {"zsh": ".zshrc", "bash": ".bashrc", "fish": ".profile", "": ".profile"}


@pytest.fixture
def home(tmp_path: Path) -> Path:
    (tmp_path / "home").mkdir()
    return tmp_path / "home"


@pytest.mark.parametrize("shell", PROFILES)
def test_the_profile_follows_the_shell(home: Path, monkeypatch: pytest.MonkeyPatch, shell: str) -> None:
    monkeypatch.setenv("SHELL", f"/bin/{shell}" if shell else "")
    profile = _user_path.shell_profile(home)
    assert profile.path == home / PROFILES[shell]
    assert profile.line == LINE
    assert not profile.has_path


@pytest.mark.parametrize("shell", PROFILES)
def test_a_preview_names_the_profile_and_changes_nothing(home: Path, monkeypatch: pytest.MonkeyPatch, shell: str) -> None:
    monkeypatch.setenv("SHELL", f"/bin/{shell}" if shell else "")
    path = home / PROFILES[shell]
    assert _user_path.shell_profile_lines(home, dry_run=True) == [f"add {MARKER} and {LINE} to {path}"]
    assert not path.exists()
    assert not (home / ".legion").exists()


def test_adding_writes_the_two_lines_records_them_and_repeats_as_a_skip(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/zsh")
    profile = home / ".zshrc"
    assert _user_path.shell_profile_lines(home) == [f"add {MARKER} and {LINE} to {profile}"]
    assert profile.read_text(encoding="utf-8") == f"{MARKER}\n{LINE}\n"
    [entry] = _footprints.read(home).entries
    assert (entry.kind, entry.path, entry.value, entry.owners) == ("path-entry", "~/.zshrc", LINE, ["legion"])
    stamp, index = profile.stat().st_mtime_ns, _footprints.footprint_index(home).read_bytes()
    assert _user_path.shell_profile_lines(home) == ["skip: shell profile PATH (already done)"]
    assert profile.stat().st_mtime_ns == stamp
    assert _footprints.footprint_index(home).read_bytes() == index
    assert _user_path.shell_profile(home).has_path


def test_a_profile_without_a_final_newline_is_separated_and_the_separator_recorded(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    profile.write_text("alias x=y", encoding="utf-8")
    _user_path.shell_profile_lines(home)
    assert profile.read_text(encoding="utf-8") == f"alias x=y\n{MARKER}\n{LINE}\n"
    assert _footprints.read(home).entries[0].key == "\n"


def test_a_line_the_owner_wrote_is_not_recorded(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    (home / ".bashrc").write_text(f"{LINE}\n", encoding="utf-8")
    assert _user_path.shell_profile_lines(home) == ["skip: shell profile PATH (already done)"]
    assert _footprints.read(home).entries == []


def test_a_line_under_the_marker_is_recorded_again_with_its_key(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    (home / ".bashrc").write_text(f"{MARKER}\n{LINE}\n", encoding="utf-8")
    assert _user_path.shell_profile(home).marked
    _user_path.shell_profile_lines(home)
    assert [(entry.path, entry.owners) for entry in _footprints.read(home).entries] == [("~/.bashrc", ["legion"])]


def test_a_byte_order_mark_and_utf16_survive(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    profile.write_bytes("# x\n".encode("utf-16"))
    _user_path.shell_profile_lines(home)
    assert profile.read_bytes() == f"# x\n{MARKER}\n{LINE}\n".encode("utf-16")


def test_an_encoding_that_cannot_be_kept_is_refused(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    profile.write_bytes(b"\xff\xfe\xfa not text\n")
    with pytest.raises(_user_path.PathError, match="not lossless"):
        _user_path.shell_profile_lines(home)
    assert profile.read_bytes() == b"\xff\xfe\xfa not text\n"


def test_a_linked_profile_is_refused(home: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    target = tmp_path / "elsewhere"
    target.write_text("", encoding="utf-8")
    try:
        (home / ".bashrc").symlink_to(target)
    except OSError:
        pytest.skip("links need a privilege here")
    with pytest.raises(_user_path.PathError, match="link"):
        _user_path.shell_profile_lines(home)


@pytest.mark.skipif(sys.platform == "win32", reason="needs sh")
def test_sourcing_the_profile_puts_a_home_with_spaces_on_the_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    spaced = tmp_path / "alternate home"
    spaced.mkdir()
    monkeypatch.setenv("SHELL", "/bin/bash")
    _user_path.shell_profile_lines(spaced)
    script = f'HOME="{spaced}"; . "{spaced / ".bashrc"}"; printf "%s" "$PATH"'
    result = subprocess.run(["/bin/sh", "-c", script], capture_output=True, text=True, check=True, env={"PATH": "/usr/bin"})
    assert result.stdout.startswith(f"{spaced}/.legion/bin:")


@pytest.mark.parametrize("codec", ["utf-32-le", "utf-32-be"])
def test_a_utf32_profile_gets_utf32_bytes_and_keeps_its_original_bytes(home: Path, monkeypatch: pytest.MonkeyPatch, codec: str) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    mark = codecs.BOM_UTF32_LE if codec == "utf-32-le" else codecs.BOM_UTF32_BE
    original = mark + "# x\n".encode(codec)
    profile.write_bytes(original)
    _user_path.shell_profile_lines(home)
    assert profile.read_bytes() == original + f"{MARKER}\n{LINE}\n".encode(codec)


def test_a_crlf_profile_gets_a_crlf_block_(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    original = b"alias x=y\r\nalias z=w"
    profile.write_bytes(original)
    _user_path.shell_profile_lines(home)
    assert profile.read_bytes() == original + f"\r\n{MARKER}\r\n{LINE}\r\n".encode()
    assert _user_path.shell_profile_lines(home) == ["skip: shell profile PATH (already done)"]


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX shell profile")
def test_uninstall_restores_a_crlf_profile_to_its_original_bytes(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    original = b"alias x=y\r\nalias z=w"
    profile.write_bytes(original)
    _user_path.shell_profile_lines(home)
    assert _user_path.remove(home, dry_run=True) == [f"Remove {MARKER} and {LINE} from {profile}"]
    assert profile.read_bytes() != original
    _user_path.remove(home)
    assert profile.read_bytes() == original
    assert _user_path.remove(home) == ["skip: path (already done)"]


def test_a_profile_changed_after_it_was_read_is_kept_and_not_recorded(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    profile.write_text("alias x=y\n", encoding="utf-8")
    real = _user_path.atomic_write_bytes

    def write(path: Path, data: bytes, **options: Any) -> None:
        path.write_text("alias x=y\nalias added=elsewhere\n", encoding="utf-8")
        real(path, data, **options)

    monkeypatch.setattr(_user_path, "atomic_write_bytes", write)
    with pytest.raises(_user_path.PathError, match="changed while it was being written"):
        _user_path.shell_profile_lines(home)
    assert profile.read_text(encoding="utf-8") == "alias x=y\nalias added=elsewhere\n"
    assert not _footprints.read(home).entries


@pytest.mark.skipif(sys.platform == "win32", reason="POSIX shell profile")
def test_a_profile_line_the_owner_wrote_is_not_removed(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("SHELL", "/bin/bash")
    profile = home / ".bashrc"
    profile.write_text(f"{LINE}\n", encoding="utf-8")
    _user_path.shell_profile_lines(home)
    assert _user_path.remove(home) == ["skip: path (already done)"]
    assert profile.read_text(encoding="utf-8") == f"{LINE}\n"


@pytest.mark.skipif(sys.platform != "win32", reason="Windows saved PATH")
def test_only_the_recorded_user_path_entry_is_removed(home: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    saved = tmp_path / "user-path.txt"
    saved.write_text("other;", encoding="utf-8")
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(saved))
    assert _user_path.add(home, home / ".legion" / "bin")
    assert _user_path.remove(home, dry_run=True) == [f"Remove user PATH entry: {home / '.legion' / 'bin'}"]
    assert saved.read_text(encoding="utf-8") == f"other;{home / '.legion' / 'bin'}"
    _user_path.remove(home)
    assert saved.read_text(encoding="utf-8") == "other"
    assert _user_path.remove(home) == ["skip: path (already done)"]
