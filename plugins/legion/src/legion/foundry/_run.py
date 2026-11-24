import os
import signal
import subprocess
import sys
from pathlib import Path

from .. import _launchers, _settings_io
from .._run import _cmd_line
from .._settings_models import ToolDescriptor
from .._validate import load_descriptors
from . import recipe
from ._az import check_token
from .copilot import write_provider


def run(account: str, arguments: list[str], home: Path) -> int:
    settings = _settings_io.load(home)
    agent = next((item for item in settings.agents if item.id == account), None)
    if agent is None:
        raise ValueError(f"unknown account '{account}'")
    if agent.provider is None or agent.provider.kind != "foundry":
        raise ValueError(f"account '{account}' is not a Foundry agent")
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == agent.tool)
    command = _launchers.stock_command(descriptor, home)
    if command is None:
        raise ValueError(f"{agent.tool} is not installed; run legion-install-tool.ps1 -Tool {agent.tool}")
    token = check_token()
    launch = recipe(agent).launch(agent, home, token)
    environment = os.environ.copy()
    for name in launch.clear:
        environment.pop(name, None)
    environment.update(launch.set)
    path = launch.provider_file[0] if launch.provider_file else None
    try:
        if launch.provider_file:
            write_provider(*launch.provider_file)
        if launch.notice:
            print(launch.notice, flush=True)
        line: str | list[str] = [str(command), *arguments]
        if sys.platform == "win32" and command.suffix.lower() in (".cmd", ".bat"):
            line = _cmd_line(line)
        child = subprocess.Popen(line, env=environment)
        previous = signal.signal(signal.SIGINT, signal.SIG_IGN) if sys.platform != "win32" else None
        try:
            while True:
                try:
                    return child.wait()
                except KeyboardInterrupt:
                    if sys.platform != "win32":
                        raise
        finally:
            if previous is not None:
                signal.signal(signal.SIGINT, previous)
    finally:
        if path is not None:
            path.unlink(missing_ok=True)
