import subprocess
import time
from pathlib import Path
from typing import Optional

import pytest


# Start the timeout being tested only after the child publishes readiness. A separate watchdog
# still raises TimeoutExpired so run_command kills the tree if startup gets stuck.
def timeout_after_ready(monkeypatch: pytest.MonkeyPatch, marker: Path) -> list[float]:
    communicate = subprocess.Popen.communicate
    ready: list[float] = []
    startup_checked = False

    def wait(process: subprocess.Popen[bytes], input: Optional[bytes] = None, timeout: Optional[float] = None) -> tuple[bytes, bytes]:
        nonlocal startup_checked
        if not startup_checked:
            startup_checked = True
            deadline = time.monotonic() + 60
            while not marker.is_file():
                if time.monotonic() >= deadline:
                    raise subprocess.TimeoutExpired(process.args, 60)
                time.sleep(0.01)
            ready.append(time.monotonic())
        return communicate(process, input=input, timeout=timeout)

    monkeypatch.setattr(subprocess.Popen, "communicate", wait)
    return ready
