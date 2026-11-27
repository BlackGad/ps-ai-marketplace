# The detached shell that deletes legion's own folders after Python has exited.
import os
import subprocess
import sys
import time
from pathlib import Path

import pytest

from legion.services.installation import _handover

WINDOWS = sys.platform == "win32"


def test_the_command_text_holds_no_path(tmp_path: Path) -> None:
    folder, other = tmp_path / "one %PATH% folder", tmp_path / "two"
    other.write_text("a file", encoding="utf-8")
    folder.mkdir()
    command, variables = _handover.delete_command([folder, other])
    if WINDOWS:
        assert isinstance(command, str)
        assert variables == {"LEGION_DELETE_1": str(folder), "LEGION_DELETE_2": str(other)}
        assert str(tmp_path) not in command
        assert command.startswith(f'"{Path(os.environ["SYSTEMROOT"]) / "System32" / "cmd.exe"}" /d /v:off /s /c ')
        assert 'rmdir /s /q "%LEGION_DELETE_1%"' in command
        assert 'del /f /q "%LEGION_DELETE_2%"' in command
    else:
        assert isinstance(command, list)
        assert command[:2] == ["/bin/sh", "-c"]
        assert "kill -0" in command[2]
        assert command[3:] == ["sh", str(os.getpid()), str(folder), str(other)]
        assert variables == {}


def test_start_runs_the_command_detached_without_console_input_or_output(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    started: list[tuple[object, dict[str, object]]] = []
    monkeypatch.setattr(_handover.subprocess, "Popen", lambda command, **options: started.append((command, options)))
    _handover.start([tmp_path])
    ((command, options),) = started
    assert command == _handover.delete_command([tmp_path])[0]
    assert options["stdin"] == options["stdout"] == options["stderr"] == subprocess.DEVNULL
    environment = options["env"]
    assert isinstance(environment, dict)
    assert (environment["LEGION_DELETE_1"] == str(tmp_path)) if WINDOWS else environment["PATH"]
    assert ("creationflags" in options) if WINDOWS else options["start_new_session"] is True


def test_start_with_nothing_to_delete_starts_nothing(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_handover.subprocess, "Popen", lambda *_args, **_options: pytest.fail("a shell was started"))
    _handover.start([])


# The real shell, against a lookalike of ~/.legion that holds a link to a folder outside it.
def test_the_shell_deletes_the_folders_after_the_starting_process_exits_and_spares_the_link_target(tmp_path: Path) -> None:
    legion = tmp_path / ".legion"
    (legion / "configuration" / "nested").mkdir(parents=True)
    (legion / "configuration" / "nested" / "file.txt").write_text("legion", encoding="utf-8")
    (legion / "agents").mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "keep.txt").write_text("owner", encoding="utf-8")
    link = legion / "configuration" / "link"
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


@pytest.mark.skipif(WINDOWS, reason="POSIX shell")
def test_the_posix_shell_waits_for_the_starting_process_to_exit(tmp_path: Path) -> None:
    folder = tmp_path / "legion"
    folder.mkdir()
    code = "import sys; from pathlib import Path; from legion.services.installation import _handover; _handover.start([Path(sys.argv[1])]); sys.stdin.read()"
    parent = subprocess.Popen([sys.executable, "-c", code, str(folder)], stdin=subprocess.PIPE)
    time.sleep(2)
    assert folder.exists()
    parent.communicate(timeout=60)
    deadline = time.monotonic() + 30
    while folder.exists() and time.monotonic() < deadline:
        time.sleep(0.2)
    assert not folder.exists()


