# Fakes for the uv tool and refresh tests: a plugin source folder and a recording uv.

import json
import sys
from collections.abc import Mapping
from pathlib import Path

import pytest

from legion.services.installation import _uv_tool
from legion.core._run import RunResult

if sys.platform == "win32":
    import _winapi

VERSION = "1.0.0"


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
    # A recording uv. `calls` holds the arguments of each uv command run in this process; `detached` holds each
    # command handed to the helper that runs after exit, with the paths it deletes. The tool state is `installed`.
    def __init__(self, monkeypatch: pytest.MonkeyPatch, bin_folder: Path) -> None:
        self.calls: list[list[str]] = []
        self.detached: list[tuple[list[str], list[Path]]] = []
        self.installed: str | None = None
        self.fail: dict[str, int] = {}
        self.bin = bin_folder
        # Where `uv tool dir` says the tools live.
        self.tools = bin_folder.parent / "uv tools"
        monkeypatch.setattr(_uv_tool, "find_uv", lambda: "uv")
        monkeypatch.setattr(_uv_tool, "run_command", self.run)
        monkeypatch.setattr("legion.services.installation._constraints.run_command", self.run)
        monkeypatch.setattr(_uv_tool._handover, "start_command", lambda command, remove=None: self.detached.append((command, remove or [])))

    def installs(self) -> list[list[str]]:
        return [call for call in self.calls if call[:2] == ["tool", "install"]]

    def run(self, command: str, arguments: list[str], timeout: float | None = None, env: Mapping[str, str] | None = None, cwd: Path | None = None) -> RunResult:
        assert command == "uv"
        self.calls.append(list(arguments))
        name = " ".join(arguments[:2])
        output = ""
        if name in self.fail:
            return RunResult(exit_code=self.fail[name], output="", error=f"{name} failed", timed_out=False)
        if name == "tool list" and self.installed:
            output = f"legion v{self.installed}\n- legion\n"
        elif arguments == ["tool", "dir"]:
            output = f"{self.tools}\n"
        elif arguments == ["tool", "dir", "--bin"]:
            output = f"{self.bin}\n"
        elif arguments[0] == "export":
            output = "mcp==1.0.0\n"
        elif name == "tool install":
            root = Path(arguments[2].removesuffix("[mcp]"))
            self.installed = json.loads((root / "plugin.json").read_text(encoding="utf-8"))["version"]
            program = self.bin / ("legion.exe" if sys.platform == "win32" else "legion")
            program.parent.mkdir(parents=True, exist_ok=True)
            program.touch()
        return RunResult(exit_code=0, output=output, error="", timed_out=False)
