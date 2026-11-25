import contextlib
import errno
import json
import os
import signal
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import Optional
from types import SimpleNamespace
from unittest.mock import Mock

import pytest
import psutil
from process_ready import timeout_after_ready

from legion.core import _run
from legion.core._process import process_started_at
from legion.core._run import run_command

PYTHON = sys.executable

# The grandchild publishes its pid; a reader that sees the file sees all of it.
PUBLISH_PID = "import os, sys; from pathlib import Path; part = Path(sys.argv[1] + '.part'); part.write_text(str(os.getpid())); part.replace(sys.argv[1])"
GRANDCHILD = PUBLISH_PID + "; import time; time.sleep(60)"

# The child starts a grandchild that records its pid, then both sleep far past the timeout.
TREE = f"""
import subprocess, sys, time
from pathlib import Path
subprocess.Popen([sys.executable, "-c", {GRANDCHILD!r}, sys.argv[1]])
while not Path(sys.argv[1]).is_file():
    time.sleep(0.05)
print("tree started", flush=True)
Path(sys.argv[1] + ".ready").touch()
time.sleep(60)
"""


# The child starts a grandchild that holds both pipes, then exits at once.
QUICK_PARENT = f"""
import subprocess, sys
subprocess.Popen([sys.executable, "-c", {GRANDCHILD!r}, sys.argv[1]])
"""

# Pauses every write_text between creating the file and writing it, as a busy machine can.
PAUSED_WRITE = """
import pathlib, time
def paused_write_text(self, data, encoding=None, errors=None, newline=None):
    with open(self, "w", encoding=encoding, errors=errors, newline=newline) as file:
        file.flush()
        time.sleep(1)
        file.write(data)
pathlib.Path.write_text = paused_write_text
"""


def wait_until_gone(pid: int) -> None:
    deadline = time.monotonic() + 10
    while process_started_at(pid) is not None and time.monotonic() < deadline:
        time.sleep(0.1)
    assert process_started_at(pid) is None


def read_pid(marker: Path) -> int:
    deadline = time.monotonic() + 20
    while not marker.is_file() and time.monotonic() < deadline:
        time.sleep(0.05)
    return int(marker.read_text(encoding="utf-8"))


def test_grandchild_pid_is_complete_once_its_file_appears(tmp_path: Path) -> None:
    marker = tmp_path / "grandchild.pid"
    child = subprocess.Popen([PYTHON, "-c", PAUSED_WRITE + PUBLISH_PID, str(marker)])
    try:
        assert read_pid(marker) > 0
    finally:
        child.wait(30)


def test_success_captures_both_streams() -> None:
    result = run_command(PYTHON, ["-c", "import sys; sys.stdout.buffer.write('out ✓'.encode()); print('err', file=sys.stderr)"], timeout=30)
    assert (result.exit_code, result.timed_out) == (0, False)
    assert result.output.strip() == "out ✓"
    assert result.error.strip() == "err"


def test_non_zero_exit_code_is_returned() -> None:
    result = run_command(PYTHON, ["-c", "raise SystemExit(7)"], timeout=30)
    assert (result.exit_code, result.timed_out) == (7, False)


def test_stdin_is_closed() -> None:
    result = run_command(PYTHON, ["-c", "import sys; print(repr(sys.stdin.read()))"], timeout=30)
    assert result.output.strip() == "''"


def test_arguments_keep_spaces_and_quotes() -> None:
    result = run_command(PYTHON, ["-c", "import sys; print(sys.argv[1:])", "two words", 'say "hi"', ""], timeout=30)
    assert result.output.strip() == str(["two words", 'say "hi"', ""])


