# The generated owner command, run by the real shell with a fake uv: arguments arrive unchanged, stdin and output
# pass through, the exit code is exact, the caller's environment stays, and a command that is deleted while it runs
# (an update rewriting it) still ends cleanly. Readiness is by blocking reads and a marker line, never by sleeping.

import os
import shutil
import subprocess
import sys
import threading
from pathlib import Path

import pytest

from legion import _app

MISSING = "uv is missing. Ask the owner before installing it, then run the legion installer again."
WINDOWS = sys.platform == "win32"
CSC = Path(os.environ.get("SYSTEMROOT", "C:\\Windows")) / "Microsoft.NET" / "Framework64" / "v4.0.30319" / "csc.exe"
UNICODE = "Привіт"

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


def child_environment(folder: Path, log: Path, code: int, delete: Path | None = None) -> dict[str, str]:
    path = f"{folder}{os.pathsep}{os.environ['SYSTEMROOT']}\\System32" if WINDOWS else f"{folder}{os.pathsep}/usr/bin:/bin"
    environment = {"PATH": path, "FAKE_UV_LOG": str(log), "FAKE_UV_EXIT": str(code), "FAKE_UV_DELETE": str(delete or ""), "UV_PROJECT_ENVIRONMENT": "caller value"}
    if WINDOWS:
        environment["SystemRoot"] = os.environ["SYSTEMROOT"]
        environment["COMSPEC"] = os.environ["COMSPEC"]
    return environment


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
    # cmd /s /c takes the line exactly as written, so the test controls every quote.
    return subprocess.run(f'cmd.exe /d /s /c "{line}"', input=(text + "\r\n").encode("utf-8"), capture_output=True, env=environment, check=False)


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
        "arg:run", "arg:--project", f"arg:{bin_folder}\\..\\app\\1.2.3", "arg:--frozen", "arg:--quiet", "arg:legion", "arg:--home", f"arg:{bin_folder}\\..\\..",
        "arg:status", "arg:two words", "arg:", "arg:100%", f"arg:{UNICODE}", f"env:{bin_folder}\\..\\python\\{_app.python_environment(app, home).name}", "stdin:typed input",
    ]  # fmt: skip
    assert log.read_text(encoding="utf-8").splitlines() == expected


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
    environment = os.environ | child_environment(fake_uv_folder, tmp_path / "uv.log", 0) | {"PATH": f"{fake_uv_folder}{os.pathsep}{os.environ['PATH']}"}
    result = subprocess.run([str(pwsh_path), "-NoProfile", "-File", str(script), str(template), str(shim)], capture_output=True, text=True, env=environment, check=True)
    assert result.stdout.splitlines() == ["0 0 live output", "3 3 live output", "300 300 live output", "-1 -1 live output"]


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_uv_output_arrives_while_uv_still_runs(tmp_path: Path, fake_uv_folder: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    environment = child_environment(fake_uv_folder, tmp_path / "uv.log", 0)
    process = subprocess.Popen(f'cmd.exe /d /s /c ""{shim}" status"', stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=environment)
    # A hung child is ended after a minute; a passing test never waits for this.
    watchdog = threading.Timer(60, process.kill)
    watchdog.start()
    try:
        assert process.stdout is not None
        assert process.stdout.readline().strip() == b"live output"
        assert process.poll() is None
        process.communicate(b"go\r\n")
        assert process.returncode == 0
    finally:
        watchdog.cancel()
        process.kill()


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_an_interactive_console_stays_open_with_uvs_code_and_its_own_environment(tmp_path: Path, fake_uv_folder: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    environment = child_environment(fake_uv_folder, tmp_path / "uv.log", 5) | {"LEGION_TEST_SHIM": str(shim)}
    # The command reads nul, so the fake uv cannot take the console's next lines.
    text = '"%LEGION_TEST_SHIM%" status <nul\r\necho after %errorlevel% %UV_PROJECT_ENVIRONMENT%\r\nexit'
    result = cmd("cmd /d /q /k", environment, text)
    assert b"after 5 caller value" in result.stdout


@pytest.mark.skipif(not WINDOWS, reason="the batch command is Windows only")
def test_without_uv_the_batch_command_prints_one_line_and_exits_127(tmp_path: Path) -> None:
    _, _, shim = home_with_shim(tmp_path, "legion.cmd", True)
    environment = {"PATH": f"{os.environ['SYSTEMROOT']}\\System32", "SystemRoot": os.environ["SYSTEMROOT"], "COMSPEC": os.environ["COMSPEC"]}
    result = cmd(f'"{shim}" status', environment)
    assert result.returncode == 127
    assert result.stderr.decode() == f"{MISSING}\r\n"


def git_bash() -> Path | None:
    git = shutil.which("git")
    if not git:
        return None
    candidates = [Path(git).parent / ".." / "bin" / "bash.exe", Path(git).parent / ".." / ".." / "bin" / "bash.exe"]
    return next((path.resolve() for path in candidates if path.is_file()), None)


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
    result = subprocess.run(["/usr/bin/env", "PATH=/nonexistent", "/bin/sh", str(shim), "status"], capture_output=True, text=True, check=False)
    assert result.returncode == 127
    assert result.stderr.strip() == MISSING
