# The generated owner command, run by the real shell with a fake uv: arguments arrive unchanged, stdin and output
# pass through, the exit code is exact, the caller's environment stays, and a command that is deleted while it runs
# (an update rewriting it) still ends cleanly. Readiness is by blocking reads and a marker line, never by sleeping.

import json
import os
import queue
import shutil
import subprocess
import sys
import threading
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest

from legion.services import _app

from conftest import REPO

MISSING = "uv is missing. Ask the owner before installing it, then run the legion installer again."
WINDOWS = sys.platform == "win32"
CSC = Path(os.environ.get("SYSTEMROOT", "C:\\Windows")) / "Microsoft.NET" / "Framework64" / "v4.0.30319" / "csc.exe"
UNICODE = "Привіт"
COMSPEC = os.environ.get("COMSPEC", "")
TASKKILL = Path(os.environ.get("SYSTEMROOT", "C:\\Windows")) / "System32" / "taskkill.exe"


def bounded_read(read: Callable[[], bytes], timeout: float) -> bytes:
    result: queue.Queue[bytes | BaseException] = queue.Queue(maxsize=1)

    def worker() -> None:
        try:
            result.put(read())
        except BaseException as error:
            result.put(error)

    threading.Thread(target=worker, daemon=True).start()
    try:
        value = result.get(timeout=timeout)
    except queue.Empty as error:
        raise TimeoutError("command output did not close") from error
    if isinstance(value, BaseException):
        raise value
    return value


def test_bounded_read_times_out_and_can_release_its_reader() -> None:
    released = threading.Event()

    def blocked_read() -> bytes:
        released.wait()
        return b""

    try:
        with pytest.raises(TimeoutError):
            bounded_read(blocked_read, 0)
    finally:
        released.set()


# A real executable: a batch fake would never return to the command's (goto) tail. It writes its output first,
# then blocks reading one line of stdin, so a test can see the output arrive while uv still runs.
FAKE_UV_SOURCE = """
using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
class FakeUv {
    static int Main(string[] args) {
        var lines = new List<string>();
        foreach (var arg in args) { lines.Add("arg:" + arg); }
        lines.Add("env:" + Environment.GetEnvironmentVariable("UV_PROJECT_ENVIRONMENT"));
        Console.Out.WriteLine("live output");
        Console.Out.Flush();
        if (Environment.GetEnvironmentVariable("FAKE_UV_NO_STDIN") != "1") { lines.Add("stdin:" + Console.In.ReadLine()); }
        File.WriteAllLines(Environment.GetEnvironmentVariable("FAKE_UV_LOG"), lines.ToArray(), new UTF8Encoding(false));
        string delete = Environment.GetEnvironmentVariable("FAKE_UV_DELETE");
        if (!string.IsNullOrEmpty(delete)) { File.Delete(delete); }
        return int.Parse(Environment.GetEnvironmentVariable("FAKE_UV_EXIT"));
    }
}
"""

FAKE_UV_SH = '#!/bin/sh\n{ for a in "$@"; do echo "arg:$a"; done; echo "env:$UV_PROJECT_ENVIRONMENT"; } > "$FAKE_UV_LOG"\necho "live output"\nexit "$FAKE_UV_EXIT"\n'


@pytest.fixture(scope="module")
def fake_uv_folder(tmp_path_factory: pytest.TempPathFactory) -> Path:
    folder = tmp_path_factory.mktemp("fake-uv")
    if WINDOWS:
        if not CSC.is_file():
            pytest.skip("the .NET Framework compiler is missing")
        source = folder / "fake-uv.cs"
        source.write_text(FAKE_UV_SOURCE, encoding="utf-8")
        subprocess.run([str(CSC), "/nologo", "/target:exe", f"/out:{folder / 'uv.exe'}", str(source)], check=True, capture_output=True)
    else:
        uv = folder / "uv"
        uv.write_text(FAKE_UV_SH, encoding="utf-8")
        uv.chmod(0o755)
    return folder


