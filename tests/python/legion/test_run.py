import sys
import time
from pathlib import Path

import pytest

from legion._process import process_started_at
from legion._run import run_command

PYTHON = sys.executable

# The child starts a grandchild that records its pid, then both sleep far past the timeout.
TREE = """
import subprocess, sys, time
from pathlib import Path
code = "import os, sys, time; from pathlib import Path; Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(60)"
subprocess.Popen([sys.executable, "-c", code, sys.argv[1]])
deadline = time.monotonic() + 20
while not Path(sys.argv[1]).is_file() and time.monotonic() < deadline:
    time.sleep(0.05)
print("tree started", flush=True)
time.sleep(60)
"""


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


def test_timeout_kills_the_whole_tree(tmp_path: Path) -> None:
    marker = tmp_path / "grandchild.pid"
    started = time.monotonic()
    result = run_command(PYTHON, ["-c", TREE, str(marker)], timeout=3)
    assert time.monotonic() - started < 30
    assert (result.exit_code, result.timed_out) == (-1, True)
    assert "tree started" in result.output
    grandchild = int(marker.read_text(encoding="utf-8"))
    deadline = time.monotonic() + 10
    while process_started_at(grandchild) is not None and time.monotonic() < deadline:
        time.sleep(0.1)
    assert process_started_at(grandchild) is None


@pytest.mark.skipif(sys.platform != "win32", reason="cmd wrappers exist only on Windows")
def test_cmd_wrapper_runs_through_cmd(tmp_path: Path) -> None:
    wrapper = tmp_path / "my tool.cmd"
    wrapper.write_text("@echo off\r\necho [%~1] [%~2]\r\nexit /b 3\r\n", encoding="utf-8")
    result = run_command(str(wrapper), ["two words", "x"], timeout=30)
    assert result.exit_code == 3
    assert result.output.strip() == "[two words] [x]"
