# Every long-lived legion process (each `legion mcp` server, each `legion run` wrapper) registers a file holding its process id
# in <home>/.legion/run/. An update or a full uninstall writes the stop file there; each registered process sees it within
# a second and exits, so uv can replace legion's files. Only the standard library and psutil are used.

import contextlib
import os
import sys
import threading
import time
from collections.abc import Callable, Iterator
from datetime import UTC, datetime
from pathlib import Path

from legion.core import _process
from legion.core._atomic_write import atomic_write_bytes
from legion.core._home import run_folder

STOP_FILE = "stop"
CHECK_SECONDS = 1.0
WAIT_SECONDS = 30.0
# A stop file this old is the leftover of an update that died; it no longer stops anything.
STOP_VALID_SECONDS = 600.0


def stop_path(home: Path) -> Path:
    return run_folder(home) / STOP_FILE


def stop_raised(home: Path, *, pid: int | None = None) -> bool:
    path = stop_path(home)
    try:
        if time.time() - path.stat().st_mtime >= STOP_VALID_SECONDS:
            return False
        return pid is None or str(pid).encode("ascii") not in path.read_bytes().split()[1:]
    except OSError:
        return False


# Registers this process until the block ends and calls `on_stop` once from a helper thread when the stop file appears.
@contextlib.contextmanager
def registered(home: Path, on_stop: Callable[[], None], *, wait_for_stop: bool = False) -> Iterator[None]:
    pid = os.getpid()
    registration = run_folder(home) / f"{pid}.pid"
    # Written whole, so a reader never sees an empty file.
    atomic_write_bytes(registration, str(os.getpid()).encode("ascii"), keep_mode=False)
    finished = threading.Event()

    def watch() -> None:
        while not finished.wait(CHECK_SECONDS):
            if stop_raised(home, pid=pid):
                on_stop()
                return

    watcher = threading.Thread(target=watch, daemon=True)
    watcher.start()
    try:
        yield
    finally:
        finished.set()
        if wait_for_stop:
            watcher.join()
        registration.unlink(missing_ok=True)


def raise_stop(home: Path, protected: set[int] | None = None) -> None:
    # Store the exclusions for the entire handover, including after the updater exits.
    contents = "\n".join(map(str, [os.getpid(), *sorted(protected or ())]))
    atomic_write_bytes(stop_path(home), contents.encode("ascii"), keep_mode=False)


def clear_stop(home: Path) -> None:
    stop_path(home).unlink(missing_ok=True)


# The process ids of registered processes still alive. The file of a dead process is removed; so is the file of a pid that
# a newer process reuses (it started after the file was written).
def running(home: Path) -> list[int]:
    alive: list[int] = []
    for registration in sorted(run_folder(home).glob("*.pid")):
        try:
            pid = int(registration.read_text(encoding="ascii"))
            written = datetime.fromtimestamp(registration.stat().st_mtime, UTC)
        except (OSError, ValueError):
            registration.unlink(missing_ok=True)
            continue
        process = _process.process_info(pid)
        if process is not None and (process.started_at <= written or _process.same_start_time(process.started_at, written)):
            alive.append(pid)
        else:
            registration.unlink(missing_ok=True)
    return alive


# Raises the stop event and waits until no registered process is alive. Returns the ones still alive after the timeout.
def stop_all(home: Path, timeout: float = WAIT_SECONDS, poll: float = 0.2) -> list[int]:
    caller = os.getpid()
    ancestors = {process.pid for process in _process.ancestors(caller)}
    protected = {caller, *ancestors}
    raise_stop(home, protected)
    deadline = time.monotonic() + timeout
    warned = False
    while True:
        registered_pids = running(home)
        if not warned and ancestors.intersection(registered_pids):
            print("Restart this session after the legion update.", file=sys.stderr, flush=True)
            warned = True
        alive = [pid for pid in registered_pids if pid not in protected]
        if not alive or time.monotonic() >= deadline:
            return alive
        time.sleep(poll)
