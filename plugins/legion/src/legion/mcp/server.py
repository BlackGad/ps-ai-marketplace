import _thread
import contextlib
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import (
    Annotated,
    Optional,
)

import anyio
import psutil
from anyio.abc import (
    ByteReceiveStream,
    Process,
)
from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations
from pydantic import (
    Field,
    TypeAdapter,
)

from legion.core import _stop_event
from legion.core._home import legion_home
from legion.core._run import DRAIN_SECONDS
from legion.services.limits import AccountLimits
from legion.services.status import StatusReport

# Leave 5 s for serialization within Copilot's documented 30 s default.
CALL_BUDGET = 25.0
# Reserve time for CLI startup and output, plus both process drain waits after a timeout.
PROBE_RESERVE = 2 * DRAIN_SECONDS + 2.0
PROBE_BUDGET = CALL_BUDGET - PROBE_RESERVE
# How long a terminated process may take to exit before it is killed.
STOP_SECONDS = 3.0
# How long the server gets to end on its own after the stop event, before the process is ended.
STOP_GRACE_SECONDS = 2.0


# Each tool call runs the matching CLI as one child process, so cancelling a call means ending that process tree.
# The child gets its own temporary folder; it is removed after the child ends, even when the child was killed.
async def _run_cli(arguments: list[str], home: Optional[Path], cwd: Optional[Path] = None) -> bytes:
    if os.environ.get("LEGION_ROLE") == "member" or os.environ.get("LEGION_TASK"):
        raise ValueError("Legion members do not use MCP tools")
    deadline = anyio.current_time() + CALL_BUDGET
    temp = Path(tempfile.mkdtemp(prefix="legion-mcp-"))
    try:
        return await _run_child(arguments, home, cwd, {**os.environ, "TEMP": str(temp), "TMP": str(temp), "TMPDIR": str(temp)}, deadline)
    finally:
        shutil.rmtree(temp, ignore_errors=True)


async def _run_child(arguments: list[str], home: Optional[Path], cwd: Optional[Path], environment: dict[str, str], deadline: float) -> bytes:
    # -I keeps a repository-local module in the working folder from shadowing the installed package.
    command = [sys.executable, "-I", "-m", "legion.cli", *(["--home", str(home)] if home is not None else []), *arguments]
    output = bytearray()
    errors = bytearray()

    async def collect(stream: ByteReceiveStream, buffer: bytearray) -> None:
        async for chunk in stream:
            buffer.extend(chunk)

    process, child = await _start(command, cwd, environment)
    try:
        with anyio.fail_at(deadline):
            async with anyio.create_task_group() as group:
                assert process.stdout is not None
                assert process.stderr is not None
                group.start_soon(collect, process.stdout, output)
                group.start_soon(collect, process.stderr, errors)
            await process.wait()
    except TimeoutError:
        raise ValueError("MCP call deadline exceeded") from None
    finally:
        # Also runs on cancel or EOF; the shield lets the cleanup finish.
        with anyio.CancelScope(shield=True):
            try:
                if child is not None:
                    await anyio.to_thread.run_sync(_end_tree, child)
            finally:
                await process.aclose()
    if process.returncode != 0:
        raise ValueError(errors.decode("utf-8", errors="replace").strip() or f"legion exited with {process.returncode}")
    return bytes(output)


# Starting is short; shielding it means a started child is always known to the cleanup of its caller.
async def _start(command: list[str], cwd: Optional[Path], environment: dict[str, str]) -> tuple[Process, Optional[psutil.Process]]:
    with anyio.CancelScope(shield=True):
        process = await anyio.open_process(command, stdin=subprocess.DEVNULL, cwd=cwd, env=environment)
        # Keep the identity from spawn: psutil checks it before signalling, so a reused pid is never hit.
        try:
            return process, psutil.Process(process.pid)
        except psutil.NoSuchProcess:
            return process, None
    raise AssertionError("unreachable: the shielded start always returns")  # pyright cannot see that a shield never swallows


# Go on past a process that cannot be stopped, then report the first such failure.
def _end_tree(child: psutil.Process) -> None:
    if not child.is_running():
        return
    failures: list[psutil.Error] = []

    def stop(processes: list[psutil.Process], action: str) -> None:
        for process in processes:
            try:
                getattr(process, action)()
            except psutil.NoSuchProcess:
                continue
            except psutil.Error as error:
                failures.append(error)

    try:
        tree = [*child.children(recursive=True), child]
    except psutil.NoSuchProcess:
        return
    stop(tree, "terminate")
    _, alive = psutil.wait_procs(tree, timeout=STOP_SECONDS)
    stop(alive, "kill")
    psutil.wait_procs(alive, timeout=STOP_SECONDS)
    if failures:
        raise failures[0]


def build(home: Optional[Path] = None) -> FastMCP:
    server = FastMCP("legion", log_level="ERROR")
    # FastMCP disables this SDK validator to permit coercion (including JSON strings
    # into arrays). Validate the advertised schema before any tool conversion.
    server._mcp_server.call_tool(validate_input=True)(server.call_tool)

    @server.tool(description="Read Legion status for a repository, with local version and process checks.", annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False))
    async def status(repo: Optional[str] = None) -> StatusReport:
        report = await _run_cli(["status", "--json"], home, Path(repo) if repo is not None else None)
        return StatusReport.model_validate_json(report)

    @server.tool(
        description=f"Ping each named account; consumes quota and may be billable, creates a ping folder and Codex session; Foundry checks az; capped at {CALL_BUDGET:g}s per call.",
        annotations=ToolAnnotations(readOnlyHint=False, idempotentHint=False, openWorldHint=True),
    )
    async def limits(accounts: list[str], timeout: Annotated[float, Field(gt=0, allow_inf_nan=False)] = 120) -> list[AccountLimits]:
        effective_timeout = min(timeout, PROBE_BUDGET)
        arguments = ["limits", "--json", "--timeout", str(effective_timeout)]
        for account in accounts:
            arguments += ["--id", account]
        return TypeAdapter(list[AccountLimits]).validate_json(await _run_cli(arguments, home))

    return server


# The stop event interrupts the server. A blocked read of stdin cannot be cancelled, so the process ends after a short grace.
def _stop_serving() -> None:
    _thread.interrupt_main()
    time.sleep(STOP_GRACE_SECONDS)
    os._exit(0)


# While it serves, this process is registered for the stop event; an update makes it exit.
def main(home: Optional[Path] = None) -> int:
    with _stop_event.registered(legion_home(home), _stop_serving), contextlib.suppress(KeyboardInterrupt):
        build(home).run(transport="stdio")
    return 0
