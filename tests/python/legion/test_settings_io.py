import json
import os
from pathlib import Path
from typing import Any

import pytest

from legion import _settings_io
from legion._home import settings_path
from legion._settings_io import SCHEMA_URL, SettingsError
from legion._settings_models import PersonalisationSettings

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
    assert folder_names(tmp_path) == ["personalisation.json"]


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
    assert folder_names(tmp_path) == ["personalisation.json"]


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
    assert folder_names(tmp_path) == ["personalisation.json"]


def test_save_preserves_non_windows_permission_error(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [], "channels": []})

    def denied(*_args: object, **_kwargs: object) -> None:
        raise PermissionError(13, "temporary directory denies creation")

    monkeypatch.setattr(_settings_io.tempfile, "NamedTemporaryFile", denied)
    with pytest.raises(SettingsError, match="temporary directory denies creation"):
        _settings_io.save(tmp_path, model())


def test_save_reports_replace_and_cleanup_failures_together(tmp_path: Path) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [], "channels": []})

    def held(_source: object, _target: object) -> None:
        error = OSError("replacement denied")
        patch.setattr(error, "winerror", 32, raising=False)
        raise error

    def cleanup_denied(_path: Path, **_kwargs: object) -> None:
        raise PermissionError("cleanup denied")

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(_settings_io.Path, "unlink", cleanup_denied)
        patch.setattr(_settings_io.Path, "replace", held)
        with pytest.raises(SettingsError) as failure:
            _settings_io.save(tmp_path, model())
    assert "in use by another program" in str(failure.value)
    assert "cleanup denied" in str(failure.value)
    assert "\n" not in str(failure.value)


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
    assert folder_names(tmp_path) == ["personalisation.json"]
