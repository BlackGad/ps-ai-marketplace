# Fake tools and a PATH for the account and launcher tests; nothing here starts a real tool.

import os
import stat
import sys
from pathlib import Path

import pytest

from legion.services.repository import _footprints
from legion.services.installation._installed_runtime import python_environment
from legion.core._settings_models import Agent, ToolDescriptor
from legion.core._validate import load_descriptors

WINDOWS = sys.platform == "win32"

# Prints the account variable and each argument on a line, then exits 3. cmd.exe needs the quotes around & in a path.
CMD_CLI = '@echo off\r\necho "var=%{variable}%"\r\nfor %%a in (%*) do echo "arg=%%~a"\r\nexit /b 3\r\n'
SH_CLI = '#!/bin/sh\necho "var=${variable}"\nfor a in "$@"; do echo "arg=$a"; done\nexit 3\n'
# The same readout as a Python script, so a launcher can be proven against a real .exe target.
PY_CLI = 'import os, sys\nprint("var=" + os.environ["{variable}"])\nfor argument in sys.argv[1:]:\n    print("arg=" + argument)\nraise SystemExit(3)\n'


def tool(tool_id: str) -> ToolDescriptor:
    return next(descriptor for descriptor in load_descriptors(ToolDescriptor, "tool.json") if descriptor.id == tool_id)


def agent(account: str, folder: Path, tool_id: str = "codex", command: str | None = None) -> Agent:
    data = {"id": account, "tool": tool_id, "configDir": str(folder)}
    if command is not None:
        data["command"] = command
    return Agent.model_validate(data)


def fake_cli(folder: Path, name: str, variable: str = "CODEX_HOME") -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    if WINDOWS:
        path = folder / f"{name}.cmd"
        path.write_text(CMD_CLI.replace("{variable}", variable), encoding="utf-8", newline="")
    else:
        path = folder / name
        path.write_text(SH_CLI.replace("{variable}", variable), encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


def python_cli(folder: Path, variable: str = "CODEX_HOME") -> Path:
    folder.mkdir(parents=True, exist_ok=True)
    path = folder / "fake_cli.py"
    path.write_text(PY_CLI.replace("{variable}", variable), encoding="utf-8")
    return path


# What the owner runs once to log in: the tool itself started on the account's folder, in the shell of the system.
def login(variable: str, folder: Path, program: str) -> str:
    if WINDOWS:
        return f"$env:{variable}='{folder}'; {program}"
    return f"{variable}='{folder}' {program}"


# Only these folders are searched for commands, and Windows runs .cmd files from them.
def only_on_path(monkeypatch: pytest.MonkeyPatch, *folders: Path) -> None:
    monkeypatch.setenv("PATH", os.pathsep.join(str(folder) for folder in folders))
    if WINDOWS:
        monkeypatch.setenv("PATHEXT", ".COM;.EXE;.BAT;.CMD")


# A home with one ready app version, and the legion program its Foundry launchers must name.
def ready_app(home: Path, version: str = "1.0.0") -> Path:
    app = home / ".legion" / "app" / version
    app.mkdir(parents=True)
    (app / ".legion-app-ready").touch()
    _footprints.add(home, "app-version", app, "legion")
    program = python_environment(app, home) / ("Scripts/legion.exe" if WINDOWS else "bin/legion")
    program.parent.mkdir(parents=True, exist_ok=True)
    program.touch()
    return program
