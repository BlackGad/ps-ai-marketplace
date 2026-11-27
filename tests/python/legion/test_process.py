import os
from datetime import UTC, datetime, timedelta

import pytest

from legion.core import _process
from legion.core._process import (
    ProcessInfo,
    ancestors,
    owner_process,
    process_started_at,
    same_start_time,
)

BASE = datetime(2026, 11, 23, 8, 0, tzinfo=UTC)


@pytest.fixture(autouse=True)
def no_shim_shell_pid(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("LEGION_SHELL_WINPID", raising=False)
    monkeypatch.delenv("LEGION_SHIM_WINPID", raising=False)


def table(*rows: tuple[int, int, str, int]) -> _process.Lookup:
    # Build a fake process table from (pid, parent pid, name, start offset in seconds).
    processes = {pid: ProcessInfo(pid, parent, name, BASE + timedelta(seconds=offset)) for pid, parent, name, offset in rows}
    return processes.get


def test_own_process_has_a_recent_start_time() -> None:
    started = process_started_at(os.getpid())
    assert started is not None
    assert started.tzinfo is not None
    assert datetime.now(UTC) - timedelta(days=1) < started <= datetime.now(UTC)


def test_start_time_is_stable_across_calls() -> None:
    first = process_started_at(os.getpid())
    second = process_started_at(os.getpid())
    assert first is not None
    assert second is not None
    assert same_start_time(first, second)


@pytest.mark.parametrize("pid", [4_194_303, 2**64])
def test_missing_process_has_no_start_time(pid: int) -> None:
    # Pid 2**22 - 1 is above the default pid limit on Linux and unlikely on Windows and macOS.
    assert process_started_at(pid) is None


def test_own_chain_starts_at_the_parent_and_goes_back_in_time() -> None:
    chain = ancestors(os.getpid())
    assert chain
    assert chain[0].pid == os.getppid()
    own = process_started_at(os.getpid())
    assert own is not None
    for child_start, parent in zip([own, *(item.started_at for item in chain)], chain, strict=False):
        # Hand-built, reason: rounded same-tick starts may reverse by a few microseconds.
        assert parent.started_at <= child_start or same_start_time(parent.started_at, child_start)


def test_own_owner_is_an_ancestor_or_refused() -> None:
    # In a container the chain can hold only shells and launchers; then the refusal is the right answer.
    chain = ancestors(os.getpid())
    if not any(not _process.is_skipped(item.name) for item in chain):
        with pytest.raises(LookupError, match="pass --process-id"):
            owner_process()
        return
    assert owner_process().pid in {item.pid for item in chain}


def test_same_start_time_uses_a_500_millisecond_window() -> None:
    assert same_start_time(BASE, BASE + timedelta(milliseconds=499))
    assert not same_start_time(BASE, BASE - timedelta(milliseconds=500))
    # A naive value from a lock file is treated as UTC, like a round-trip .NET value.
    assert same_start_time(BASE.replace(tzinfo=None), BASE)


@pytest.mark.parametrize("name", ["pwsh", "powershell.exe", "CMD.EXE", "sh", "bash", "zsh", "uv.exe", "python", "python3", "python3.12", "Python.exe"])
def test_shell_names_are_skipped(name: str) -> None:
    lookup = table((10, 9, "python.exe", 30), (9, 8, name, 20), (8, 1, "claude.exe", 10), (1, 0, "init", 0))
    assert owner_process(10, lookup).name == "claude.exe"


@pytest.mark.parametrize("name", ["claude", "codex.exe", "node", "copilot", "pythonista", "uvx"])
def test_other_names_are_owners(name: str) -> None:
    lookup = table((10, 9, "python", 30), (9, 8, name, 20), (8, 1, "claude", 10), (1, 0, "init", 0))
    assert owner_process(10, lookup).pid == 9


def test_legion_launcher_chain_finds_the_agent() -> None:
    lookup = table(
        (10, 9, "python.exe", 50),
        (9, 8, "legion.exe", 40),
        (8, 7, "uv.exe", 30),
        (7, 6, "cmd.exe", 20),
        (6, 1, "claude.exe", 10),
    )
    assert owner_process(10, lookup).pid == 6


def test_shell_only_chain_is_refused() -> None:
    lookup = table((10, 9, "python", 30), (9, 8, "bash", 20), (8, 7, "zsh", 10))
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(10, lookup)


def test_git_bash_shim_chain_with_an_exited_parent_is_refused() -> None:
    # Measured: an exec'd sh.exe shim keeps the pid of a parent that has already exited, so the chain stops at sh.exe.
    lookup = table(
        (17, 16, "python.exe", 60),
        (16, 15, "python.exe", 50),
        (15, 14, "legion.exe", 40),
        (14, 13, "uv.exe", 30),
        (13, 12, "sh.exe", 20),
    )
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(17, lookup)


def test_reused_parent_pid_ends_the_chain() -> None:
    # Pid 9 now belongs to a process started after its "child", so it is not the real parent.
    lookup = table((10, 9, "python", 30), (9, 8, "claude", 40), (8, 1, "codex", 5))
    assert ancestors(10, lookup) == []
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(10, lookup)


def test_same_tick_parent_stays_in_the_chain(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_process, "WINDOWS", False)
    # Hand-built, reason: a one-microsecond reversal reproduces rounded process start times deterministically.
    processes = {
        10: ProcessInfo(10, 9, "python", BASE),
        9: ProcessInfo(9, 1, "uv", BASE + timedelta(microseconds=1)),
    }
    assert [item.pid for item in ancestors(10, processes.get)] == [9]


CUT_CHAIN = (
    (17, 16, "python.exe", 60),
    (16, 15, "python.exe", 50),
    (15, 14, "legion.exe", 40),
    (14, 13, "uv.exe", 30),
    (13, 12, "sh.exe", 20),
)
SESSION_ABOVE_SHELL = ((22, 21, "bash.exe", 15), (21, 20, "bash.exe", 12), (20, 1, "claude.exe", 10))


def hint(monkeypatch: pytest.MonkeyPatch, shell: str, shim: str = "13") -> None:
    monkeypatch.setenv("LEGION_SHELL_WINPID", shell)
    monkeypatch.setenv("LEGION_SHIM_WINPID", shim)


def test_shim_hint_continues_a_cut_chain(monkeypatch: pytest.MonkeyPatch) -> None:
    hint(monkeypatch, "22")
    assert owner_process(17, table(*CUT_CHAIN, *SESSION_ABOVE_SHELL)).pid == 20


@pytest.mark.parametrize("shell", ["", "abc", "-5", "99"])
def test_invalid_or_dead_shell_hint_is_refused(monkeypatch: pytest.MonkeyPatch, shell: str) -> None:
    hint(monkeypatch, shell)
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(17, table(*CUT_CHAIN, *SESSION_ABOVE_SHELL))


@pytest.mark.parametrize("shim", ["", "abc", "99", "14"])
def test_hint_from_another_shim_is_refused(monkeypatch: pytest.MonkeyPatch, shim: str) -> None:
    # A hint inherited from another session names a live, older shell, but not the cut end of this chain.
    hint(monkeypatch, "22", shim)
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(17, table(*CUT_CHAIN, *SESSION_ABOVE_SHELL))


@pytest.mark.parametrize("shell_start", [timedelta(seconds=5), timedelta(milliseconds=100), timedelta(0)])
def test_shell_hint_started_at_or_after_the_shim_is_refused(monkeypatch: pytest.MonkeyPatch, shell_start: timedelta) -> None:
    # The hinted pid was reused by a process that started after the shim.
    hint(monkeypatch, "22")
    processes = {pid: ProcessInfo(pid, parent, name, BASE + timedelta(seconds=offset)) for pid, parent, name, offset in (*CUT_CHAIN, *SESSION_ABOVE_SHELL)}
    processes[22] = ProcessInfo(22, 21, "bash.exe", processes[13].started_at + shell_start)
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(17, processes.get)


def test_windows_parent_started_after_its_child_ends_the_chain(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_process, "WINDOWS", True)
    processes = {
        10: ProcessInfo(10, 9, "python", BASE),
        9: ProcessInfo(9, 1, "uv", BASE + timedelta(microseconds=1)),
    }
    assert ancestors(10, processes.get) == []


def test_reused_native_parent_of_the_shim_keeps_the_bound_hint_valid(monkeypatch: pytest.MonkeyPatch) -> None:
    # The shim's exited native parent pid 12 is reused 100 ms after the shim started; on Windows the walk must stop at the shim.
    monkeypatch.setattr(_process, "WINDOWS", True)
    hint(monkeypatch, "22")
    processes = {pid: ProcessInfo(pid, parent, name, BASE + timedelta(seconds=offset)) for pid, parent, name, offset in (*CUT_CHAIN, *SESSION_ABOVE_SHELL)}
    processes[12] = ProcessInfo(12, 1, "node.exe", processes[13].started_at + timedelta(milliseconds=100))
    assert owner_process(17, processes.get).pid == 20


def test_reused_pid_behind_a_shell_is_refused() -> None:
    lookup = table((10, 9, "python", 30), (9, 8, "bash", 20), (8, 1, "claude", 25))
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(10, lookup)


def test_parent_loops_end_the_chain() -> None:
    lookup = table((10, 9, "python", 30), (9, 9, "bash", 20))
    assert [item.pid for item in ancestors(10, lookup)] == [9]