def test_the_run_command_text_holds_no_word_of_the_command_and_no_path_to_remove(tmp_path: Path) -> None:
    folder, stop = tmp_path / "constraints %PATH%", tmp_path / "stop"
    folder.mkdir()
    stop.write_text("1", encoding="utf-8")
    command = ["uv", "tool", "install", f"{tmp_path}[mcp]", "--reinstall"]
    program, variables = _handover.run_command_line(command, [folder, stop])
    assert {name: value for name, value in variables.items() if name.startswith("LEGION_REMOVE_")} == {"LEGION_REMOVE_1": str(folder), "LEGION_REMOVE_2": str(stop)}
    if WINDOWS:
        assert isinstance(program, str)
        assert variables == {**{f"LEGION_RUN_{number}": word for number, word in enumerate(command, 1)}, "LEGION_REMOVE_1": str(folder), "LEGION_REMOVE_2": str(stop)}
        assert str(tmp_path) not in program
        assert "uv" not in program.replace("LEGION_RUN", "")
        assert 'rmdir /s /q "%LEGION_REMOVE_1%"' in program
        assert 'del /f /q "%LEGION_REMOVE_2%"' in program
    else:
        assert program[:2] == ["/bin/sh", "-c"]
        assert program[3:] == ["sh", str(os.getpid()), *command]
        assert 'rm -rf -- "$LEGION_REMOVE_1" "$LEGION_REMOVE_2"' in program[2]
        assert str(tmp_path) not in program[2]


def test_start_command_runs_detached_and_without_a_folder_to_remove(monkeypatch: pytest.MonkeyPatch) -> None:
    started: list[tuple[object, dict[str, object]]] = []
    monkeypatch.setattr(_handover.subprocess, "Popen", lambda command, **options: started.append((command, options)))
    _handover.start_command(["uv", "tool", "uninstall", "legion"])
    ((command, options),) = started
    assert command == _handover.run_command_line(["uv", "tool", "uninstall", "legion"], [])[0]
    assert options["stdin"] == options["stdout"] == options["stderr"] == subprocess.DEVNULL
    assert ("creationflags" in options) if WINDOWS else options["start_new_session"] is True


# The real shell runs a script with awkward words after the starting process exits, then removes the folder and the stop file.
def test_the_shell_runs_the_command_once_the_parent_is_gone_and_removes_the_folder_and_the_stop_file(tmp_path: Path) -> None:
    folder = tmp_path / "constraints folder"
    folder.mkdir()
    (folder / "constraints.txt").write_text("mcp==1.0.0", encoding="utf-8")
    stop = tmp_path / "stop"
    stop.write_text("1", encoding="utf-8")
    script = tmp_path / "record.py"
    script.write_text("import sys\nfrom pathlib import Path\nPath(sys.argv[1]).write_text(sys.argv[2], encoding='utf-8')\n", encoding="utf-8")
    out = tmp_path / "out.txt"
    words = "legion[mcp] & 100% !x!"
    code = "import sys; from pathlib import Path; from legion.services.installation import _handover; _handover.start_command(sys.argv[1:-2], [Path(sys.argv[-2]), Path(sys.argv[-1])])"
    subprocess.run([sys.executable, "-c", code, sys.executable, str(script), str(out), words, str(folder), str(stop)], check=True, timeout=60)
    deadline = time.monotonic() + 60
    while (not out.exists() or folder.exists() or stop.exists()) and time.monotonic() < deadline:
        time.sleep(0.5)
    assert out.read_text(encoding="utf-8") == words
    assert not folder.exists()
    assert not stop.exists()


@pytest.mark.skipif(not WINDOWS, reason="only Windows retries while a file is locked")
def test_windows_retries_the_command_until_it_succeeds(tmp_path: Path) -> None:
    script = tmp_path / "flaky.py"
    lines = [
        "import sys",
        "from pathlib import Path",
        "marker = Path(sys.argv[1])",
        "if not marker.exists():",
        "    marker.write_text('first try fails', encoding='utf-8')",
        "    sys.exit(1)",
        "Path(sys.argv[2]).write_text('done', encoding='utf-8')",
    ]
    script.write_text("\n".join(lines) + "\n", encoding="utf-8")
    marker, out = tmp_path / "marker.txt", tmp_path / "out.txt"
    code = "import sys; from legion.services.installation import _handover; _handover.start_command(sys.argv[1:])"
    subprocess.run([sys.executable, "-c", code, sys.executable, str(script), str(marker), str(out)], check=True, timeout=60)
    deadline = time.monotonic() + 60
    while not out.exists() and time.monotonic() < deadline:
        time.sleep(0.5)
    assert out.read_text(encoding="utf-8") == "done"
