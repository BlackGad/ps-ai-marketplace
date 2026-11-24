import json
import multiprocessing
import os
import socket
import subprocess
import sys
import time
from datetime import timedelta
from multiprocessing.synchronize import Barrier, Event
from pathlib import Path
from typing import Optional

import pytest

from legion import _lease
from legion._lease import (
    Lease,
    LeaseError,
    lease_path,
    release,
    state,
    take,
)
from legion._process import process_started_at

REPO_ROOT = Path(__file__).resolve().parents[3]
DEAD_PID = 99_999_999


def own_started_at() -> str:
    started = process_started_at(os.getpid())
    assert started is not None
    return _lease.round_trip(started) + "Z"


def write_lease(repo: Path, **fields: object) -> Path:
    data: dict[str, object] = {
        "tool": "codex",
        "account": "owner",
        "pid": os.getpid(),
        "processStartedAt": own_started_at(),
        "host": socket.gethostname(),
        "startedAt": "2026-11-18T10:00:00Z",
    }
    data.update(fields)
    path = lease_path(repo)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({key: value for key, value in data.items() if value is not None}), encoding="utf-8")
    return path


def make_old(path: Path) -> None:
    old = time.time() - 300
    os.utime(path, (old, old))


# Lease ownership and state


def test_free_without_a_lock(tmp_path: Path) -> None:
    assert state(tmp_path).state == "free"


def test_helper_takes_for_its_long_lived_owner_and_releases(tmp_path: Path) -> None:
    assert take(tmp_path, "codex", "session") == "lease taken"
    current = state(tmp_path)
    assert current.state == "held"
    assert current.lease is not None
    assert current.lease.pid != os.getpid()
    assert current.lease.process_started_at is not None
    assert current.lease.host == socket.gethostname()
    assert release(tmp_path) == "lease released"
    assert not lease_path(tmp_path).exists()


@pytest.mark.parametrize("host", [socket.gethostname(), "fixture-foreign-host"])
@pytest.mark.parametrize("missing", ["processStartedAt", "pid", "host"])
def test_lease_without_process_identity_is_stale_on_any_host(tmp_path: Path, host: str, missing: str) -> None:
    fields: dict[str, object] = {"host": host, missing: None}
    write_lease(tmp_path, **fields)
    assert state(tmp_path).state == "stale"


def test_foreign_host_and_host_case(tmp_path: Path) -> None:
    write_lease(tmp_path, host="fixture-foreign-host")
    assert state(tmp_path).state == "foreign"
    write_lease(tmp_path, host=socket.gethostname().swapcase())
    assert state(tmp_path).state == "held"


def test_reused_pid_with_another_start_time_is_stale_and_cannot_be_released(tmp_path: Path) -> None:
    started = process_started_at(os.getpid())
    assert started is not None
    path = write_lease(tmp_path, processStartedAt=_lease.round_trip(started - timedelta(seconds=1)) + "Z")
    assert state(tmp_path).state == "stale"
    with pytest.raises(LeaseError, match="belongs to another session"):
        release(tmp_path, process_id=os.getpid())
    assert path.exists()


def test_take_twice_skips_and_others_cannot_release(tmp_path: Path) -> None:
    write_lease(tmp_path, pid=DEAD_PID)
    assert state(tmp_path).state == "stale"
    assert take(tmp_path, "codex", "owner", process_id=os.getpid()) == "lease taken"
    assert state(tmp_path).state == "held"
    assert take(tmp_path, "codex", "owner", process_id=os.getpid()).startswith("skip:")
    with pytest.raises(LeaseError):
        release(tmp_path, process_id=DEAD_PID)
    assert lease_path(tmp_path).exists()
    assert release(tmp_path, process_id=os.getpid()) == "lease released"
    assert not lease_path(tmp_path).exists()
    assert release(tmp_path, process_id=os.getpid()).startswith("skip:")


def test_take_refuses_held_and_foreign_leases(tmp_path: Path) -> None:
    write_lease(tmp_path, tool="claude", account="claude-a", startedAt="2026-11-18T10:00:00Z")
    with pytest.raises(LeaseError, match="lease held by claude claude-a since 2026-11-18T10:00:00Z"):
        take(tmp_path, "codex", "other", process_id=os.getppid())
    write_lease(tmp_path, host="fixture-foreign-host")
    with pytest.raises(LeaseError, match="lease from host fixture-foreign-host; ask the owner"):
        take(tmp_path, "codex", "other", process_id=os.getpid())