def test_timeout_kills_the_whole_tree(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    marker = tmp_path / "grandchild.pid"
    ready = timeout_after_ready(monkeypatch, Path(f"{marker}.ready"))
    result = run_command(PYTHON, ["-c", TREE, str(marker)], timeout=3)
    assert time.monotonic() - ready[0] < 30
    assert (result.exit_code, result.timed_out) == (-1, True)
    assert "tree started" in result.output
    wait_until_gone(int(marker.read_text(encoding="utf-8")))


@pytest.mark.parametrize("stop", ["timeout", "cancel"])
@pytest.mark.parametrize("group_state", ["live", "zombies", "gone", "exits-during-signal"])
def test_darwin_group_exit_race_keeps_cleanup_and_outcome(monkeypatch: pytest.MonkeyPatch, stop: str, group_state: str) -> None:
    # Hand-built: Darwin excludes zombies from killpg and returns EPERM for an existing
    # group with no eligible members. Force both sides of the individual-kill race.
    group_status = "zombie" if group_state in {"zombies", "gone"} else "live"
    states = {101: group_status, 102: group_status, 103: "live", 104: group_status, 999: "live"}
    group = (101, 102, 104)  # 103 detached; 104 outlived discovery; 999 is unrelated.
    events: list[int] = []

    def kill(pid: int) -> None:
        events.append(pid)
        if states[pid] == "zombie":
            raise psutil.NoSuchProcess(pid)
        states[pid] = "zombie"

    parent = Mock(spec=psutil.Process, pid=101)
    child = Mock(spec=psutil.Process, pid=102)
    detached = Mock(spec=psutil.Process, pid=103)
    parent.children.side_effect = [[child, detached], [], []]
    child.children.return_value = detached.children.return_value = []
    for member in (parent, child, detached):
        member.kill.side_effect = lambda pid=member.pid: kill(pid)

    def killpg(pgid: int, sig: int) -> None:
        assert (pgid, sig) == (101, 9)
        events.append(-pgid)
        if group_state == "gone":
            raise ProcessLookupError(errno.ESRCH, "No such process")
        if group_state == "exits-during-signal":
            for pid in group:
                states[pid] = "zombie"
        if all(states[pid] == "zombie" for pid in group):
            raise PermissionError(errno.EPERM, "Operation not permitted")
        for pid in group:
            states[pid] = "zombie"

    cancelled = threading.Event()
    process = Mock(spec=subprocess.Popen, pid=101, returncode=-9)

    def communicate(timeout: Optional[float] = None) -> tuple[bytes, bytes]:
        del timeout
        if not events:
            if stop == "cancel":
                cancelled.set()
            raise subprocess.TimeoutExpired("fake", 0)
        return b"tree started\n", b""

    process.communicate.side_effect = communicate
    monkeypatch.setattr(_run, "sys", SimpleNamespace(platform="darwin"))
    monkeypatch.setattr(_run, "signal", SimpleNamespace(SIGKILL=9))
    monkeypatch.setattr(subprocess, "Popen", Mock(return_value=process))
    monkeypatch.setattr(psutil, "Process", Mock(return_value=parent))
    monkeypatch.setattr(os, "killpg", killpg, raising=False)
    with _run.command_cancellation(cancelled):
        if stop == "cancel":
            with pytest.raises(_run.CommandCancelled):
                run_command("fake", [], timeout=30)
        else:
            result = run_command("fake", [], timeout=0)
            assert (result.exit_code, result.timed_out, result.output) == (-1, True, "tree started\n")
    assert events == [-101, 103, 102, 101]
    assert states == {101: "zombie", 102: "zombie", 103: "zombie", 104: "zombie", 999: "live"}
    assert process.communicate.call_count == 2


def test_group_permission_error_does_not_hide_owned_process_denial(monkeypatch: pytest.MonkeyPatch) -> None:
    parent = Mock(spec=psutil.Process, pid=101)
    parent.children.return_value = []
    parent.kill.side_effect = psutil.AccessDenied(101)
    group_kill = Mock(side_effect=PermissionError(errno.EPERM, "Operation not permitted"))
    monkeypatch.setattr(_run, "sys", SimpleNamespace(platform="darwin"))
    monkeypatch.setattr(_run, "signal", SimpleNamespace(SIGKILL=9))
    monkeypatch.setattr(os, "killpg", group_kill, raising=False)
    with pytest.raises(psutil.AccessDenied):
        _run._kill_tree(Mock(pid=101), None, {101: parent})
    group_kill.assert_called_once_with(101, 9)


def test_child_that_starts_a_process_and_exits_at_once_is_still_stopped(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    marker = tmp_path / "grandchild.pid"
    ready = timeout_after_ready(monkeypatch, marker)
    result = run_command(PYTHON, ["-c", QUICK_PARENT, str(marker)], timeout=3)
    assert time.monotonic() - ready[0] < 30
    assert (result.exit_code, result.timed_out) == (-1, True)
    wait_until_gone(read_pid(marker))


def test_tree_stop_is_retried_when_a_descendant_keeps_pipes_open(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    marker = tmp_path / "grandchild.pid"
    ready = timeout_after_ready(monkeypatch, marker)
    kill_tree = _run._kill_tree
    attempts = 0

    # Hand-built, reason: a missed first stop makes the existing drain fallback observable.
    def miss_once(process: "subprocess.Popen[bytes]", job: Optional[int], owned: dict[int, psutil.Process]) -> None:
        nonlocal attempts
        attempts += 1
        if attempts > 1:
            kill_tree(process, job, owned)

    monkeypatch.setattr(_run, "_kill_tree", miss_once)
    grandchild = None
    try:
        result = run_command(PYTHON, ["-c", QUICK_PARENT, str(marker)], timeout=3)
        grandchild = read_pid(marker)
        assert time.monotonic() - ready[0] < 3 + 2 * _run.DRAIN_SECONDS + 10
        assert (result.exit_code, result.timed_out) == (-1, True)
        wait_until_gone(grandchild)
    finally:
        if grandchild is not None and process_started_at(grandchild) is not None:
            with contextlib.suppress(OSError):
                os.kill(grandchild, signal.SIGTERM)
            wait_until_gone(grandchild)


# A survivor that keeps the pipes open must not keep the caller waiting past the drain bound.
def test_drain_after_a_timeout_is_bounded(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def kill_only_the_child(process: "subprocess.Popen[bytes]", job: Optional[int], owned: dict[int, psutil.Process]) -> None:
        del job, owned
        process.kill()

    monkeypatch.setattr(_run, "_kill_tree", kill_only_the_child)
    marker = tmp_path / "grandchild.pid"
    ready = timeout_after_ready(monkeypatch, Path(f"{marker}.ready"))
    result = run_command(PYTHON, ["-c", TREE, str(marker)], timeout=3)
    grandchild = read_pid(marker)
    try:
        assert time.monotonic() - ready[0] < 3 + _run.DRAIN_SECONDS + 10
        assert (result.exit_code, result.timed_out) == (-1, True)
    finally:
        with contextlib.suppress(OSError):
            os.kill(grandchild, signal.SIGTERM)
    wait_until_gone(grandchild)


@pytest.mark.skipif(sys.platform != "win32", reason="Windows jobs")
def test_failed_job_assignment_never_runs_the_child(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_run, "_assign_to_job", lambda *_: False)
    marker = tmp_path / "ran"
    with pytest.raises(OSError, match="job"):
        run_command(PYTHON, ["-c", "import sys; from pathlib import Path; Path(sys.argv[1]).write_text('ran')", str(marker)], timeout=30)
    time.sleep(1)
    assert not marker.exists()


@pytest.mark.skipif(sys.platform != "win32", reason="cmd wrappers exist only on Windows")
def test_cmd_wrapper_keeps_every_character_literal(tmp_path: Path) -> None:
    script = tmp_path / "show.py"
    script.write_text("import json, sys\nprint(json.dumps(sys.argv[1:]))\n", encoding="utf-8")
    wrapper = tmp_path / "my tool.cmd"
    wrapper.write_text(f'@"{PYTHON}" "{script}" %*\r\n', encoding="utf-8")
    arguments = ["%PATH%", "%cd%", 'say "hi"', 'back\\"slash', "& | < > ^ ! ( )", "%%", "x%", "end\\", ""]
    result = run_command(str(wrapper), arguments, timeout=30)
    assert result.exit_code == 0, result.error
    assert result.output.strip() == json.dumps(arguments)


@pytest.mark.skipif(sys.platform != "win32", reason="cmd wrappers exist only on Windows")
def test_cmd_wrapper_refuses_a_line_break() -> None:
    with pytest.raises(ValueError, match="line break"):
        run_command("tool.cmd", ["two\nlines"], timeout=30)


@pytest.mark.skipif(sys.platform != "win32", reason="cmd wrappers exist only on Windows")
def test_cmd_wrapper_runs_through_cmd(tmp_path: Path) -> None:
    wrapper = tmp_path / "my tool.cmd"
    wrapper.write_text("@echo off\r\necho [%~1] [%~2]\r\nexit /b 3\r\n", encoding="utf-8")
    result = run_command(str(wrapper), ["two words", "x"], timeout=30)
    assert result.exit_code == 3
    assert result.output.strip() == "[two words] [x]"
