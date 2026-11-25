# Runs the literal session-start commands from both hook manifests in the shells that run them.
import json
import os
import shutil
import subprocess
import sys
import time
import venv
from datetime import UTC, datetime
from pathlib import Path

import pytest

from legion.hook._hook import MEMBER

PLUGIN = Path(__file__).resolve().parents[3] / "plugins" / "legion"
FALLBACK = "legion: uv or Python 3.12 is missing, so mode detection did not run; run the legion installer. If LEGION_ROLE=member is set, load the legion-member skill."
CASES = ["default", "configured", "member", "missing", "pruned", "bad marker", "absolute marker", "legacy marker", "missing root"]


def manifest_commands() -> dict[str, str]:
    shared = json.loads((PLUGIN / "hooks" / "hooks.json").read_text(encoding="utf-8"))["hooks"]["SessionStart"][0]["hooks"][0]
    copilot = json.loads((PLUGIN / "hooks" / "copilot-hooks.json").read_text(encoding="utf-8"))["hooks"]["sessionStart"][0]
    return {"command": shared["command"], "commandWindows": shared["commandWindows"], "bash": copilot["bash"], "powershell": copilot["powershell"]}


COMMANDS = manifest_commands()


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


def ready(home: Path, version: str, name: str, *, pruned: bool = False) -> Path:
    marker = home / ".legion" / "app" / version / ".legion-app-ready"
    marker.parent.mkdir(parents=True)
    marker.write_text(name, encoding="utf-8")
    if not pruned:
        venv.EnvBuilder(with_pip=False).create(home / ".legion" / "python" / name)
    return marker


def cache_update(home: Path, version: str) -> None:
    cache = home / ".legion" / "temp" / "update.json"
    cache.parent.mkdir(parents=True)
    record = {"Source": "BlackGad/ps-legion-marketplace", "CheckedAt": datetime.now(UTC).isoformat(), "Available": version, "Failed": False}
    cache.write_text(json.dumps(record), encoding="utf-8")


def shell_cases() -> list[tuple[str, str, Path, str]]:
    cases = [(key, name, path, "-c") for key in ("command", "bash") for name, path in posix_shells().items()]
    if sys.platform == "win32":
        cases.extend((key, name, path, "-Command") for key in ("commandWindows", "powershell") for name, path in powershells().items())
    return cases


SHELL_CASES = shell_cases()


@pytest.mark.parametrize(("key", "shell_name", "shell", "flag"), SHELL_CASES, ids=[f"{key}-{name}" for key, name, _, _ in SHELL_CASES])
@pytest.mark.parametrize("case", CASES)
def test_manifest_hook_command(plugin: Path, tmp_path: Path, key: str, shell_name: str, shell: Path, flag: str, case: str) -> None:
    login = Path.home()
    configured = tmp_path / "owner O'Brien ü"
    root_name = "CLAUDE_PLUGIN_ROOT" if key in ("command", "commandWindows") else "COPILOT_PLUGIN_ROOT"
    env = {key: value for key, value in os.environ.items() if not key.startswith(("LEGION_", "UV_PYTHON"))}
    if case != "missing root":
        env[root_name] = str(plugin)
    if case != "default":
        env["LEGION_HOME"] = str(configured)
    version = json.loads((plugin / "plugin.json").read_text(encoding="utf-8"))["version"]
    name = "env-abcdef012345"
    home = login if case == "default" else configured
    if case in ("default", "configured", "member"):
        ready(home, version, name)
    elif case in ("pruned", "bad marker", "absolute marker", "legacy marker"):
        marker = ready(home, version, name, pruned=True)
        marker_contents = {"bad marker": "../outside", "absolute marker": str(tmp_path / "outside"), "legacy marker": ""}
        if case in marker_contents:
            marker.write_text(marker_contents[case], encoding="utf-8")
    if case != "default":
        # Any fallback to the login home would find a valid runtime and a different update notice.
        ready(login, version, "env-012345abcdef")
    if case == "configured":
        # The highest ready version is intentionally unusable. The loaded plugin owns version selection.
        ready(configured, "999.0.0", "env-111111111111", pruned=True)
    cache_update(login, "777.0.0")
    cache_update(configured, "888.0.0")
    hook = plugin / "hooks" / "session_start.py"
    original = hook.read_text(encoding="utf-8")
    probe = f"""
import os
import sys
from pathlib import Path

assert sys.flags.isolated
assert Path(sys.executable).parents[1].name == {name!r}

def reject_network(event, _args):
    if event in ("socket.getaddrinfo", "socket.connect"):
        with open(os.environ["PYTHON_TEST_SOCKET_RECORD"], "a", encoding="utf-8") as log:
            log.write(event)
        raise RuntimeError("hook tried the network")

sys.addaudithook(reject_network)
"""
    hook.write_text(probe + original, encoding="utf-8")
    # Fence uv and PowerShell: the POSIX hooks must also work without PowerShell installed.
    path = without(env["PATH"], "uv", "uv.exe", "uv.cmd")
    if flag == "-c":
        path = without(path, "pwsh", "pwsh.exe")
    trap = tmp_path / "uv-trap"
    trap.mkdir()
    (trap / "uv").write_text("#!/bin/sh\nprintf 'unexpected uv call' > uv-called\nexit 99\n", encoding="utf-8", newline="\n")
    (trap / "uv").chmod(0o755)
    (trap / "uv.cmd").write_text("@echo unexpected uv call > uv-called\n@exit /b 99\n", encoding="utf-8")
    paths = [str(trap)]
    if sys.platform == "win32" and flag == "-c":
        paths.append(str(posix_shells()["sh"].parent))
    env["PATH"] = os.pathsep.join([*paths, path])
    repo = tmp_path / "repo"
    (repo / ".legion" / "state").mkdir(parents=True)
    (repo / ".legion" / "state" / "handoff.md").touch()
    # Exercise stdin cwd, separate from the directory where the shell starts.
    hook_input = json.dumps({"cwd": str(repo), "hook_event_name": "SessionStart"})
    args = [str(shell), "-NoProfile", flag, COMMANDS[key]] if flag == "-Command" else [str(shell), flag, COMMANDS[key]]
    expected_version = "777.0.0" if case == "default" else "888.0.0"
    expected = f'legion: this repo is orchestrated. Say continue to act as the overseer. legion {expected_version} is available (installed {version}); say "update legion" to update.'
    if case not in ("default", "configured"):
        env.update(LEGION_ROLE="member", LEGION_TASK="task.md")
        expected = MEMBER if case == "member" else FALLBACK
    if key in ("bash", "powershell"):
        expected = json.dumps({"additionalContext": expected}, separators=(",", ":"))
    start = time.monotonic()
    result = subprocess.run(args, input=hook_input, capture_output=True, text=True, cwd=tmp_path, env=env, timeout=10, check=False)
    elapsed = time.monotonic() - start
    print(f"{key} / {shell_name} / {case}: {elapsed:.3f}s")
    assert not (tmp_path / "uv-called").exists()
    assert elapsed < 10
    assert result.returncode == 0, result.stderr
    assert result.stderr == ""
    assert result.stdout.splitlines() == [expected]
