# The stop event: registered processes, the stop file, and the wait an update does before uv replaces legion.
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

from legion.core import _stop_event
from legion.core._home import run_folder


@pytest.fixture(autouse=True)
def quick_checks(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_stop_event, "CHECK_SECONDS", 0.05)


def wait_for(condition: object, seconds: float = 30) -> bool:
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if callable(condition) and condition():
            return True
        time.sleep(0.05)
    return False


def test_a_registered_process_leaves_a_file_with_its_pid_and_removes_it_at_the_end(tmp_path: Path) -> None:
    registration = run_folder(tmp_path) / f"{os.getpid()}.pid"
    with _stop_event.registered(tmp_path, lambda: None):
        assert registration.read_text(encoding="ascii") == str(os.getpid())
        assert _stop_event.running(tmp_path) == [os.getpid()]
    assert not registration.exists()
    assert _stop_event.running(tmp_path) == []


def test_the_registration_goes_even_when_the_block_fails(tmp_path: Path) -> None:
    with pytest.raises(RuntimeError), _stop_event.registered(tmp_path, lambda: None):
        raise RuntimeError("boom")
    assert list(run_folder(tmp_path).glob("*.pid")) == []


def test_the_stop_file_makes_a_registered_process_call_its_stop_handler_once(tmp_path: Path) -> None:
    stopped: list[int] = []
    with _stop_event.registered(tmp_path, lambda: stopped.append(1)):
        time.sleep(0.2)
        assert stopped == []
        _stop_event.raise_stop(tmp_path)
        assert wait_for(lambda: stopped)
        time.sleep(0.3)
    assert stopped == [1]


def test_a_stop_file_left_by_a_dead_update_stops_nothing(tmp_path: Path) -> None:
    _stop_event.raise_stop(tmp_path)
    old = time.time() - _stop_event.STOP_VALID_SECONDS - 5
    os.utime(_stop_event.stop_path(tmp_path), (old, old))
    assert not _stop_event.stop_raised(tmp_path)
    stopped: list[int] = []
    with _stop_event.registered(tmp_path, lambda: stopped.append(1)):
        time.sleep(0.3)
    assert stopped == []


def test_clearing_the_stop_event_twice_is_fine(tmp_path: Path) -> None:
    _stop_event.raise_stop(tmp_path)
    _stop_event.clear_stop(tmp_path)
    _stop_event.clear_stop(tmp_path)
    assert not _stop_event.stop_path(tmp_path).exists()


def test_running_removes_the_files_of_dead_processes_and_unreadable_files(tmp_path: Path) -> None:
    folder = run_folder(tmp_path)
    folder.mkdir(parents=True)
    child = subprocess.Popen([sys.executable, "-c", "pass"])
    child.wait()
    dead = folder / f"{child.pid}.pid"
    dead.write_text(str(child.pid), encoding="ascii")
    garbage = folder / "oops.pid"
    garbage.write_text("not a number", encoding="ascii")
    own = folder / f"{os.getpid()}.pid"
    own.write_text(str(os.getpid()), encoding="ascii")
    assert _stop_event.running(tmp_path) == [os.getpid()]
    assert not dead.exists()
    assert not garbage.exists()
    assert own.exists()


def test_a_pid_that_a_newer_process_reuses_is_stale(tmp_path: Path) -> None:
    folder = run_folder(tmp_path)
    folder.mkdir(parents=True)
    registration = folder / f"{os.getpid()}.pid"
    registration.write_text(str(os.getpid()), encoding="ascii")
    long_ago = time.time() - 86400 * 365
    os.utime(registration, (long_ago, long_ago))
    assert _stop_event.running(tmp_path) == []
    assert not registration.exists()


def test_stop_all_raises_the_event_and_returns_at_once_when_nothing_runs(tmp_path: Path) -> None:
    assert _stop_event.stop_all(tmp_path) == []
    assert _stop_event.stop_path(tmp_path).is_file()


def test_stop_all_protects_the_caller_and_its_registered_ancestor(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    stopped: list[bool] = []
    parent = run_folder(tmp_path) / f"{os.getppid()}.pid"
    with _stop_event.registered(tmp_path, lambda: stopped.append(True)):
        parent.write_text(str(os.getppid()), encoding="ascii")
        assert _stop_event.stop_all(tmp_path, timeout=0.2) == []
        assert not _stop_event.stop_raised(tmp_path, pid=os.getppid())
        time.sleep(0.2)
        assert stopped == []
        assert set(_stop_event.running(tmp_path)) == {os.getpid(), os.getppid()}
    assert capsys.readouterr().err.splitlines() == ["Restart this session after the legion update."]


# The process id a started process registered: on Windows a venv's python.exe starts the real one, so it is not the Popen pid.
def registered_pid(home: Path) -> int:
    assert wait_for(lambda: list(run_folder(home).glob("*.pid")))
    (registration,) = run_folder(home).glob("*.pid")
    return int(registration.read_text(encoding="ascii"))


# A process that registers, then sleeps; `handler` is the Python text of its stop handler.
def start_registered(home: Path, handler: str, seconds: float) -> subprocess.Popen[bytes]:
    lines = [
        "import os, sys, time",
        "from pathlib import Path",
        "from legion.core import _stop_event",
        "_stop_event.CHECK_SECONDS = 0.05",
        f"with _stop_event.registered(Path(sys.argv[1]), {handler}):",
        f"    time.sleep({seconds})",
    ]
    return subprocess.Popen([sys.executable, "-c", os.linesep.join(lines), str(home)])


def test_stop_all_waits_until_a_registered_process_is_gone(tmp_path: Path) -> None:
    child = start_registered(tmp_path, "lambda: None", 1.5)
    try:
        registered_pid(tmp_path)
        started = time.monotonic()
        assert _stop_event.stop_all(tmp_path, timeout=30, poll=0.05) == []
        assert time.monotonic() - started >= 0.5
    finally:
        child.kill()
        child.wait()


def test_stop_all_waits_for_a_real_process_that_ends_on_the_stop_file_and_leaves_no_registration(tmp_path: Path) -> None:
    child = start_registered(tmp_path, "lambda: os._exit(0)", 60)
    try:
        registered_pid(tmp_path)
        assert _stop_event.stop_all(tmp_path, timeout=30, poll=0.05) == []
        assert child.wait(30) == 0
    finally:
        child.kill()
    assert list(run_folder(tmp_path).glob("*.pid")) == []


def test_stop_all_times_out_naming_a_process_that_ignores_the_stop_file(tmp_path: Path) -> None:
    child = start_registered(tmp_path, "lambda: None", 60)
    try:
        pid = registered_pid(tmp_path)
        assert _stop_event.stop_all(tmp_path, timeout=0.5, poll=0.05) == [pid]
    finally:
        child.kill()
        child.wait()


# The real MCP server: it registers, serves over stdio and exits when the stop file appears.
def test_the_mcp_server_registers_and_exits_on_the_stop_event(tmp_path: Path) -> None:
    pytest.importorskip("mcp")
    server = subprocess.Popen([sys.executable, "-I", "-m", "legion.cli", "--home", str(tmp_path), "mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    try:
        registered_pid(tmp_path)
        _stop_event.raise_stop(tmp_path)
        assert server.wait(30) == 0
    finally:
        if server.poll() is None:
            server.kill()
        for stream in (server.stdin, server.stdout, server.stderr):
            if stream:
                stream.close()
    assert _stop_event.running(tmp_path) == []
