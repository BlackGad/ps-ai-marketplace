# The worker runs from an independent uv environment through shutdown, update and resume.

import io
import os
import re
import subprocess
import sys
import time
from contextlib import redirect_stderr, redirect_stdout, suppress
from datetime import datetime
from pathlib import Path

import click
import psutil
from filelock import FileLock, Timeout

from legion.core import (
    _home,
    _process,
    _run,
    _settings_io,
    _stop_event,
)
from legion.core._atomic_write import atomic_write_bytes
from legion.services.accounts import _launchers
from legion.services.accounts._accounts import get_tool
from legion.services.channels import _channel, _overseer, _telegram
from legion.services.installation import _uv_tool
from legion.services.lifecycle import _lifecycle
from legion.services.repository import _lease, _repository

if sys.platform != "win32":
    import pty

RESULT = Path(".legion/temp/self-update.log")
HANDOFF = Path(".legion/state/handoff.md")
ERRORS = (*_lifecycle.ERRORS, _channel.ChannelError, _overseer.OverseerError, _repository.RepositoryError, psutil.Error)


def _source(source: str, ref: str) -> tuple[str, str]:
    if Path(source).is_dir():
        source = str(_home.resolve_directory(Path(source)))
        return source, f"{Path(source) / 'plugins/legion'}[mcp]"
    if not re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", source):
        raise ValueError("Choose a local checkout or a GitHub owner/repository for self-update")
    branch = "main" if ref == "main" else "stable"
    return source, f"legion[mcp] @ git+https://github.com/{source}.git@{branch}#subdirectory=plugins/legion"


def _check_live_launch(pid: int, repo: Path, launch: _overseer.Launch, tool: str, session: str, config: tuple[str, Path]) -> None:
    # The legacy launcher keeps one history entry per repository. Verify that entry against the lease owner.
    try:
        process = psutil.Process(pid)
        actual = process.cmdline()[:-1]  # the startup prompt
        environment = process.environ()
        cwd = _home.resolve_directory(Path(process.cwd()))
    except (psutil.Error, NotImplementedError) as error:
        raise ValueError("Could not verify the live overseer launch") from error
    prefix = _overseer._resume_arguments(tool, session)
    arguments = launch.arguments[len(prefix) : -1]
    if tool == "claude":
        # The active conversation started either with --session-id or --resume.
        arguments = [session, *arguments]
        if len(actual) <= len(arguments) or actual[-len(arguments) - 1] not in ("--session-id", "--resume"):
            raise ValueError("The live Claude conversation does not match the saved launch")
    if not _home.same_path(cwd, repo) or (arguments and actual[-len(arguments) :] != arguments):
        raise ValueError("The live overseer repository or arguments do not match the saved launch")
    variable, folder = config
    expected = launch.environment | {variable: str(folder)}
    for name, value in expected.items():
        actual_path = environment.get(name)
        if not actual_path or not _home.same_path(_home.resolve_directory(Path(actual_path)), _home.resolve_directory(Path(value))):
            raise ValueError("The live overseer account or channel folder does not match the saved launch")
    if "TELEGRAM_STATE_DIR" not in expected and environment.get("TELEGRAM_STATE_DIR"):
        raise ValueError("The live Telegram channel does not match the saved launch")


def _resume(repo: Path, home: Path, pid: int, session_id: str | None) -> tuple[_overseer.LastLaunch, _overseer.Launch]:
    current = _lease.state(repo)
    lease = current.lease
    if current.state != "held" or lease is None or lease.pid != pid or not _stop_event.has_registered_ancestor(home, pid=pid):
        raise ValueError("Self-update requires the live overseer lease under its Legion launcher")
    saved = _overseer.load_last(repo, home)
    if saved is None or saved.account != lease.account:
        raise ValueError("The saved launch does not match this overseer lease")
    settings = _settings_io.load(home)
    agent = _channel._agent(settings, saved.account)
    if agent.tool != lease.tool:
        raise ValueError("The saved account tool does not match this overseer lease")
    if session_id is not None and agent.tool != "copilot":
        raise ValueError("--session-id is only used for Copilot self-update")
    tool = get_tool(agent.tool)
    _launchers.target(agent, tool, home)
    if agent.tool == "claude":
        session, resume = _overseer._session(saved.session, agent, home)
        if not resume:
            raise ValueError("The current Claude conversation has not been saved yet")
    else:
        session = (lease.session or "") if agent.tool == "codex" else (session_id or "")
    if not _overseer.CONVERSATION_ID.fullmatch(session):
        raise ValueError("Need the current conversation ID (use /session id and --session-id for Copilot)")
    resume_flags = {"--resume", "--continue", "--session-id"}
    resume_flags.update(("-r", "-c") if agent.tool == "claude" else ("resume",) if agent.tool == "codex" else ())
    if any(word.split("=", 1)[0] in resume_flags for word in saved.arguments):
        raise ValueError("Remove custom resume or session arguments from the overseer launch before self-update")
    launch = _overseer._launch(settings, agent, tuple(saved.channels), tuple(saved.arguments), session, True, repo, home)
    _check_live_launch(pid, repo, launch, agent.tool, session, (tool.config_env, _home.home_path(agent.config_dir, home)))
    return saved.model_copy(update={"session": session}), launch


