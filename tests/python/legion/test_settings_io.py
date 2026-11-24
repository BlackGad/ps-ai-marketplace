import json
import os
import queue
import subprocess
import sys
import threading
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

import pytest

from legion import _settings_io
from legion import _channel
from filelock import FileLock
from legion._home import settings_path
from legion._settings_io import SCHEMA_URL, SettingsError
from legion._settings_models import Channel, PersonalisationSettings

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


def test_powershell_account_add_preserves_overlapping_channel_change(tmp_path: Path, pwsh_path: Path) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    config = tmp_path / "config"
    config.mkdir()
    command = tmp_path / "fake-tool"
    command.write_bytes(b"fake")
    account = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "legion-account.ps1"
    launch = tmp_path / "account.ps1"
    launch.write_text(
        ". (Join-Path (Split-Path $args[0]) 'lib/accounts.ps1'); "
        "$global:settingsLockPath = Join-Path $args[3] '.legion/configuration/personalisation.json.lock'; "
        "Set-PSBreakpoint -Command Wait-LegionLockFile -Action { [Console]::WriteLine('ready') } | Out-Null; "
        "Set-PSBreakpoint -Command Read-LegionJson -Action { "
        "[Console]::WriteLine('read breakpoint'); $held = Open-LegionLockFile -Path $global:settingsLockPath; "
        "if ($held) { $held.Dispose(); [Console]::Error.WriteLine('account read settings without lock') } } | Out-Null; "
        "& $args[0] -Action add -Id claude-b -Tool claude -Command $args[1] -ConfigDir $args[2] -HomeRoot $args[3]",
        encoding="utf-8",
    )
    with FileLock(str(settings_path(tmp_path)) + ".lock", timeout=0):
        child = subprocess.Popen(
            [str(pwsh_path), "-NoProfile", "-File", str(launch), str(account), str(command), str(config), str(tmp_path)],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
        try:
            assert child.stdout is not None
            output = child.stdout
            ready: queue.Queue[str] = queue.Queue()
            threading.Thread(target=lambda: ready.put(output.readline()), daemon=True).start()
            assert ready.get(timeout=30).strip() == "ready"
            assert child.poll() is None
            settings = _settings_io.load(tmp_path)
            settings.channels.append(Channel.model_validate({"id": "channel-a", "kind": "telegram", "target": "1", "accounts": ["claude-a"]}))
            _settings_io.save_locked(tmp_path, settings)
        except BaseException:
            if child.poll() is None:
                child.kill()
            child.communicate(timeout=60)
            raise
    try:
        stdout, stderr = child.communicate(timeout=60)
    except subprocess.TimeoutExpired:
        child.kill()
        stdout, stderr = child.communicate(timeout=5)
        pytest.fail(f"PowerShell account child stalled: {stdout} {stderr}")
    assert child.returncode == 0, stderr
    assert "read breakpoint" in stdout
    assert "account read settings without lock" not in stderr
    result = _settings_io.load(tmp_path)
    assert {agent.id for agent in result.agents} == {"claude-a", "claude-b"}
    assert {channel.id for channel in result.channels} == {"channel-a"}


def test_powershell_models_list_does_not_wait_for_settings_writer(tmp_path: Path, pwsh_path: Path) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [FOUNDRY], "channels": []})
    account = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "legion-account.ps1"
    fake_az = Path(__file__).resolve().parents[3] / "tests" / "FakeAz.ps1"
    launch = tmp_path / "models-list.ps1"
    launch.write_text(
        ". $args[0]; Use-FakeAz -Answers @{ "
        '\'account get-access-token --resource https://cognitiveservices.azure.com\' = @{exit=0; stdout=\'{"accessToken":"fake","expiresOn":"2099-01-01T00:00:00+00:00"}\'}; '
        "'cognitiveservices account list' = @{exit=0; stdout='[]'}; "
        "'account list' = @{exit=0; stdout=''} "
        "}; & $args[1] -Action models -Id claude-f -List -HomeRoot $args[2]",
        encoding="utf-8",
    )
    with FileLock(str(settings_path(tmp_path)) + ".lock", timeout=0):
        result = subprocess.run(
            [str(pwsh_path), "-NoProfile", "-File", str(launch), str(fake_az), str(account), str(tmp_path)],
            capture_output=True,
            text=True,
            timeout=60,
            check=False,
        )
    assert result.returncode == 0, result.stderr
    assert '"deployments"' in result.stdout


def test_powershell_setup_locks_settings_before_planning(tmp_path: Path, pwsh_path: Path) -> None:
    write_settings(tmp_path, {"schemaVersion": 1, "agents": [ACCOUNT], "channels": []})
    setup = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "legion-setup.ps1"
    probe = tmp_path / "setup-lock.ps1"
    probe.write_text(
        ". $args[0] -NoRun\n"
        "function Get-SetupPlan { param($Add, $Id, $HomeRoot) "
        "$file = Get-LegionOwnerPath -HomeRoot $HomeRoot -Name Settings; "
        "$held = Open-LegionLockFile -Path (Get-LegionSettingsLockPath -Path $file); "
        "if ($held) { $held.Dispose(); throw 'settings were read without the lock' }; return @{ HomeRoot = $HomeRoot } }\n"
        "function Initialize-SetupFiles { param($Plan) }\n"
        "function Assert-Unlocked { param($Plan) $file = Get-LegionOwnerPath -HomeRoot $Plan.HomeRoot -Name Settings; "
        "$held = Open-LegionLockFile -Path (Get-LegionSettingsLockPath -Path $file); "
        "if (-not $held) { throw 'settings lock held during external work' }; $held.Dispose() }\n"
        "function Install-SetupTools { param($Plan) Assert-Unlocked $Plan }\n"
        "function Add-SetupAccounts { param($Plan) $file = Get-LegionOwnerPath -HomeRoot $Plan.HomeRoot -Name Settings; "
        "$held = Open-LegionLockFile -Path (Get-LegionSettingsLockPath -Path $file); "
        "if ($held) { $held.Dispose(); throw 'account read lacked settings lock' } }\n"
        "function Add-SetupAllowRules { param($Plan) Assert-Unlocked $Plan }\n"
        "function Set-SetupPath { param($Plan) }\n"
        "function Install-SetupPlugins { param($Plan) Assert-Unlocked $Plan }\n"
        "function Write-SetupCommands { param($Plan) Assert-Unlocked $Plan }\n"
        "function Write-SetupTable { param($Plan) }\n"
        "Invoke-Setup -Yes -HomeRoot $args[1]\n",
        encoding="utf-8",
    )
    result = subprocess.run([str(pwsh_path), "-NoProfile", "-File", str(probe), str(setup), str(tmp_path)], capture_output=True, text=True, timeout=60, check=False)
    assert result.returncode == 0, result.stderr
