# Runs the literal session-start commands from both hook manifests in the shells that run them.
import json
import os
import shutil
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

import pytest

PLUGIN = Path(__file__).resolve().parents[3] / "plugins" / "legion"
FALLBACK = "legion: uv or Python 3.12 is missing, so mode detection did not run; run the legion installer. If LEGION_ROLE=member is set, load the legion-member skill."
MEMBER = "legion: you are a legion member. Load the legion-member skill"
CASES = ["ok", "uv missing", "no python"]


def manifest_commands() -> dict[str, str]:
    shared = json.loads((PLUGIN / "hooks" / "hooks.json").read_text(encoding="utf-8"))["hooks"]["SessionStart"][0]["hooks"][0]
    copilot = json.loads((PLUGIN / "hooks" / "copilot-hooks.json").read_text(encoding="utf-8"))["hooks"]["sessionStart"][0]
    return {"command": shared["command"], "commandWindows": shared["commandWindows"], "bash": copilot["bash"], "powershell": copilot["powershell"]}


COMMANDS = manifest_commands()


def uv_path() -> Path:
    found = os.environ.get("UV") or shutil.which("uv")
    assert found, "uv must be on PATH or named by UV"
    return Path(found)


# Claude Code runs hooks in Git Bash on Windows; never pick the WSL bash from System32.
def posix_shells() -> dict[str, Path]:
    if sys.platform != "win32":
        shells = {"bash": shutil.which("bash"), "sh": "/bin/sh"}
        return {name: Path(path) for name, path in shells.items() if path}
    git = shutil.which("git")
    assert git, "Git for Windows provides the hook shell"
    for folder in Path(git).resolve().parents:
        if (folder / "bin" / "bash.exe").exists():
            return {"bash": folder / "bin" / "bash.exe", "sh": folder / "usr" / "bin" / "sh.exe"}
    raise AssertionError("Git Bash not found")


def powershells() -> dict[str, Path]:
    shells = {"pwsh": shutil.which("pwsh"), "powershell 5.1": shutil.which("powershell")}
    return {name: Path(path) for name, path in shells.items() if path}


def without(path: str, *names: str) -> str:
    def has(folder: str) -> bool:
        return any((Path(folder) / name).is_file() for name in names)

    return os.pathsep.join(folder for folder in path.split(os.pathsep) if folder and not has(folder))


