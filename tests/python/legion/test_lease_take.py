import os
from datetime import UTC, datetime, timedelta
from pathlib import Path
from unittest.mock import Mock

import psutil
import pytest

from legion.core._process import ProcessInfo, owner_process
from legion.services.repository import _lease, _lease_take
from legion.services.repository._lease import LeaseError, lease_path, release, state
from legion.services.repository._lease_take import take_for_session

BASE = datetime(2026, 11, 20, tzinfo=UTC)


class FakeProcess:
    def __init__(self, command_line: object) -> None:
        self.command_line = command_line

    def cmdline(self) -> list[str]:
        if isinstance(self.command_line, Exception):
            raise self.command_line
        assert isinstance(self.command_line, list)
        return self.command_line


def chain(monkeypatch: pytest.MonkeyPatch, name: str, command_line: object) -> None:
    processes = {
        10: ProcessInfo(10, 9, "legion.exe", BASE + timedelta(seconds=30)),
        9: ProcessInfo(9, 8, "pwsh.exe", BASE + timedelta(seconds=20)),
        8: ProcessInfo(8, 1, name, BASE + timedelta(seconds=10)),
        1: ProcessInfo(1, 0, "init", BASE),
    }
    monkeypatch.setattr(_lease_take, "owner_process", lambda: owner_process(10, processes.get))
    monkeypatch.setattr(_lease_take, "process_lookup", lambda: processes.get)
    monkeypatch.setattr(psutil, "Process", lambda _: FakeProcess(command_line))
    # The fake chain is not a real process, so the lease cannot be written for it.
    monkeypatch.setattr(_lease_take, "take", Mock(return_value="lease taken"))


DAEMON = ["codex.exe", "app-server", "--listen", "unix://", "--managed-daemon"]


def test_inferred_app_server_is_refused_and_names_process_id(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    chain(monkeypatch, "codex.exe", DAEMON)
    with pytest.raises(LeaseError, match="--process-id"):
        take_for_session(tmp_path, "codex", "owner")


def test_explicit_app_server_pid_is_refused(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    chain(monkeypatch, "codex.exe", DAEMON)
    with pytest.raises(LeaseError, match="--process-id"):
        take_for_session(tmp_path, "codex", "owner", process_id=8)


@pytest.mark.parametrize("command_line", [psutil.AccessDenied(8), psutil.NoSuchProcess(8), []])
def test_unreadable_codex_command_line_is_refused(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, command_line: object) -> None:
    chain(monkeypatch, "codex.exe", command_line)
    with pytest.raises(LeaseError, match=r"cannot read the command line.*--process-id"):
        take_for_session(tmp_path, "codex", "owner")


@pytest.mark.parametrize("name", ["codex-aarch64-apple-darwin", "Codex", "CODEX.EXE"])
def test_target_suffixed_and_cased_codex_names_are_checked(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, name: str) -> None:
    chain(monkeypatch, name, [name, "app-server"])
    with pytest.raises(LeaseError, match="app-server daemon"):
        take_for_session(tmp_path, "codex", "owner")


def test_app_server_as_a_later_argument_is_accepted(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    chain(monkeypatch, "codex.exe", ["codex.exe", "exec", "app-server"])
    assert take_for_session(tmp_path, "codex", "owner") == "lease taken"


def test_normal_codex_session_is_accepted(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    chain(monkeypatch, "codex.exe", ["codex.exe", "-c", "features.x=true"])
    assert take_for_session(tmp_path, "codex", "owner") == "lease taken"


def test_non_codex_owner_is_not_inspected(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    chain(monkeypatch, "claude.exe", psutil.AccessDenied(8))
    assert take_for_session(tmp_path, "claude", "owner") == "lease taken"


def test_release_still_works_for_a_lease_held_by_a_daemon(tmp_path: Path) -> None:
    _lease.take(tmp_path, "codex", "owner", process_id=os.getpid())
    assert state(tmp_path).state == "held"
    assert release(tmp_path, process_id=os.getpid()) == "lease released"
    assert not lease_path(tmp_path).exists()
