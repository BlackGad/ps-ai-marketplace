# Start an account's program with its own config folder. The owner's overseer, members, limits,
# inbox nudges and Foundry accounts all launch through here; nothing is written to <home>/.legion/bin.

import os
import signal
import subprocess
import sys
from collections.abc import Callable, Mapping, Sequence
from contextlib import suppress
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from legion.core import _settings_io
from legion.core._home import full_path, home_path
from legion.core._run import _cmd_line, launch_environment
from legion.core._settings_models import Agent
from legion.services.accounts._accounts import get_tool
from legion.services.accounts._launchers import LauncherError, command_prefix, target
from legion.services.foundry import recipe
from legion.services.foundry._az import AzAccessToken, check_token
from legion.services.foundry._types import ProviderFile
from legion.services.foundry.copilot import write_provider


@dataclass(frozen=True)
class AccountCommand:
    program: Path
    prefix: list[str]
    set_env: dict[str, str]
    clear_env: list[str] = field(default_factory=list[str])
    provider_file: Optional[tuple[Path, ProviderFile]] = None
    notice: Optional[str] = None

    def words(self, arguments: Sequence[str]) -> list[str]:
        return [str(self.program), *self.prefix, *arguments]

    # The caller's environment (by default this process's, without legion's own virtual environment), changed for the account.
    def environment(self, base: Optional[Mapping[str, str]] = None) -> dict[str, str]:
        environment = dict(launch_environment() if base is None else base)
        for name in self.clear_env:
            environment.pop(name, None)
        return environment | self.set_env


# The account's own program, or the tool's stock one; the config folder variable comes from the tool, Foundry from its recipe.
def account_command(agent: Agent, home: Path, *, token_check: Callable[[], AzAccessToken] = check_token) -> AccountCommand:
    tool = get_tool(agent.tool)
    program, prefix = command_prefix(target(agent, tool, home))
    legion_home = {"LEGION_HOME": str(full_path(home))}
    if agent.provider is None:
        folder = full_path(home_path(agent.config_dir, home))
        return AccountCommand(program, prefix, {tool.config_env: str(folder), **legion_home})
    launch = recipe(agent).launch(agent, home, token_check())
    return AccountCommand(program, prefix, launch.set | legion_home, launch.clear, launch.provider_file, launch.notice)


# True when this process is in the terminal's foreground group: a Ctrl+C typed there reached the account's program too.
def _foreground() -> bool:
    if sys.platform == "win32":
        return False
    try:
        with open("/dev/tty", "rb") as terminal:
            return os.tcgetpgrp(terminal.fileno()) == os.getpgrp()
    except OSError:
        return False


# Runs the account in this terminal and returns its exit code; Ctrl+C goes to the account's program, not to legion.
# On POSIX a SIGINT or SIGTERM sent to legion's own process is passed on, as when the old launcher exec'd the tool.
def run_account(account: str, arguments: list[str], home: Path, *, cwd: Optional[Path] = None, environment: Optional[Mapping[str, str]] = None) -> int:
    agent = next((item for item in _settings_io.load(home).agents if item.id == account), None)
    if agent is None:
        raise LauncherError(f"unknown account '{account}'")
    command = account_command(agent, home)
    path = command.provider_file[0] if command.provider_file else None
    try:
        if command.provider_file:
            write_provider(*command.provider_file)
        if command.notice:
            print(command.notice, flush=True)
        line: str | list[str] = command.words(arguments)
        if sys.platform == "win32" and Path(line[0]).suffix.lower() in (".cmd", ".bat"):
            line = _cmd_line(line)
        child = subprocess.Popen(line, cwd=cwd, env=command.environment(environment))

        def forward(number: int, _frame: object) -> None:
            if number == signal.SIGINT and _foreground():
                return
            with suppress(ProcessLookupError):
                child.send_signal(number)

        names = [signal.SIGINT, signal.SIGTERM] if sys.platform != "win32" else []
        previous = {number: signal.signal(number, forward) for number in names}
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
            for number, handler in previous.items():
                signal.signal(number, handler)
    finally:
        if path is not None:
            path.unlink(missing_ok=True)
