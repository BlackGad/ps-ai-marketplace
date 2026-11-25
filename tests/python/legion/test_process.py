import os
import subprocess
import sys
from datetime import UTC, datetime, timedelta
from pathlib import Path

import pytest

from legion.core import _process
from legion.core._process import ProcessInfo, ancestors, owner_process, process_started_at, same_start_time

BASE = datetime(2026, 11, 23, 8, 0, tzinfo=UTC)


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


def test_missing_process_has_no_start_time() -> None:
    # Pid 2**22 - 1 is above the default pid limit on Linux and unlikely on Windows and macOS.
    assert process_started_at(4_194_303) is None


def test_own_chain_starts_at_the_parent_and_goes_back_in_time() -> None:
    chain = ancestors(os.getpid())
    assert chain
    assert chain[0].pid == os.getppid()
    own = process_started_at(os.getpid())
    assert own is not None
    for child_start, parent in zip([own, *(item.started_at for item in chain)], chain, strict=False):
        # Hand-built, reason: rounded same-tick starts may reverse by a few microseconds.
        assert parent.started_at <= child_start or same_start_time(parent.started_at, child_start)


def test_own_owner_is_an_ancestor() -> None:
    owner = owner_process()
    assert owner.pid in {item.pid for item in ancestors(os.getpid())}


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


def test_measured_windows_chain_finds_the_agent() -> None:
    lookup = table(
        (17, 16, "python.exe", 60),
        (16, 15, "python.exe", 50),
        (15, 14, "uv.exe", 40),
        (14, 13, "bash.exe", 30),
        (13, 12, "bash.exe", 20),
        (12, 11, "bash.exe", 15),
        (11, 1, "claude.exe", 10),
    )
    assert owner_process(17, lookup).pid == 11


def test_legion_launcher_chain_finds_the_agent() -> None:
    lookup = table(
        (10, 9, "python.exe", 50),
        (9, 8, "legion.exe", 40),
        (8, 7, "uv.exe", 30),
        (7, 6, "cmd.exe", 20),
        (6, 1, "claude.exe", 10),
    )
    assert owner_process(10, lookup).pid == 6


def test_shell_only_chain_keeps_the_oldest_shell() -> None:
    lookup = table((10, 9, "python", 30), (9, 8, "bash", 20), (8, 7, "zsh", 10))
    assert owner_process(10, lookup).pid == 8


def test_reused_parent_pid_ends_the_chain() -> None:
    # Pid 9 now belongs to a process started after its "child", so it is not the real parent.
    lookup = table((10, 9, "python", 30), (9, 8, "claude", 40), (8, 1, "codex", 5))
    assert ancestors(10, lookup) == []
    with pytest.raises(LookupError, match="pass --process-id"):
        owner_process(10, lookup)


def test_same_tick_parent_stays_in_the_chain() -> None:
    # Hand-built, reason: a one-microsecond reversal reproduces rounded process start times deterministically.
    processes = {
        10: ProcessInfo(10, 9, "python", BASE),
        9: ProcessInfo(9, 1, "uv", BASE + timedelta(microseconds=1)),
    }
    assert [item.pid for item in ancestors(10, processes.get)] == [9]


def test_reused_pid_behind_a_shell_falls_back_to_the_shell() -> None:
    lookup = table((10, 9, "python", 30), (9, 8, "bash", 20), (8, 1, "claude", 25))
    assert owner_process(10, lookup).pid == 9


def test_exited_parent_ends_the_chain() -> None:
    lookup = table((10, 9, "python", 30))
    with pytest.raises(LookupError):
        owner_process(10, lookup)


def test_parent_loops_end_the_chain() -> None:
    lookup = table((10, 9, "python", 30), (9, 9, "bash", 20))
    assert [item.pid for item in ancestors(10, lookup)] == [9]


def test_module_imports_without_third_party_packages() -> None:
    source = Path(_process.__file__)
    script = (
        "import importlib.util, sys\n"
        f"spec = importlib.util.spec_from_file_location('probe', {str(source)!r})\n"
        "module = importlib.util.module_from_spec(spec)\n"
        "spec.loader.exec_module(module)\n"
        "assert module.process_started_at(module.os.getpid()) is not None\n"
        "print(sorted(name for name in ('click', 'pydantic', 'legion') if name in sys.modules))\n"
    )
    result = subprocess.run([sys.executable, "-I", "-c", script], capture_output=True, text=True, check=True)
    assert result.stdout.strip() == "[]"
