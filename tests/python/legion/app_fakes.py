# Fakes for the app sync and refresh tests: a plugin source folder, a recording uv and ready or old app versions.

import json
import sys
from collections.abc import Callable, Mapping
from pathlib import Path

import pytest

from legion.services.installation import _installed_runtime
from legion.services.repository import _footprints
from legion.core._run import RunResult

if sys.platform == "win32":
    import _winapi

VERSION = "1.0.0"
MARKER = ".legion-app-ready"


def make_link(link: Path, target: Path) -> None:
    link.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == "win32":
        _winapi.CreateJunction(str(target), str(link))
    else:
        link.symlink_to(target, target_is_directory=True)


def make_source(root: Path, version: str = VERSION) -> Path:
    source = root / "source"
    (source / "src").mkdir(parents=True, exist_ok=True)
    (source / "plugin.json").write_text(json.dumps({"name": "legion", "version": version}), encoding="utf-8")
    (source / "pyproject.toml").write_text("[project]\n", encoding="utf-8")
    (source / "src" / "module.py").write_text("x = 1\n", encoding="utf-8")
    return source


class FakeUv:
    # Records each uv call with the environment it was given; the exit code and a side effect are set by the test.
    def __init__(self, monkeypatch: pytest.MonkeyPatch) -> None:
        self.calls: list[tuple[str, list[str], str]] = []
        self.exit_code = 0
        self.error = ""
        self.effect: Callable[[Path], None] | None = None
        # What the app's own legion answers to `run --help`; 0 means it can start accounts. Each probe is counted.
        self.run_help_exit = 0
        self.probes = 0
        monkeypatch.setattr(_installed_runtime, "find_uv", lambda: "uv")
        monkeypatch.setattr(_installed_runtime, "run_command", self.run)

    def run(self, command: str, arguments: list[str], timeout: float | None = None, env: Mapping[str, str] | None = None) -> RunResult:
        if arguments == ["run", "--help"]:
            self.probes += 1
            return RunResult(exit_code=self.run_help_exit, output="", error="", timed_out=False)
        assert env is not None
        self.calls.append((command, list(arguments), env["UV_PROJECT_ENVIRONMENT"]))
        if self.effect:
            self.effect(Path(arguments[2]))
        if self.exit_code == 0:
            # A synced environment holds the app's own legion.
            program = Path(env["UV_PROJECT_ENVIRONMENT"]) / ("Scripts/legion.exe" if sys.platform == "win32" else "bin/legion")
            program.parent.mkdir(parents=True, exist_ok=True)
            program.touch()
        return RunResult(exit_code=self.exit_code, output="", error=self.error, timed_out=False)


def old_app(home: Path, version: str = "0.0.1", ready: bool = True, recorded: bool = True) -> tuple[Path, Path]:
    path = home / ".legion" / "app" / version
    path.mkdir(parents=True)
    (path / "plugin.json").write_text(json.dumps({"name": "legion", "version": version}), encoding="utf-8")
    if ready:
        (path / MARKER).touch()
    environment = _installed_runtime.python_environment(path, home)
    environment.mkdir(parents=True)
    (environment / "python.txt").write_text("python", encoding="utf-8")
    if recorded:
        _footprints.add(home, "app-version", path, "legion")
    return path, environment
