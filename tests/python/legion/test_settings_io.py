import json
import os
import sys
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

import pytest

from legion.services import _accounts
from legion.core import _settings_io
from legion.services.foundry import _discovery
from legion.services import _channel
from filelock import FileLock
from legion.core._home import settings_path
from legion.core._settings_io import SCHEMA_URL, SettingsError
from legion.core._settings_models import PersonalisationSettings

ACCOUNT = {"id": "claude-a", "tool": "claude", "configDir": "~/.claude"}
FOUNDRY = {
    "id": "claude-f",
    "tool": "claude",
    "configDir": "~/.claude-f",
    "provider": {"kind": "foundry", "endpoint": "https://example.cognitiveservices.azure.com", "default": "a", "deployments": [{"name": "a"}]},
}


def model(**changes: Any) -> PersonalisationSettings:
    data: dict[str, Any] = {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []}
    data.update(changes)
    return PersonalisationSettings.model_validate(data)


def write_settings(home: Path, data: dict[str, Any]) -> bytes:
    path = settings_path(home)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = json.dumps(data).encode("utf-8")
    path.write_bytes(text)
    return text


def folder_names(home: Path) -> list[str]:
    return sorted(path.name for path in settings_path(home).parent.iterdir())


def test_load_without_settings_refuses(tmp_path: Path) -> None:
    with pytest.raises(SettingsError, match=r"^No legion settings yet; add an agent first\.$"):
        _settings_io.load(tmp_path)


def test_load_reads_a_bom_file(tmp_path: Path) -> None:
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_bytes(b"\xef\xbb\xbf" + json.dumps({"schemaVersion": 1, "agents": [ACCOUNT], "channels": []}).encode("utf-8"))
    assert _settings_io.load(tmp_path) == model()