def child_environment(folder: Path, log: Path, code: int, delete: Path | None = None, tools: tuple[Path, ...] = ()) -> dict[str, str]:
    # The fenced environment stays (home, temp, proxies); only PATH is an allowlist: the fake uv, the folders of
    # the tools a test names and, on Windows, System32 for cmd. The host PATH never reaches a child.
    system = [str(Path(os.environ["SYSTEMROOT"]) / "System32")] if WINDOWS else []
    path = os.pathsep.join([str(folder), *map(str, tools), *system])
    return {**os.environ, "PATH": path, "FAKE_UV_LOG": str(log), "FAKE_UV_EXIT": str(code), "FAKE_UV_DELETE": str(delete or ""), "UV_PROJECT_ENVIRONMENT": "caller value"}


def home_with_shim(root: Path, name: str, windows: bool) -> tuple[Path, Path, Path]:
    # A home name outside the console code page, as an accented or Cyrillic user name gives, and a percent sign.
    home = root / "Zoë Пользователь 100%"
    app = home / ".legion" / "app" / "1.2.3"
    bin_folder = home / ".legion" / "bin"
    bin_folder.mkdir(parents=True)
    shim = bin_folder / name
    shim.write_bytes(_app.shim_text(app, home, windows).encode("utf-8"))
    shim.chmod(0o755)
    return home, app, shim