def request(home: Path, source: str, ref: str, session_id: str | None, *, source_explicit: bool) -> int:
    repo = _repository._code_root(Path.cwd())
    current = _lease.state(repo).lease
    caller = _process.process_info(os.getpid())
    if caller is None or current is None:
        raise ValueError("Run self-update from the session holding the overseer lease")
    # Codex can run shell commands under its app server, outside the interactive CLI's process tree.
    codex_thread = current.tool == "codex" and current.session and current.session == os.environ.get("CODEX_THREAD_ID")
    if not codex_thread and current.pid not in {process.pid for process in _process.ancestors(caller.pid)}:
        raise ValueError("Run self-update from the session holding the overseer lease")
    if not _home.owner_path_safe(repo / HANDOFF, repo) or not (repo / HANDOFF).is_file():
        raise ValueError("Save the overseer handoff before self-update")
    lock = _home.run_folder(home) / "self-update.lock"
    if not _home.owner_path_safe(repo / RESULT, repo) or not _home.owner_path_safe(lock, home):
        raise ValueError("The self-update log or lock path contains a link")
    try:
        with FileLock(lock, timeout=0):
            pass
    except Timeout:
        raise ValueError("A Legion self-update is already running in this home") from None
    _resume(repo, home, current.pid, session_id)
    source, candidate = _source(source, ref)
    uv = _uv_tool.find_uv()
    if uv is None:
        raise ValueError(_uv_tool.UV_MISSING)
    if _uv_tool.running_from_tool(uv):
        arguments = ["--home", str(home), "update", "--self", "--yes", "--ref", ref]
        if source_explicit:
            arguments.extend(["--source", source])
        if session_id:
            arguments.extend(["--session-id", session_id])
        return _run.run_foreground(uv, ["tool", "run", "--isolated", "--refresh-package", "legion", "--from", candidate, "legion", *arguments])

    command = [sys.executable, "-m", __name__, str(home), str(repo), source, str(int(source_explicit)), ref, str(current.pid), str(caller.pid), caller.started_at.isoformat(), session_id or ""]
    environment = _run.launch_environment() | {"LEGION_HOME": str(home)}
    if sys.platform == "win32":
        # A new console provides an interactive relaunch after the old Terminal tab goes away.
        subprocess.Popen(command, cwd=repo, env=environment, creationflags=subprocess.CREATE_NEW_CONSOLE | subprocess.CREATE_BREAKAWAY_FROM_JOB)
    else:
        subprocess.Popen(command, cwd=repo, env=environment, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    click.echo(f"Legion self-update queued. This session will stop and reopen. Result: {repo / RESULT}")
    return 0


def _write_result(repo: Path, line: str) -> None:
    if not _home.owner_path_safe(repo / RESULT, repo):
        raise ValueError("The self-update log path contains a link")
    atomic_write_bytes(repo / RESULT, f"{line}\n".encode(), keep_mode=False)


def _report_failure(home: Path, channels: list[str], line: str) -> None:
    # If the session cannot report for itself, use its configured Telegram destinations.
    with suppress(*ERRORS):
        settings = _settings_io.load(home)
        for channel in settings.channels:
            if channel.id in channels and channel.kind == "telegram":
                with suppress(*ERRORS), redirect_stdout(io.StringIO()), redirect_stderr(io.StringIO()):
                    _telegram.send(channel.id, channel.target, line, "plain", None, [], home=home)


def _update(home: Path, repo: Path, owner: psutil.Process, source: str, ref: str, source_explicit: bool) -> str:
    # Preparation and plugin changes happen after the old launcher has released its files.
    try:
        _uv_tool.stop_running(home)
    except _uv_tool.UvToolError:
        return "Legion self-update failed while waiting for registered sessions to exit."
    try:
        if _stop_event._still_running(owner) or _lease.state(repo).state in ("held", "foreign"):
            return "Legion self-update failed because the repository still has a live overseer."
        with _lifecycle.saved_path():
            changes = _lifecycle.plan(home, "update", source=source, source_explicit=source_explicit, ref=ref, self_update=True)
            if _lifecycle.apply(changes, yes=True, say=lambda _line: None):
                return f"Legion self-update failed while updating {changes.failed_target}."
            if not changes.steps:
                return "Legion self-update completed. Legion is already current."
            return "Legion self-update completed."
    finally:
        _stop_event.clear_stop(home)


def _relaunch(repo: Path, launch: _overseer.Launch, line: str) -> int:
    launch.arguments[-1] = f"{line} Continue as the overseer. Take the lease, read {HANDOFF.as_posix()} and {RESULT.as_posix()}, then report the result on every connected channel."
    if sys.platform == "win32":
        print(line, flush=True)
        return _overseer.start_launch(repo, launch, in_place=True)

    # An interactive CLI needs a controlling terminal even when the requesting command was piped.
    child, terminal = pty.fork()
    if not child:
        try:
            code = _overseer.start_launch(repo, launch, in_place=True)
        except ERRORS:
            code = 1
        os._exit(code)
    try:
        # Drain the terminal without recording conversation output or credentials.
        with suppress(OSError):
            while os.read(terminal, 4096):
                pass
    finally:
        os.close(terminal)
    return os.waitstatus_to_exitcode(os.waitpid(child, 0)[1])


def _worker(home: Path, repo: Path, source: str, ref: str, pid: int, requester: int, started: datetime, session_id: str | None, *, source_explicit: bool) -> int:
    lock = FileLock(_home.run_folder(home) / "self-update.lock", timeout=0)
    try:
        lock.acquire()
    except Timeout:
        return 0
    try:
        _write_result(repo, "Legion self-update is waiting for the requesting command to exit.")
        deadline = time.monotonic() + _stop_event.WAIT_SECONDS
        while (process := _process.process_info(requester)) is not None and _process.same_start_time(process.started_at, started):
            if time.monotonic() >= deadline:
                raise TimeoutError("requester timeout")
            time.sleep(0.1)
        saved, launch = _resume(repo, home, pid, session_id)
        owner = psutil.Process(pid)
        _write_result(repo, "Legion self-update is stopping registered sessions.")
        try:
            line = _update(home, repo, owner, source, ref, source_explicit)
        except _lifecycle.ERRORS:
            line = "Legion self-update failed while preparing the update."
        if _stop_event._still_running(owner) or _lease.state(repo).state in ("held", "foreign"):
            line = f"{line} The overseer is still running."
            _write_result(repo, line)
            _report_failure(home, saved.channels, line)
            return 1
        # History supports manual recovery. The in-memory launch can still resume if saving fails.
        with suppress(OSError, ValueError):
            _overseer.save_last(repo, home, saved)
        try:
            _write_result(repo, line)
        except (OSError, ValueError):
            line = f"{line} The result file could not be written."
    except ERRORS:
        _write_result(repo, "Legion self-update failed before relaunch. Open Legion in this repository and read the saved handoff.")
        return 1
    finally:
        lock.release()

    try:
        code = _relaunch(repo, launch, line)
    except ERRORS:
        code = 1
    # A later self-update intentionally stops this launcher.
    lease = _lease.state(repo).lease
    if code or (lease is not None and lease.pid == pid):
        with suppress(Timeout, OSError, ValueError), lock.acquire():
            if not _stop_event.stop_raised(home) and (repo / RESULT).read_text(encoding="utf-8").strip() == line:
                reason = f"exited with code {code}" if code else "exited before taking the lease"
                line = f"{line} Overseer relaunch {reason}. Open Legion in this repository and read the saved handoff."
                _write_result(repo, line)
                _report_failure(home, saved.channels, line)
    return code


if __name__ == "__main__":
    home, repo, source, explicit, ref, pid, requester, started, session = sys.argv[1:]
    raise SystemExit(_worker(Path(home), Path(repo), source, ref, int(pid), int(requester), datetime.fromisoformat(started), session or None, source_explicit=explicit == "1"))
