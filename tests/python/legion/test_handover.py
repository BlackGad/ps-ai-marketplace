# The detached shell that deletes legion's own folders after Python has exited.
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

from legion.services.installation import _handover

WINDOWS = sys.platform == "win32"


def test_the_command_names_every_folder(tmp_path: Path) -> None:
    first, second = tmp_path / "one folder", tmp_path / "two"
    command = _handover.delete_command([first, second])
    if WINDOWS:
        assert isinstance(command, str)
        assert command.startswith("cmd /d /s /c ")
        assert f'rmdir /s /q "{first}"' in command
        assert f'rmdir /s /q "{second}"' in command
    else:
        assert command == ["sh", "-c", 'sleep 1; rm -rf -- "$@"', "sh", str(first), str(second)]


def test_start_runs_the_command_detached_without_console_input_or_output(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    started: list[tuple[object, dict[str, object]]] = []
    monkeypatch.setattr(_handover.subprocess, "Popen", lambda command, **options: started.append((command, options)))
    _handover.start([tmp_path])
    ((command, options),) = started
    assert command == _handover.delete_command([tmp_path])
    assert options["stdin"] == options["stdout"] == options["stderr"] == subprocess.DEVNULL
    assert ("creationflags" in options) if WINDOWS else options["start_new_session"] is True


def test_start_with_nothing_to_delete_starts_nothing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_handover.subprocess, "Popen", lambda *_args, **_options: pytest.fail("a shell was started"))
    _handover.start([])


# The real shell, against a lookalike of ~/.legion that holds a link to a folder outside it.
def test_the_shell_deletes_the_folders_after_the_starting_process_exits_and_spares_the_link_target(tmp_path: Path) -> None:
    legion = tmp_path / ".legion"
    (legion / "app" / "nested").mkdir(parents=True)
    (legion / "app" / "nested" / "file.txt").write_text("legion", encoding="utf-8")
    (legion / "bin").mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "keep.txt").write_text("owner", encoding="utf-8")
    link = legion / "app" / "link"
    if WINDOWS:
        if subprocess.run([os.environ["COMSPEC"], "/c", "mklink", "/J", str(link), str(outside)], capture_output=True, check=False).returncode != 0:
            pytest.skip("junctions are not available here")
    else:
        link.symlink_to(outside, target_is_directory=True)
    code = "import sys; from pathlib import Path; from legion.services.installation import _handover; _handover.start([Path(sys.argv[1])])"
    subprocess.run([sys.executable, "-c", code, str(legion)], check=True, timeout=60)
    deadline = time.monotonic() + 60
    while os.path.lexists(legion) and time.monotonic() < deadline:
        time.sleep(0.5)
    assert not os.path.lexists(legion)
    assert (outside / "keep.txt").read_text(encoding="utf-8") == "owner"