@pytest.fixture
def plugin(tmp_path: Path) -> Path:
    root = tmp_path / "plugin O'Brien x"
    shutil.copytree(PLUGIN / "hooks", root / "hooks", ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copytree(PLUGIN / "src" / "legion", root / "src" / "legion", ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copy2(PLUGIN / "plugin.json", root / "plugin.json")
    return root


def run(shell: Path, flag: str, command: str, plugin_root: str, case: str, *, root_name: str, folder: Path, member: bool) -> subprocess.CompletedProcess[str]:
    env = {key: value for key, value in os.environ.items() if not key.startswith(("LEGION_", "UV_PYTHON"))}
    env[root_name] = plugin_root
    if member:
        env.update(LEGION_ROLE="member", LEGION_TASK="task.md")
    uv = uv_path()
    # A POSIX hook must work on machines without PowerShell.
    path = without(env["PATH"], "pwsh", "pwsh.exe") if flag == "-c" else env["PATH"]
    path = without(path, "uv", "uv.exe")
    if case != "uv missing":
        path = str(uv.parent) + os.pathsep + path
    if case == "no python":
        empty = folder / "no-managed-python"
        empty.mkdir(exist_ok=True)
        env.update(UV_PYTHON_PREFERENCE="only-managed", UV_PYTHON_INSTALL_DIR=str(empty))
        env.pop("VIRTUAL_ENV", None)
    env["PATH"] = path
    args = [str(shell), "-NoProfile", "-Command", command] if flag == "-Command" else [str(shell), "-c", command]
    stdin = json.dumps({"cwd": str(folder), "hook_event_name": "SessionStart"})
    return subprocess.run(args, input=stdin, capture_output=True, text=True, cwd=folder, env=env, timeout=60, check=False)  # noqa: S603


def check(result: subprocess.CompletedProcess[str], case: str, *, copilot: bool, member: bool) -> None:
    assert result.returncode == 0, result.stderr
    lines = result.stdout.splitlines()
    if case != "ok":
        assert lines == [json.dumps({"additionalContext": FALLBACK}, separators=(",", ":")) if copilot else FALLBACK]
        assert result.stderr != ""  # the shell or uv says what is missing; hosts do not show it in context
        return
    assert result.stderr == ""
    if not member:
        assert lines == (["{}"] if copilot else [])
        return
    assert len(lines) == 1
    assert (json.loads(lines[0])["additionalContext"] if copilot else lines[0]).startswith(MEMBER)


@pytest.mark.parametrize("case", CASES)
@pytest.mark.parametrize("key", ["command", "bash"])
@pytest.mark.parametrize("shell", sorted(posix_shells()))
def test_posix_hook_command(plugin: Path, tmp_path: Path, shell: str, key: str, case: str) -> None:
    root_name = "CLAUDE_PLUGIN_ROOT" if key == "command" else "COPILOT_PLUGIN_ROOT"
    for member in (True, False):
        result = run(posix_shells()[shell], "-c", COMMANDS[key], plugin.as_posix(), case, root_name=root_name, folder=tmp_path, member=member)
        check(result, case, copilot=key == "bash", member=member)


@pytest.mark.skipif(sys.platform != "win32", reason="Windows only: Codex and Copilot run these keys in PowerShell")
@pytest.mark.parametrize("case", CASES)
@pytest.mark.parametrize("key", ["commandWindows", "powershell"])
@pytest.mark.parametrize("shell", sorted(powershells()))
def test_windows_hook_command(plugin: Path, tmp_path: Path, shell: str, key: str, case: str) -> None:
    root_name = "CLAUDE_PLUGIN_ROOT" if key == "commandWindows" else "COPILOT_PLUGIN_ROOT"
    for member in (True, False):
        result = run(powershells()[shell], "-Command", COMMANDS[key], str(plugin), case, root_name=root_name, folder=tmp_path, member=member)
        check(result, case, copilot=key == "powershell", member=member)


def test_cached_run_imports_only_the_standard_library(plugin: Path, tmp_path: Path) -> None:
    repo = tmp_path / "repo"
    (repo / ".legion" / "state").mkdir(parents=True)
    (repo / ".legion" / "state" / "handoff.md").write_text("## Goal\nM1\n", encoding="utf-8")
    home = tmp_path / "home"
    cache = home / ".legion" / "temp" / "update.json"
    cache.parent.mkdir(parents=True)
    record = {"Source": "BlackGad/ps-legion-marketplace", "CheckedAt": datetime.now(UTC).isoformat(), "Available": "999.0.0", "Failed": False}
    cache.write_text(json.dumps(record), encoding="utf-8")
    script = """
import runpy, sys
hook = sys.argv[1]
sys.argv = [hook, "--format", "text"]
try:
    runpy.run_path(hook, run_name="__main__")
except SystemExit:
    pass
# pathlib itself imports urllib.parse; the slow part is urllib.request and its HTTP stack.
loaded = sorted(name for name in sys.modules if name.split(".")[0] in ("pydantic", "click") or name in ("urllib.request", "http.client", "ssl"))
sys.stderr.write(",".join(loaded))
"""
    env = {key: value for key, value in os.environ.items() if not key.startswith("LEGION_")}
    env.update(HOME=str(home), USERPROFILE=str(home))
    stdin = json.dumps({"cwd": str(repo)})
    result = subprocess.run([sys.executable, "-c", script, str(plugin / "hooks" / "session_start.py")], input=stdin, capture_output=True, text=True, env=env, check=False)  # noqa: S603
    assert result.returncode == 0
    assert result.stderr == ""
    assert result.stdout.splitlines()[1].startswith("legion 999.0.0 is available")
