# Taking the lease from a command: the chosen process must be a session, never the Codex app-server daemon.
# Release does not use this module, so a lease the daemon already holds can still be released.

from pathlib import Path
from typing import Optional

import psutil

from legion.core._process import ProcessInfo, owner_process, process_info
from legion.services.repository._lease import LeaseError, take

APP_SERVER_REFUSAL = "pid {pid} is the Codex app-server daemon, not your session; pass --process-id <the Codex session process id>"
UNREADABLE_REFUSAL = "cannot read the command line of Codex process {pid}; pass --process-id <the Codex session process id>"


def take_for_session(repo: Path, tool: str, account: str, process_id: Optional[int] = None) -> str:
    if process_id is None:
        try:
            process = owner_process()
        except LookupError as error:
            raise LeaseError(str(error)) from error
    else:
        # A pid that is not running is left to take, which reports it.
        process = process_info(process_id)
    if process is not None:
        _refuse_app_server(process)
    return take(repo, tool, account, process_id=process_id if process is None else process.pid)


def _refuse_app_server(process: ProcessInfo) -> None:
    if not process.name.lower().removesuffix(".exe").startswith("codex"):
        return
    try:
        command_line = psutil.Process(process.pid).cmdline()
    except psutil.Error:
        command_line = []
    if not command_line:
        raise LeaseError(UNREADABLE_REFUSAL.format(pid=process.pid))
    if command_line[1:2] == ["app-server"]:
        raise LeaseError(APP_SERVER_REFUSAL.format(pid=process.pid))