def test_load_validates_the_same_snapshot_it_returns(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    original = _settings_io._validate.read_text
    reads = 0

    def changing_read(path: Path) -> str:
        nonlocal reads
        reads += 1
        if reads == 1:
            return original(path)
        return '{"schemaVersion":1,"agents":[],"channels":[{"id":"stale","kind":"telegram","target":"1","accounts":["gone"]}]}'

    monkeypatch.setattr(_settings_io._validate, "read_text", changing_read)
    assert _settings_io.load(tmp_path) == model()
    assert reads == 1


def test_load_refuses_a_broken_file_in_one_line(tmp_path: Path) -> None:
    write_settings(tmp_path, {"schemaVersion": 2, "agents": [], "channels": []})
    with pytest.raises(SettingsError) as error:
        _settings_io.load(tmp_path)
    assert "schemaVersion" in str(error.value)
    assert "\n" not in str(error.value)


def test_load_refuses_invalid_utf8_in_one_line(tmp_path: Path) -> None:
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_bytes(b"\xff")
    with pytest.raises(SettingsError) as error:
        _settings_io.load(tmp_path)
    assert "decode" in str(error.value)
    assert "\n" not in str(error.value)


def test_load_or_empty_starts_a_fresh_home_and_reads_an_existing_one(tmp_path: Path) -> None:
    assert _settings_io.load_or_empty(tmp_path) == PersonalisationSettings.model_validate({"schemaVersion": 1, "agents": [], "channels": []})
    assert not settings_path(tmp_path).exists()
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    assert _settings_io.load_or_empty(tmp_path) == model()


def test_save_writes_indented_utf8_without_bom_and_a_final_newline(tmp_path: Path) -> None:
    _settings_io.save(tmp_path, model(agents=[{**ACCOUNT, "configDir": "~/.claude-é"}]))
    data = settings_path(tmp_path).read_bytes()
    assert not data.startswith(b"\xef\xbb\xbf")
    assert b"\r" not in data
    assert data.endswith(b"}\n")
    assert '"configDir": "~/.claude-é"' in data.decode("utf-8")
    assert data.decode("utf-8").splitlines()[1] == '  "schemaVersion": 1,'
    assert _settings_io.load(tmp_path).agents[0].config_dir == "~/.claude-é"
    assert set(folder_names(tmp_path)) <= {"personalisation.json", "personalisation.json.lock"}
    assert "personalisation.json" in folder_names(tmp_path)
    assert not list(settings_path(tmp_path).parent.glob(".personalisation.json.*.tmp"))


def test_save_rewrites_a_present_schema_and_leaves_an_absent_one_out(tmp_path: Path) -> None:
    _settings_io.save(tmp_path, model())
    assert "$schema" not in json.loads(settings_path(tmp_path).read_text(encoding="utf-8"))
    _settings_io.save(tmp_path, model(**{"$schema": "../schemas/personalisation.schema.json"}))
    saved = json.loads(settings_path(tmp_path).read_text(encoding="utf-8"))
    assert saved["$schema"] == SCHEMA_URL


def test_save_follows_a_settings_symlink(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    target = tmp_path / "managed.json"
    target.write_text('{"schemaVersion":1,"agents":[],"channels":[]}', encoding="utf-8")
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    linked = True
    try:
        path.symlink_to(target)
    except (OSError, NotImplementedError):
        linked = False
        # Windows may deny file symlinks; exercise the resolved destination with an injected resolver.
        original_resolve = Path.resolve

        def resolve(candidate: Path, *args: Any, **kwargs: Any) -> Path:
            return target if candidate == path else original_resolve(candidate, *args, **kwargs)

        monkeypatch.setattr(Path, "resolve", resolve)
    _settings_io.save(tmp_path, model())
    if linked:
        assert path.is_symlink()
    assert json.loads(target.read_text(encoding="utf-8"))["agents"] == [ACCOUNT]


@pytest.mark.parametrize(
    ("settings", "message"),
    [
        (lambda: model(channels=[{"id": "my-telegram", "kind": "telegram", "target": "1", "accounts": ["nobody"]}]), "channel 'my-telegram': unknown account 'nobody'"),
        (lambda: model(agents=[ACCOUNT, {**FOUNDRY, "provider": {**FOUNDRY["provider"], "default": "gone"}}]), "agents[1].provider: default 'gone' is not a deployment"),
    ],
    ids=["unknown account", "Foundry provider"],
)
def test_save_writes_nothing_when_a_check_fails(tmp_path: Path, settings: Any, message: str) -> None:
    before = write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    with pytest.raises(SettingsError) as error:
        _settings_io.save(tmp_path, settings())
    assert message in str(error.value)
    assert settings_path(tmp_path).read_bytes() == before
    assert not list(settings_path(tmp_path).parent.glob(".personalisation.json.*.tmp"))


def test_save_refuses_a_model_that_breaks_the_schema(tmp_path: Path) -> None:
    before = write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    broken = model()
    broken.agents[0].config_dir = ""
    with pytest.raises(SettingsError, match=r"agents\[0\]\.configDir"):
        _settings_io.save(tmp_path, broken)
    assert settings_path(tmp_path).read_bytes() == before


def test_save_reports_a_held_file_in_one_line_and_leaves_no_temp_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    before = write_settings(tmp_path, {"schemaVersion": 1, "agents": [], "channels": []})

    # The held-file diagnostic is specific to WinError 5 and 32.
    def held(_source: object, _target: object) -> None:
        error = PermissionError(13, "The process cannot access the file because it is being used by another process")
        monkeypatch.setattr(error, "winerror", 32, raising=False)
        raise error

    monkeypatch.setattr(os, "replace", held)
    with pytest.raises(SettingsError) as error:
        _settings_io.save(tmp_path, model())
    assert str(error.value) == "legion settings are in use by another program; close it and run the command again"
    assert settings_path(tmp_path).read_bytes() == before
    assert set(folder_names(tmp_path)) <= {"personalisation.json", "personalisation.json.lock"}
    assert "personalisation.json" in folder_names(tmp_path)
    if sys.platform != "win32":
        assert "personalisation.json.lock" in folder_names(tmp_path)
    assert not list(settings_path(tmp_path).parent.glob(".personalisation.json.*.tmp"))


def test_save_preserves_non_windows_permission_error(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [], "channels": []})

    def denied(*_args: object, **_kwargs: object) -> None:
        raise PermissionError(13, "temporary directory denies creation")

    monkeypatch.setattr(_settings_io.tempfile, "NamedTemporaryFile", denied)
    with pytest.raises(SettingsError, match="temporary directory denies creation"):
        _settings_io.save(tmp_path, model())


def test_save_reports_replace_and_cleanup_failures_together(tmp_path: Path) -> None:
    before = write_settings(tmp_path, {"schemaVersion": 1, "agents": [], "channels": []})
    real_unlink = Path.unlink
    temp: Path | None = None

    def held(source: Path, target: Path) -> None:
        nonlocal temp
        assert target == settings_path(tmp_path)
        temp = source
        error = OSError("replacement denied")
        patch.setattr(error, "winerror", 32, raising=False)
        raise error

    def cleanup_denied(path: Path, *, missing_ok: bool = False) -> None:
        # Only the failed replacement's temp file is denied; filelock may unlink its own probes.
        if path == temp:
            raise PermissionError("cleanup denied")
        real_unlink(path, missing_ok=missing_ok)

    with pytest.MonkeyPatch.context() as patch:
        # Exercise named lock probes on Linux too; macOS has no O_TMPFILE.
        patch.delattr(os, "O_TMPFILE", raising=False)
        patch.setattr(_settings_io.Path, "unlink", cleanup_denied)
        patch.setattr(_settings_io.Path, "replace", held)
        with pytest.raises(SettingsError) as failure:
            _settings_io.save(tmp_path, model())
    assert str(failure.value) == "legion settings are in use by another program; close it and run the command again; cleanup failed: cleanup denied"
    assert settings_path(tmp_path).read_bytes() == before
    assert temp is not None
    assert temp.is_file()


@pytest.mark.parametrize("winerror", [5, 32])
def test_save_handles_windows_replace_errors(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, winerror: int) -> None:
    before = write_settings(tmp_path, {"schemaVersion": 1, "agents": [], "channels": []})

    def held(source: Path, target: Path) -> None:
        assert source.parent == target.parent == settings_path(tmp_path).parent
        assert json.loads(source.read_text(encoding="utf-8"))["agents"] == [ACCOUNT]
        error = OSError("file is held\nby another program")
        monkeypatch.setattr(error, "winerror", winerror, raising=False)
        raise error

    monkeypatch.setattr(os, "replace", held)
    with pytest.raises(SettingsError, match=r"^legion settings are in use by another program; close it and run the command again$"):
        _settings_io.save(tmp_path, model())
    assert settings_path(tmp_path).read_bytes() == before
    assert set(folder_names(tmp_path)) <= {"personalisation.json", "personalisation.json.lock"}
    assert "personalisation.json" in folder_names(tmp_path)
    assert not list(settings_path(tmp_path).parent.glob(".personalisation.json.*.tmp"))


def test_channel_load_and_replace_hold_the_writer_lock(tmp_path: Path) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    real_lock = _settings_io.FileLock
    real_read = _settings_io._validate.read_text
    real_save = _settings_io.save_locked
    held = False

    @contextmanager
    def checked_lock(path: str, timeout: int) -> Iterator[None]:
        nonlocal held
        with real_lock(path, timeout=timeout):
            held = True
            try:
                yield
            finally:
                held = False

    def checked_read(path: Path) -> str:
        assert held, "settings loaded without the writer lock"
        return real_read(path)

    def checked_save(home: Path, settings: PersonalisationSettings) -> None:
        assert held, "settings replaced without the writer lock"
        real_save(home, settings)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(_settings_io, "FileLock", checked_lock)
        patch.setattr(_settings_io._validate, "read_text", checked_read)
        patch.setattr(_settings_io, "save_locked", checked_save)
        _channel.add(tmp_path, "channel-0", "telegram", "1", ["claude-a"])
        _channel.add(tmp_path, "channel-1", "telegram", "1", ["claude-a"])
    assert {channel.id for channel in _settings_io.load(tmp_path).channels} == {"channel-0", "channel-1"}


def test_channel_add_refuses_an_existing_writer_lock_immediately(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    real_lock = _settings_io.FileLock
    with FileLock(str(settings_path(tmp_path)) + ".lock", timeout=0):

        def immediate(path: str, timeout: int) -> FileLock:
            assert timeout == 30
            return real_lock(path, timeout=0)

        monkeypatch.setattr(_settings_io, "FileLock", immediate)
        with pytest.raises(SettingsError, match="settings are busy"):
            _channel.add(tmp_path, "channel-0", "telegram", "1", ["claude-a"])


def test_writer_refuses_lock_setup_permission_failure_in_one_line(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    parent = settings_path(tmp_path).parent
    real_mkdir = Path.mkdir

    def denied(path: Path, *args: Any, **kwargs: Any) -> None:
        if path == parent:
            raise PermissionError("permission\n denied")
        real_mkdir(path, *args, **kwargs)

    monkeypatch.setattr(Path, "mkdir", denied)
    with pytest.raises(SettingsError) as error, _settings_io.writer(tmp_path):
        pass
    assert str(error.value) == "permission denied"


def test_writer_refuses_lock_open_permission_failure_in_one_line(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})

    def denied(path: str, timeout: int) -> None:
        assert path.endswith("personalisation.json.lock")
        assert timeout == 30
        raise PermissionError("lock\n denied")

    monkeypatch.setattr(_settings_io, "FileLock", denied)
    with pytest.raises(SettingsError) as error, _settings_io.writer(tmp_path):
        pass
    assert str(error.value) == "lock denied"


def test_writer_leaves_fresh_home_untouched_when_settings_are_missing(tmp_path: Path) -> None:
    with pytest.raises(SettingsError, match="No legion settings yet"), _settings_io.writer(tmp_path):
        _settings_io.load(tmp_path)
    assert not (tmp_path / ".legion").exists()


def test_models_list_does_not_wait_for_settings_writer(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [FOUNDRY], "channels": []})
    discovery = _discovery.FoundryDiscovery(source="management", error="", deployments=[])
    monkeypatch.setattr(_discovery, "discover", lambda *_args: discovery)
    with FileLock(str(settings_path(tmp_path)) + ".lock", timeout=0):
        lines = _accounts.models(tmp_path, "claude-f", [], None, None, False, True)
    assert '"deployments"' in lines[0]