def cmd(line: str, environment: dict[str, str], text: str = "") -> subprocess.CompletedProcess[bytes]:
    # cmd /s /c takes the line exactly as written, so the test controls every quote; the shell is named, not searched.
    return subprocess.run(f'"{COMSPEC}" /d /s /c "{line}"', input=(text + "\r\n").encode("utf-8"), capture_output=True, env=environment, check=False)


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
@pytest.mark.parametrize("code", [0, 3])
def test_a_batch_command_deleted_while_it_runs_exits_with_uvs_status(tmp_path: Path, fake_uv_folder: Path, code: int) -> None:
    home, app, shim = home_with_shim(tmp_path, "legion.cmd", True)
    log = tmp_path / "uv.log"
    result = cmd(f'"{shim}" status "two words" "" 100% {UNICODE}', child_environment(fake_uv_folder, log, code, delete=shim), "typed input")
    bin_folder = shim.parent
    assert result.returncode == code
    assert not shim.exists()
    assert b"cannot find" not in result.stdout + result.stderr
    assert result.stdout == b"live output\r\n"
    expected = [
        "arg:run",
        "arg:--project",
        f"arg:{bin_folder}\\..\\app\\1.2.3",
        "arg:--frozen",
        "arg:--quiet",
        "arg:legion",
        "arg:--home",
        f"arg:{bin_folder}\\..\\..",
        "arg:status",
        "arg:two words",
        "arg:",
        "arg:100%",
        f"arg:{UNICODE}",
        f"env:{bin_folder}\\..\\python\\{_app.python_environment(app, home).name}",
        "stdin:typed input",
    ]
    assert log.read_text(encoding="utf-8").splitlines() == expected


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
@pytest.mark.parametrize("code", [0, 3])
def test_uninstall_deletes_its_batch_command_and_returns_uvs_status(tmp_path: Path, fake_uv_folder: Path, code: int) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    log = tmp_path / "uv.log"
    result = cmd(f'"{shim}" uninstall --yes', child_environment(fake_uv_folder, log, code, delete=shim))
    assert result.returncode == code
    assert not shim.exists()
    assert b"batch file cannot be found" not in (result.stdout + result.stderr).lower()
    assert "_self_uninstall.py" in log.read_text(encoding="utf-8")


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
@pytest.mark.parametrize("code", [0, 3])
def test_uninstall_runs_a_temp_copy_when_uv_is_in_legion_home(tmp_path: Path, fake_uv_folder: Path, code: int) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    installed_uv = shim.parent / "uv.exe"
    shutil.copy2(fake_uv_folder / "uv.exe", installed_uv)
    temp = tmp_path / "temp with spaces"
    temp.mkdir()
    log = tmp_path / "uv.log"
    environment = child_environment(shim.parent, log, code, delete=installed_uv) | {"TEMP": str(temp), "TMP": str(temp), "FAKE_UV_NO_STDIN": "1", "LEGION_UV_COPY": "caller value"}
    result = cmd(f'"{shim}" uninstall --purge --yes', environment)
    assert result.returncode == code, result.stdout + result.stderr
    assert not installed_uv.exists()
    assert "_self_uninstall.py" in log.read_text(encoding="utf-8")
    assert list(temp.iterdir()) == []


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
@pytest.mark.parametrize("code", [0, 3])
@pytest.mark.parametrize("prior_copy", [None, "caller value"])
def test_uninstall_preserves_the_calling_cmd_environment(tmp_path: Path, fake_uv_folder: Path, code: int, prior_copy: str | None) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    temp = tmp_path / "temp with spaces"
    temp.mkdir()
    environment = child_environment(fake_uv_folder, tmp_path / "uv.log", code) | {
        "TEMP": str(temp),
        "TMP": str(temp),
        "FAKE_UV_NO_STDIN": "1",
        "ERRORLEVEL": "9",
        "LEGION_TEST_SHIM": str(shim),
    }
    if prior_copy is None:
        environment.pop("LEGION_UV_COPY", None)
    else:
        environment["LEGION_UV_COPY"] = prior_copy
    script = '"%LEGION_TEST_SHIM%" uninstall --yes <nul\r\necho after %errorlevel% copy=[%LEGION_UV_COPY%] project=[%UV_PROJECT_ENVIRONMENT%]\r\nexit'
    result = cmd("cmd /d /q /k", environment, script)
    observed_copy = prior_copy if prior_copy is not None else "%LEGION_UV_COPY%"
    assert f"after 9 copy=[{observed_copy}] project=[caller value]".encode() in result.stdout
    assert result.returncode == code
    assert (tmp_path / "uv.log").is_file()
    assert list(temp.iterdir()) == []


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_concurrent_uninstalls_use_separate_temporary_uv_copies(tmp_path: Path, fake_uv_folder: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    temp = tmp_path / "temp with spaces"
    temp.mkdir()
    processes: list[subprocess.Popen[bytes]] = []
    logs = [tmp_path / f"uv-{index}.log" for index in range(2)]
    for log in logs:
        environment = child_environment(fake_uv_folder, log, 0) | {"TEMP": str(temp), "TMP": str(temp), "FAKE_UV_NO_STDIN": "1"}
        processes.append(subprocess.Popen(f'"{COMSPEC}" /d /s /c ""{shim}" uninstall --yes"', stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=environment))
    for process in processes:
        output, error = process.communicate(timeout=10)
        assert process.returncode == 0, output + error
    assert all(log.is_file() for log in logs)
    copies = [log.read_text(encoding="utf-8").split("arg:--uv-copy\narg:", 1)[1].splitlines()[0] for log in logs]
    assert copies[0] != copies[1]
    assert list(temp.iterdir()) == []


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_uninstall_reports_an_unusable_temp_folder(tmp_path: Path, fake_uv_folder: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    temp = tmp_path / "not a directory"
    temp.write_text("foreign file", encoding="utf-8")
    log = tmp_path / "uv.log"
    environment = child_environment(fake_uv_folder, log, 0) | {"TEMP": str(temp), "TMP": str(temp)}
    result = cmd(f'"{shim}" uninstall --yes', environment)
    assert result.returncode == 1, (result.stdout, result.stderr)
    assert b"Cannot create temporary uv folder" in result.stderr
    assert not log.exists()
    assert temp.read_text(encoding="utf-8") == "foreign file"


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
@pytest.mark.parametrize("code", [0, 3])
def test_a_caller_with_its_own_errorlevel_variable_still_gets_uvs_exit_code(tmp_path: Path, fake_uv_folder: Path, code: int) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    environment = child_environment(fake_uv_folder, tmp_path / "uv.log", code) | {"ERRORLEVEL": "9"}
    assert cmd(f'"{shim}" status', environment).returncode == code


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_powershell_sees_uvs_exact_code_also_after_the_command_is_deleted(tmp_path: Path, fake_uv_folder: Path, pwsh_path: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    template = tmp_path / "template.cmd"
    shutil.copy(shim, template)
    script = tmp_path / "run.ps1"
    script.write_text(
        'param($template, $shim)\nforeach ($code in 0, 3, 300, -1) {\n    Copy-Item $template $shim\n    $env:FAKE_UV_EXIT = "$code"\n    $env:FAKE_UV_DELETE = $shim\n'
        "    $output = @('' | & $shim status 2>&1)\n    \"$code $LASTEXITCODE $($output -join '|')\"\n}\n",
        encoding="utf-8",
    )
    environment = child_environment(fake_uv_folder, tmp_path / "uv.log", 0, tools=(pwsh_path.parent,))
    result = subprocess.run([str(pwsh_path), "-NoProfile", "-File", str(script), str(template), str(shim)], capture_output=True, text=True, env=environment, check=True)
    assert result.stdout.splitlines() == ["0 0 live output", "3 3 live output", "300 300 live output", "-1 -1 live output"]


def kill_tree(process: subprocess.Popen[bytes]) -> None:
    # cmd.exe starts uv as a child: ending cmd alone leaves uv holding the pipes, so the whole tree goes, then is reaped.
    subprocess.run([str(TASKKILL), "/PID", str(process.pid), "/T", "/F"], capture_output=True, check=False, timeout=10)
    if process.poll() is None:
        process.kill()
    process.wait(timeout=10)


def start_batch_command(shim: Path, environment: dict[str, str]) -> subprocess.Popen[bytes]:
    return subprocess.Popen(f'"{COMSPEC}" /d /s /c ""{shim}" status"', stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=environment)


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_uv_output_arrives_while_uv_still_runs(tmp_path: Path, fake_uv_folder: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    process = start_batch_command(shim, child_environment(fake_uv_folder, tmp_path / "uv.log", 0))
    try:
        assert process.stdout is not None
        assert bounded_read(process.stdout.readline, 10).strip() == b"live output"
        assert process.poll() is None
        process.communicate(b"go\r\n", timeout=10)
        assert process.returncode == 0
    finally:
        kill_tree(process)


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_ending_a_stuck_command_ends_the_fake_uv_and_closes_its_output(tmp_path: Path, fake_uv_folder: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    process = start_batch_command(shim, child_environment(fake_uv_folder, tmp_path / "uv.log", 0))
    try:
        assert process.stdout is not None
        assert bounded_read(process.stdout.readline, 10).strip() == b"live output"
        kill_tree(process)
        # The read ends only when no process of the tree still holds the pipe; a stuck uv would block here.
        assert bounded_read(process.stdout.read, 10) == b""
    finally:
        kill_tree(process)
        if process.stdout is not None:
            process.stdout.close()


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_an_interactive_console_stays_open_with_uvs_code_and_its_own_environment(tmp_path: Path, fake_uv_folder: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    environment = child_environment(fake_uv_folder, tmp_path / "uv.log", 5) | {"LEGION_TEST_SHIM": str(shim)}
    # The command reads nul, so the fake uv cannot take the console's next lines.
    text = '"%LEGION_TEST_SHIM%" status <nul\r\necho after %errorlevel% %UV_PROJECT_ENVIRONMENT%\r\nexit'
    result = cmd("cmd /d /q /k", environment, text)
    assert b"after 5 caller value" in result.stdout


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_without_uv_the_batch_command_prints_one_line_and_exits_127(tmp_path: Path, fence: Any) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    environment = child_environment(tmp_path / "empty", tmp_path / "uv.log", 0)
    assert environment["HOME"] == str(fence.home)
    assert environment["TEMP"] == str(fence.temp)
    assert environment["HTTPS_PROXY"] == os.environ["HTTPS_PROXY"]
    result = cmd(f'"{shim}" status', environment)
    assert result.returncode == 127
    assert result.stderr.decode() == f"{MISSING}\r\n"


def git_bash() -> Path | None:
    # Named from the install folders, not searched on PATH, so a lookup regression cannot reach a tool by accident.
    roots = [os.environ.get(name) for name in ("ProgramFiles", "ProgramW6432", "ProgramFiles(x86)")]
    return next((path for path in (Path(root) / "Git" / "bin" / "bash.exe" for root in roots if root) if path.is_file()), None)


@pytest.mark.skipif(not WINDOWS, reason="Git Bash purge is Windows only")
@pytest.mark.parametrize("code", [0, 3])
def test_git_bash_uninstall_uses_a_temp_uv_outside_legion_home(tmp_path: Path, fake_uv_folder: Path, code: int) -> None:
    bash = git_bash()
    if bash is None:
        pytest.skip("Git Bash was not found")
    home, _, shim = home_with_shim(tmp_path, "legion", False)
    batch = shim.with_name("legion.cmd")
    batch.write_bytes(_app.shim_text(home / ".legion/app/1.2.3", home, True).encode("utf-8"))
    installed_uv = shim.parent / "uv.exe"
    shutil.copy2(fake_uv_folder / "uv.exe", installed_uv)
    temp = tmp_path / "temp with spaces"
    temp.mkdir()
    log = tmp_path / "uv.log"
    environment = child_environment(shim.parent, log, code, delete=installed_uv) | {
        "TEMP": str(temp),
        "TMP": str(temp),
        "FAKE_UV_NO_STDIN": "1",
        "LEGION_UV_COPY": "caller value",
        "ERRORLEVEL": "9",
    }
    script = f'PATH="$(cygpath -u "{shim.parent}"):$PATH"; "$(cygpath -u "{shim}")" uninstall --purge --yes'
    result = subprocess.run([str(bash), "-c", script], capture_output=True, stdin=subprocess.DEVNULL, env=environment, check=False)
    assert result.returncode == code, result.stdout + result.stderr
    assert not installed_uv.exists()
    assert "_self_uninstall.py" in log.read_text(encoding="utf-8")
    assert list(temp.iterdir()) == []


@pytest.mark.parametrize("code", [0, 3])
def test_the_shell_command_runs_uv_and_passes_the_status_on(tmp_path: Path, fake_uv_folder: Path, code: int) -> None:
    bash = git_bash() if WINDOWS else Path("/bin/sh")
    if bash is None:
        pytest.skip("Git Bash was not found")
    home, app, shim = home_with_shim(tmp_path, "legion", False)
    log = tmp_path / "uv.log"
    # Under Git Bash the child's stdin is not a plain null device, so the fake must not wait on it.
    environment = child_environment(fake_uv_folder, log, code) | {"FAKE_UV_NO_STDIN": "1"}
    if WINDOWS:
        # Git Bash takes POSIX paths; cygpath converts them before the command runs.
        script = f'PATH="$(cygpath -u "{fake_uv_folder}"):$PATH"; "$(cygpath -u "{shim}")" status "two words"'
        result = subprocess.run([str(bash), "-c", script], capture_output=True, stdin=subprocess.DEVNULL, env=environment, check=False)
    else:
        result = subprocess.run([str(bash), str(shim), "status", "two words"], capture_output=True, stdin=subprocess.DEVNULL, env=environment, check=False)
    assert result.returncode == code
    assert result.stdout.decode().strip() == "live output"
    lines = [line for line in log.read_text(encoding="utf-8").splitlines() if not line.startswith("stdin:")]
    expected = ["arg:run", "arg:--project", f"arg:{app}", "arg:--frozen", "arg:--quiet", "arg:legion", "arg:--home", f"arg:{home}", "arg:status", "arg:two words"]
    assert lines == [*expected, f"env:{_app.python_environment(app, home)}"]


@pytest.mark.skipif(WINDOWS, reason="the shell command's uv lookup is proven by Git Bash on Windows through the same text")
def test_without_uv_the_shell_command_prints_one_line_and_exits_127(tmp_path: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion", False)
    result = subprocess.run(["/bin/sh", str(shim), "status"], capture_output=True, text=True, env={**os.environ, "PATH": "/nonexistent"}, check=False)
    assert result.returncode == 127
    assert result.stderr.strip() == MISSING


def test_public_command_preserves_failed_overseer_launch_exit(tmp_path: Path, pwsh_path: Path) -> None:
    home = tmp_path / "home"
    app = home / ".legion" / "app" / "9.9.9"
    shutil.copytree(REPO / "plugins" / "legion", app)
    repo = tmp_path / "repo"
    repo.mkdir()
    git = shutil.which("git")
    assert git is not None
    subprocess.run([git, "init", "--quiet", str(repo)], check=True)
    settings = home / ".legion" / "configuration"
    settings.mkdir(parents=True)
    (repo / ".legion" / "configuration").mkdir(parents=True)
    (settings / "personalisation.json").write_text(json.dumps({"schemaVersion": 1, "agents": [{"id": "codex-a", "tool": "codex", "configDir": "~/.codex"}], "channels": []}), encoding="utf-8")
    (repo / ".legion" / "configuration" / "project.json").write_text('{"schemaVersion":1}', encoding="utf-8")
    overseer = app / "src" / "legion" / "services" / "_overseer.py"
    source = overseer.read_text(encoding="utf-8")
    # The fixture changes only the installed copy's launch, so the public command still crosses both real entry points.
    source = source.replace("    process = start_bridge(launch, repo)", "    return 5\n    process = start_bridge(launch, repo)")
    overseer.write_text(source, encoding="utf-8")
    assert "    return 5\n    process = start_bridge" in overseer.read_text(encoding="utf-8")

    bin_folder = home / ".legion" / "bin"
    bin_folder.mkdir(parents=True)
    shim = bin_folder / ("legion.cmd" if WINDOWS else "legion")
    shim.write_bytes(_app.shim_text(app, home, WINDOWS).encode("utf-8"))
    shim.chmod(0o755)
    uv_folder = tmp_path / "fake-uv"
    uv_folder.mkdir()
    fake = REPO / "tests" / "fixtures" / "fake-tools" / "uv-python.ps1"
    # This stub supplies uv's command boundary while the fixture script invokes the project Python and production CLI.
    if WINDOWS:
        (uv_folder / "uv.cmd").write_text(f'@"{pwsh_path}" -NoProfile -File "{fake}" %*\r\n', encoding="utf-8", newline="")
    else:
        uv = uv_folder / "uv"
        uv.write_text(f'#!/bin/sh\nexec "{pwsh_path}" -NoProfile -File "{fake}" "$@"\n', encoding="utf-8")
        uv.chmod(0o755)
    folders = [uv_folder, pwsh_path.parent, Path(git).parent]
    if WINDOWS:
        folders.append(Path(os.environ["SYSTEMROOT"]) / "System32")
    else:
        folders.append(Path("/usr/bin"))
    environment = {**os.environ, "PATH": os.pathsep.join(map(str, folders)), "LEGION_TEST_PYTHON": sys.executable}
    result = subprocess.run([str(shim), "--no-channel"], cwd=repo, env=environment, capture_output=True, text=True, check=False)
    assert result.returncode == 5, result.stdout + result.stderr
    assert not any(line.startswith("launched ") for line in result.stdout.splitlines())