def test_release_without_a_lock_skips_before_looking_for_the_owner(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def no_owner() -> None:
        raise LookupError("cannot find the agent session process; pass --process-id explicitly")

    monkeypatch.setattr(_lease, "owner_process", no_owner)
    assert release(tmp_path) == "skip: lease release (already done)"


def test_take_needs_a_running_owner(tmp_path: Path) -> None:
    with pytest.raises(LeaseError, match="not running"):
        take(tmp_path, "codex", "owner", process_id=DEAD_PID)
    assert not lease_path(tmp_path).exists()


def test_written_lock_uses_powershell_field_names_and_formats(tmp_path: Path) -> None:
    take(tmp_path, "codex", "owner", process_id=os.getpid())
    text = lease_path(tmp_path).read_text(encoding="utf-8")
    assert text.endswith("\n")
    data = json.loads(text)
    assert set(data) == {"tool", "account", "pid", "processStartedAt", "host", "startedAt"}
    assert data["pid"] == os.getpid()
    # .NET round-trip format: seven fraction digits; a UTC DateTime ends in Z, a DateTimeOffset in +00:00.
    assert len(data["processStartedAt"]) == len("2026-11-18T10:00:00.0000000Z")
    assert data["processStartedAt"].endswith("Z")
    assert len(data["startedAt"]) == len("2026-11-18T10:00:00.0000000+00:00")
    assert data["startedAt"].endswith("+00:00")


@pytest.mark.skipif(sys.platform == "win32", reason="zombie processes exist on Linux and macOS only")
def test_zombie_owner_is_stale(tmp_path: Path) -> None:
    child = subprocess.Popen([sys.executable, "-c", "import sys; sys.stdin.buffer.read(1)"], stdin=subprocess.PIPE)
    try:
        started = process_started_at(child.pid)
        assert started is not None
        write_lease(tmp_path, pid=child.pid, processStartedAt=_lease.round_trip(started) + "Z")
        assert child.stdin is not None
        child.stdin.close()
        deadline = time.monotonic() + 60
        while process_started_at(child.pid) is not None and time.monotonic() < deadline:
            time.sleep(0.05)
        assert state(tmp_path).state == "stale"
    finally:
        if process_started_at(child.pid) is not None:
            child.kill()
        child.wait()


# Concurrent lease acquisition and takeover


def test_lock_being_written_is_held_then_stale_when_old(tmp_path: Path) -> None:
    path = lease_path(tmp_path)
    path.parent.mkdir(parents=True)
    for partial in ("", '{"tool":"co'):
        path.write_text(partial, encoding="utf-8")
        current = state(tmp_path)
        assert (current.state, current.lease) == ("held", None)
        with pytest.raises(LeaseError, match="being written or cannot be read; retry"):
            take(tmp_path, "codex", "other", process_id=os.getpid())
        make_old(path)
        assert state(tmp_path).state == "stale"


def test_old_unreadable_lock_can_be_taken(tmp_path: Path) -> None:
    path = lease_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_text("not json", encoding="utf-8")
    make_old(path)
    assert take(tmp_path, "codex", "owner", process_id=os.getpid()) == "lease taken"
    assert state(tmp_path).state == "held"


def racer(repo: str, account: str, start: Barrier, done: Event, results: "multiprocessing.Queue[str]") -> None:
    start.wait()
    try:
        take(Path(repo), "codex", account, process_id=os.getpid())
        results.put("won")
    except LeaseError as error:
        results.put(f"lost: {error}")
    except Exception as error:  # Report it, so the test shows the cause instead of waiting for a dead racer.
        results.put(f"failed: {error!r}")
    # Stay alive so the winner's lease is held while the others check it.
    done.wait(30)


def run_racers(repo: Path, count: int) -> list[str]:
    context = multiprocessing.get_context("spawn")
    start, done, results = context.Barrier(count), context.Event(), context.Queue()
    processes = [context.Process(target=racer, args=(str(repo), f"racer{index}", start, done, results)) for index in range(count)]
    for process in processes:
        process.start()
    try:
        return [results.get(timeout=60) for _ in processes]
    finally:
        done.set()
        for process in processes:
            process.join(30)


@pytest.mark.parametrize("stale", [False, True])
def test_only_one_concurrent_take_wins(tmp_path: Path, stale: bool) -> None:
    if stale:
        write_lease(tmp_path, account="dead", pid=DEAD_PID, processStartedAt="2026-11-18T08:00:00Z")
    outcomes = run_racers(tmp_path, 5)
    assert outcomes.count("won") == 1, outcomes
    saved = json.loads(lease_path(tmp_path).read_text(encoding="utf-8"))
    assert saved["host"] == socket.gethostname()
    # Every racer has exited, so the lock it left is stale.
    assert state(tmp_path).state == "stale"


def hold_guard(repo: str, held: Event) -> None:
    guard = _lease._open_guard(lease_path(Path(repo)))
    assert guard is not None
    held.set()
    time.sleep(120)  # Paused while changing the lease; the test ends it without any cleanup.


# A paused holder keeps the guard however old the file is; the OS frees it when the holder exits.
def test_paused_guard_holder_blocks_takeover_and_release_until_it_exits(tmp_path: Path) -> None:
    write_lease(tmp_path, pid=DEAD_PID)
    context = multiprocessing.get_context("spawn")
    held = context.Event()
    holder = context.Process(target=hold_guard, args=(str(tmp_path), held))
    holder.start()
    try:
        assert held.wait(60)
        guard = Path(f"{lease_path(tmp_path)}.takeover")
        old = time.time() - 600
        os.utime(guard, (old, old))
        with pytest.raises(LeaseError, match="change in progress"):
            take(tmp_path, "codex", "owner", process_id=os.getpid())
        assert json.loads(lease_path(tmp_path).read_text(encoding="utf-8"))["pid"] == DEAD_PID
        with pytest.raises(LeaseError, match="change in progress"):
            release(tmp_path, process_id=DEAD_PID)
    finally:
        holder.kill()
        holder.join(30)
    assert take(tmp_path, "codex", "owner", process_id=os.getpid()) == "lease taken"
    assert release(tmp_path, process_id=os.getpid()) == "lease released"


def paused_taker(repo: str, created: Event, resume: Event, results: "multiprocessing.Queue[str]") -> None:
    real_to_json = Lease.to_json

    # The lock file exists now; its record is not written yet.
    def paused_to_json(lease: Lease) -> str:
        created.set()
        resume.wait(60)
        return real_to_json(lease)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(Lease, "to_json", paused_to_json)
        try:
            results.put(take(Path(repo), "codex", "first", process_id=os.getpid()))
        except LeaseError as error:
            results.put(f"lost: {error}")


# A taker paused between creating the lock and writing it keeps the guard, so an old empty lock is not taken.
def test_taker_paused_between_create_and_write_keeps_the_lease(tmp_path: Path) -> None:
    context = multiprocessing.get_context("spawn")
    created, resume, results = context.Event(), context.Event(), context.Queue()
    first = context.Process(target=paused_taker, args=(str(tmp_path), created, resume, results))
    first.start()
    try:
        assert created.wait(60)
        make_old(lease_path(tmp_path))
        with pytest.raises(LeaseError, match="change in progress in another session; retry"):
            take(tmp_path, "codex", "second", process_id=os.getpid())
        resume.set()
        assert results.get(timeout=60) == "lease taken"
    finally:
        resume.set()
        first.join(30)
    assert json.loads(lease_path(tmp_path).read_text(encoding="utf-8"))["account"] == "first"


# Only a lock that was read and is not a lease can age into stale; one that cannot be read is never taken over.
def test_old_lock_that_cannot_be_read_is_not_taken(tmp_path: Path) -> None:
    path = write_lease(tmp_path, pid=DEAD_PID)
    make_old(path)
    real_read_text = Path.read_text

    def refused(target: Path, encoding: Optional[str] = None, errors: Optional[str] = None) -> str:
        if target == path:
            raise PermissionError(13, "Permission denied")
        return real_read_text(target, encoding, errors)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(Path, "read_text", refused)
        patch.setattr(_lease, "RETRY_PAUSE_SECONDS", 0)
        assert (state(tmp_path).state, state(tmp_path).lease) == ("held", None)
        with pytest.raises(LeaseError, match="cannot be read; retry, or check its permissions"):
            take(tmp_path, "codex", "owner", process_id=os.getpid())
    assert json.loads(path.read_text(encoding="utf-8"))["pid"] == DEAD_PID


# The lock is read directly: an error while checking that it exists cannot skip the read-error handling.
def test_state_does_not_depend_on_an_existence_check(tmp_path: Path) -> None:
    write_lease(tmp_path)

    def denied(_target: Path, **_options: object) -> bool:
        raise PermissionError(13, "Permission denied")

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(Path, "exists", denied)
        assert state(tmp_path).state == "held"


# On Windows a lock another process has open cannot be removed; the change fails with a retry message.
@pytest.fixture
def lease_in_use(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    path = lease_path(tmp_path)
    real_unlink = Path.unlink

    def busy_unlink(target: Path, missing_ok: bool = False) -> None:
        if target == path:
            raise PermissionError(32, "The process cannot access the file because it is being used by another process")
        real_unlink(target, missing_ok=missing_ok)

    monkeypatch.setattr(Path, "unlink", busy_unlink)
    monkeypatch.setattr(_lease, "RETRY_PAUSE_SECONDS", 0)
    return path


def test_takeover_of_a_lock_in_use_asks_to_retry(tmp_path: Path, lease_in_use: Path) -> None:
    write_lease(tmp_path, pid=DEAD_PID)
    with pytest.raises(LeaseError, match="takeover in progress in another session; retry"):
        take(tmp_path, "codex", "owner", process_id=os.getpid())
    assert json.loads(lease_in_use.read_text(encoding="utf-8"))["pid"] == DEAD_PID
    guard = _lease._open_guard(lease_in_use)
    try:
        assert guard is not None
    finally:
        if guard is not None:
            _lease._close_guard(guard)


def test_release_of_a_lock_in_use_asks_to_retry(tmp_path: Path, lease_in_use: Path) -> None:
    write_lease(tmp_path)
    with pytest.raises(LeaseError, match="change in progress in another session; retry"):
        release(tmp_path, process_id=os.getpid())
    assert lease_in_use.exists()


# Release boundary races


class Contender:
    # Tries to replace the lock through the takeover guard at the release boundaries.

    def __init__(self, repo: Path) -> None:
        self.path = lease_path(repo)
        self.events: list[str] = []

    def attempt(self, boundary: str) -> None:
        handle = _lease._open_guard(self.path)
        if handle is None:
            self.events.append(f"{boundary}:blocked")
            return
        try:
            self.path.write_text('{"account":"successor","pid":99999999,"host":"fixture","startedAt":"replacement"}', encoding="utf-8")
            self.events.append(f"{boundary}:admitted")
        finally:
            _lease._close_guard(handle)


@pytest.fixture
def contender(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Contender:
    watcher = Contender(tmp_path)
    real_state, real_unlink = _lease.state, Path.unlink

    def watched_state(repo: Path) -> _lease.LeaseState:
        current = real_state(repo)
        watcher.attempt("read")
        return current

    def watched_unlink(path: Path, missing_ok: bool = False) -> None:
        if path == watcher.path:
            watcher.attempt("remove")
        real_unlink(path, missing_ok=missing_ok)

    monkeypatch.setattr(_lease, "state", watched_state)
    monkeypatch.setattr(Path, "unlink", watched_unlink)
    return watcher


def test_release_guards_its_read_and_removal(tmp_path: Path, contender: Contender) -> None:
    write_lease(tmp_path)
    assert release(tmp_path, process_id=os.getpid()) == "lease released"
    assert contender.events == ["read:blocked", "remove:blocked"]
    assert not contender.path.exists()


def test_release_retries_while_another_session_holds_the_guard(tmp_path: Path, contender: Contender) -> None:
    write_lease(tmp_path)
    held = _lease._open_guard(contender.path)
    assert held is not None
    try:
        with pytest.raises(LeaseError, match="change in progress"):
            release(tmp_path, process_id=os.getpid())
    finally:
        _lease._close_guard(held)
    assert json.loads(contender.path.read_text(encoding="utf-8"))["account"] == "owner"
    assert contender.events == []


def test_release_rejects_ownership_changed_before_its_read(tmp_path: Path, contender: Contender) -> None:
    write_lease(tmp_path, pid=DEAD_PID)
    with pytest.raises(LeaseError, match="belongs to another session"):
        release(tmp_path, process_id=os.getpid())
    assert json.loads(contender.path.read_text(encoding="utf-8"))["pid"] == DEAD_PID


# Session ownership


@pytest.mark.parametrize(
    ("tool", "thread", "expected"),
    [("codex", "fixture-thread", "fixture-thread"), ("codex", "", None), ("claude", "fixture-thread", None)],
)
def test_codex_lease_records_its_thread(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, tool: str, thread: str, expected: Optional[str]) -> None:
    monkeypatch.setenv("CODEX_THREAD_ID", thread)
    take(tmp_path, tool, "codex-a", process_id=os.getpid())
    data = json.loads(lease_path(tmp_path).read_text(encoding="utf-8"))
    assert data.get("session") == expected
    assert ("session" in data) == (expected is not None)
    current = state(tmp_path).lease
    assert current is not None
    assert current.session == expected


def test_from_json_rejects_wrong_types() -> None:
    assert Lease.from_json('{"pid": 7, "host": "h"}').pid == 7
    for text in ("[]", '{"pid": "7"}', '{"pid": true}', '{"host": 3}', '{"processStartedAt": "soon"}', "{"):
        with pytest.raises((ValueError, TypeError)):
            Lease.from_json(text)
