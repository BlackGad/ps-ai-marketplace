import contextlib
import dataclasses
import io
import json
import shutil
import subprocess
import sys
import threading
import time
import urllib.request
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Any

import pytest
from cli_runner import run

from legion import _plugin, _update

SOURCE = "BlackGad/ps-legion-marketplace"
URL = f"https://raw.githubusercontent.com/{SOURCE}/stable/plugins/legion/plugin.json"
FAILURE = "legion: update check failed; could not read the installed or GitHub plugin manifest.\n"


@pytest.fixture
def plugin(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "fork" / "plugins" / "legion"
    root.mkdir(parents=True)
    (root / "plugin.json").write_text('{"name":"legion","version":"0.3.0"}', encoding="utf-8")
    monkeypatch.setattr(_plugin, "PLUGIN_ROOT", root)
    return root


@pytest.fixture
def remote(monkeypatch: pytest.MonkeyPatch) -> dict[str, Any]:
    state: dict[str, Any] = {"text": '{"name":"legion","version":"0.4.0"}', "calls": [], "fail": False}

    # Cache and manifest tests must not depend on the daemon worker meeting its real deadline.
    # The subprocess tests below exercise that deadline with the real downloader.
    def download_fake(_deadline: float) -> str:
        state["calls"].append(URL)
        if state["fail"]:
            raise OSError("private fixture detail")
        return state["text"]

    monkeypatch.setattr(_update, "_download", download_fake)
    return state


def cache_path(home: Path) -> Path:
    return home / ".legion" / "temp" / "update.json"


def save_cache(home: Path, **changes: Any) -> Path:
    path = cache_path(home)
    path.parent.mkdir(parents=True, exist_ok=True)
    record = {"Source": SOURCE, "CheckedAt": datetime.now(UTC).isoformat(), "Available": "0.4.0", "Failed": False}
    record.update(changes)
    path.write_text(json.dumps(record), encoding="utf-8")
    return path


def test_check_cache_and_running_manifest(plugin: Path, remote: dict[str, Any], tmp_path: Path) -> None:
    result = _update.get_update(plugin, tmp_path)
    assert result is not None
    assert (result.installed, result.available, result.newer) == ("0.3.0", "0.4.0", True)
    assert remote["calls"] == [URL]
    path = cache_path(tmp_path)
    before = path.read_bytes()
    record = _update.UpdateCache.from_json(before.decode())
    assert dataclasses.is_dataclass(record)
    field = "failed"
    with pytest.raises(dataclasses.FrozenInstanceError):
        setattr(record, field, True)
    assert set(json.loads(before)) == {"Source", "CheckedAt", "Available", "Failed"}
    assert _update.get_update(plugin, tmp_path) == result
    assert path.read_bytes() == before
    (plugin / "plugin.json").write_text('{"name":"legion","version":"0.4.0"}', encoding="utf-8")
    updated = _update.get_update(plugin, tmp_path)
    assert updated is not None
    assert not updated.newer
    assert remote["calls"] == [URL]
    remote["text"] = '{"name":"legion","version":"0.10.0"}'
    forced = _update.get_update(plugin, tmp_path, force=True)
    assert forced is not None
    assert forced.available == "0.10.0"
    assert forced.newer
    assert remote["calls"] == [URL, URL]


@pytest.mark.parametrize(
    "changes",
    [
        {"CheckedAt": (datetime.now(UTC) - timedelta(days=2)).isoformat()},
        {"CheckedAt": (datetime.now(UTC) - timedelta(days=1, seconds=1)).isoformat()},
        {"CheckedAt": (datetime.now(UTC) + timedelta(days=1)).isoformat()},
        {"CheckedAt": "bad"},
        {"Source": SOURCE.lower()},
        {"Available": "bad"},
        {"Available": None},
    ],
)
def test_invalid_or_expired_cache_refreshes(plugin: Path, remote: dict[str, Any], tmp_path: Path, changes: dict[str, Any]) -> None:
    save_cache(tmp_path, **changes)
    assert _update.get_update(plugin, tmp_path) is not None
    assert remote["calls"] == [URL]


@pytest.mark.parametrize("text", ["{", "[]", "null", "{}", '{"Source": 1}', '{"Source": "x", "CheckedAt": false}'])
def test_bad_cache_shape_refreshes(plugin: Path, remote: dict[str, Any], tmp_path: Path, text: str) -> None:
    save_cache(tmp_path).write_text(text, encoding="utf-8")
    assert _update.get_update(plugin, tmp_path) is not None
    assert remote["calls"] == [URL]


@pytest.mark.usefixtures("plugin")
def test_failure_cached_and_force_reports_one_safe_line(remote: dict[str, Any], tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    remote["fail"] = True
    assert run(["--home", str(tmp_path), "update", "--check"]) == 0
    assert capsys.readouterr().out == ""
    record = json.loads(cache_path(tmp_path).read_text())
    assert record["Failed"] is True
    assert record["Available"] is None
    assert run(["--home", str(tmp_path), "update", "--check"]) == 0
    assert len(remote["calls"]) == 1
    assert capsys.readouterr().out == ""
    assert run(["--home", str(tmp_path), "update", "--check", "--force"]) == 0
    assert capsys.readouterr().out == FAILURE
    assert len(remote["calls"]) == 2


@pytest.mark.parametrize("bad", ["{", "[]", "null", '{"name":"other","version":"0.4.0"}', '{"name":"legion","version":"invalid"}', '{"name":"legion"}', '{"name":"legion","version":null}'])
@pytest.mark.parametrize("installed", [False, True])
def test_bad_manifests(plugin: Path, remote: dict[str, Any], tmp_path: Path, capsys: pytest.CaptureFixture[str], bad: str, installed: bool) -> None:
    if installed:
        (plugin / "plugin.json").write_text(bad, encoding="utf-8")
    else:
        remote["text"] = bad
    assert run(["--home", str(tmp_path), "update", "--check", "--force"]) == 0
    assert capsys.readouterr().out == FAILURE
    assert len(remote["calls"]) == (0 if installed else 1)


@pytest.mark.parametrize("flags", [["--check"], ["--check", "--force"], ["--force", "--check"]])
@pytest.mark.usefixtures("plugin")
def test_check_output(remote: dict[str, Any], tmp_path: Path, capsys: pytest.CaptureFixture[str], flags: list[str]) -> None:
    assert run(["--home", str(tmp_path), "update", *flags]) == 0
    assert capsys.readouterr().out == "legion installed: 0.3.0\nlegion available: 0.4.0\nlegion update\n"
    remote["text"] = '{"name":"legion","version":"0.3.0"}'
    assert run(["--home", str(tmp_path), "update", "--check", "--force"]) == 0
    assert capsys.readouterr().out == "legion 0.3.0 is up to date.\n"


def test_unwritable_cache_keeps_result(plugin: Path, remote: dict[str, Any], tmp_path: Path) -> None:
    cache_path(tmp_path).mkdir(parents=True)
    result = _update.get_update(plugin, tmp_path, force=True)
    assert result is not None
    assert result.available == "0.4.0"
    assert remote["calls"] == [URL]


def test_concurrent_writers_never_show_a_reader_a_partial_cache(plugin: Path, remote: dict[str, Any], tmp_path: Path) -> None:
    remote["text"] = '{"name":"legion","version":"10.20.30-a-much-longer-prerelease-name"}'
    path = cache_path(tmp_path)
    assert _update.get_update(plugin, tmp_path, force=True) is not None
    stop = threading.Event()
    broken: list[str] = []

    def write(fail: bool) -> None:
        while not stop.is_set():
            remote["fail"] = fail
            with contextlib.suppress(OSError, ValueError):
                _update.get_update(plugin, tmp_path, force=True)

    def read() -> None:
        while not stop.is_set():
            try:
                text = path.read_text(encoding="utf-8-sig")
            except OSError:
                continue  # Windows may refuse an open while the file is being replaced; that is not a partial record.
            try:
                _update.UpdateCache.from_json(text)
            except (ValueError, TypeError):
                broken.append(text)

    workers = [threading.Thread(target=write, args=(fail,)) for fail in (False, True)] + [threading.Thread(target=read) for _ in range(2)]
    for worker in workers:
        worker.start()
    time.sleep(3)
    stop.set()
    for worker in workers:
        worker.join()
    assert broken == []
    assert [item.name for item in path.parent.iterdir()] == [path.name]


def test_default_home_and_powershell_timestamp(plugin: Path, remote: dict[str, Any]) -> None:
    path = save_cache(Path.home(), CheckedAt=datetime.now(UTC).strftime("%Y-%m-%dT%H:%M:%S.%f") + "0+00:00")
    assert _update.get_update(plugin) is not None
    assert remote["calls"] == []
    assert path.exists()


@pytest.mark.parametrize(
    ("left", "right", "expected"),
    [
        ("0.10.0", "0.9.0", 1),
        ("2.0.0", "10.0.0", -1),
        ("1.0.0-alpha", "1.0.0", -1),
        ("1.0.0-alpha.2", "1.0.0-alpha.10", -1),
        ("1.0.0-1", "1.0.0-alpha", -1),
        ("1.0.0-alpha", "1.0.0-alpha.1", -1),
        ("1.0.0+one", "1.0.0+two", 0),
        ("1", "1.0.0", 0),
        ("1.2", "1.2.0", 0),
        ("01.2.3", "1.2.3", 0),
        ("1.0.0-A", "1.0.0-a", -1),
        ("1.0.0-999999999999999", "1.0.0-999999999999998", 1),
        ("1.0.0-9999999999", "1.0.0-10000000000", 1),
        ("1.0.0-2147483648", "1.0.0-9", 1),
    ],
)
def test_version_order(left: str, right: str, expected: int) -> None:
    assert _update.compare_versions(left, right) == expected
    assert _update.compare_versions(right, left) == -expected


@pytest.mark.parametrize("version", ["", "v1.2.3", "1.2.3.4", "1.2.3-01", "1.2.3-", "1.2.3+", "2147483648.0.0"])
def test_invalid_version(version: str) -> None:
    with pytest.raises(ValueError):
        _update.compare_versions(version, "1.0.0")


def test_download_reads_remote_body(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = []

    def open_fake(url: str, *, timeout: float) -> io.BytesIO:
        calls.append((url, timeout))
        return io.BytesIO(b"\xef\xbb\xbfnull")

    monkeypatch.setattr(urllib.request, "urlopen", open_fake)
    # Allow scheduling slack here; the subprocess tests verify the three-second deadline.
    assert _update._download(time.monotonic() + 30) == "null"
    assert len(calls) == 1
    assert calls[0][0] == URL
    assert 0 < calls[0][1] <= 30


@pytest.mark.parametrize("stage", ["open", "body"])
def test_stalled_download_deadline_through_process_exit(plugin: Path, tmp_path: Path, stage: str) -> None:
    # Replaces the opener in a fresh interpreter: includes daemon/shutdown behavior, not just the caller's timeout.
    script = """
import sys, time, urllib.request
from pathlib import Path
from legion import _cli, _plugin
class Response:
    def __enter__(self): return self
    def __exit__(self, *args): pass
    def read(self):
        time.sleep(60)
def stalled(*args, **kwargs):
    if sys.argv[3] == 'open': time.sleep(60)
    return Response()
urllib.request.urlopen = stalled
_plugin.PLUGIN_ROOT = Path(sys.argv[1])
Path(sys.argv[4]).write_text(str(time.monotonic()), encoding='utf-8')
_cli.main(['--home', sys.argv[2], 'update', '--check', '--force'], prog_name='legion')
"""
    marker = tmp_path / "cli-started"
    process = subprocess.run([sys.executable, "-c", script, str(plugin), str(tmp_path), stage, str(marker)], capture_output=True, text=True, timeout=60, check=False)
    finished = time.monotonic()
    assert process.returncode == 0, process.stderr
    assert process.stdout == FAILURE
    assert process.stderr == ""
    # Exclude interpreter startup and imports, but include the CLI call and process exit.
    elapsed = finished - float(marker.read_text(encoding="utf-8"))
    # With 32 CPU workers on one core, exit/wait overhead reached 5.5 s and marker-to-exit 9.3 s.
    # Leave scheduling slack while staying well below the fake opener's 60 s stall.
    assert 2.5 <= elapsed < 12
    assert json.loads(cache_path(tmp_path).read_text())["Failed"] is True


def test_cached_check_imports_only_stdlib(plugin: Path, tmp_path: Path) -> None:
    save_cache(tmp_path)
    script = """
import sys
import threading
from pathlib import Path
before = set(sys.modules)
from legion._update import get_update
assert get_update(Path(sys.argv[1]), Path(sys.argv[2])) is not None
assert not any(name in sys.modules for name in ('urllib.request', 'click', 'pydantic'))
assert not any(name.startswith('urllib') for name in set(sys.modules) - before)
"""
    result = subprocess.run([sys.executable, "-c", script, str(plugin), str(tmp_path)], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr


def test_legacy_help_lists_python_check(tmp_path: Path) -> None:
    pwsh = shutil.which("pwsh")
    assert pwsh is not None
    entry = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "legion.ps1"
    process = subprocess.run([pwsh, "-NoProfile", "-File", str(entry), "help", "-HomeRoot", str(tmp_path)], capture_output=True, text=True, check=False)
    assert process.returncode == 0, process.stderr
    assert "legion update --check [--force]" in process.stdout
