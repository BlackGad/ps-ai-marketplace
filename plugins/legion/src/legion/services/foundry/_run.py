import signal
import subprocess
import sys
from pathlib import Path

from legion.services.accounts import _launchers
from legion.core import _settings_io
from legion.core._home import full_path
from legion.core._run import _cmd_line, launch_environment
from legion.core._settings_models import ToolDescriptor
from legion.core._validate import load_descriptors
from legion.services.foundry import recipe
from legion.services.foundry._az import check_token
from legion.services.foundry.copilot import write_provider


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
        raise ValueError(f"{agent.tool} is not installed; run legion tool install --tool {agent.tool}")
    token = check_token()
    launch = recipe(agent).launch(agent, home, token)
    environment = launch_environment()
    for name in launch.clear:
        environment.pop(name, None)
    environment.update(launch.set)
    environment["LEGION_HOME"] = str(full_path(home))
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
                    code = child.wait()
                    # A tool killed by a signal gives -signal; a shell reports 128 + signal.
                    return 128 - code if code < 0 else code
                except KeyboardInterrupt:
                    if sys.platform != "win32":
                        raise
        finally:
            if previous is not None:
                signal.signal(signal.SIGINT, previous)
    finally:
        if path is not None:
            path.unlink(missing_ok=True)
