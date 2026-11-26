import os
import subprocess
import sys
from contextlib import suppress
from pathlib import Path
from typing import (
    Annotated,
    Optional,
)

import anyio
import psutil
from anyio.abc import ByteReceiveStream
from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations
from pydantic import (
    Field,
    TypeAdapter,
)

from legion.services.limits import AccountLimits
from legion.services.status import StatusReport

# Fit even Copilot's documented 30 s default, reserving time for cleanup and serialization.
CALL_BUDGET = 20.0
# How long a terminated process may take to exit before it is killed.
STOP_SECONDS = 3.0


# Each tool call runs the matching CLI as one child process, so cancelling a call means ending that process tree.
async def _run_cli(arguments: list[str], home: Optional[Path], cwd: Optional[Path] = None) -> bytes:
    if os.environ.get("LEGION_ROLE") == "member" or os.environ.get("LEGION_TASK"):
        raise ValueError("Legion members do not use MCP tools")
    command = [sys.executable, "-m", "legion.cli", *(["--home", str(home)] if home is not None else []), *arguments]
    output = bytearray()
    errors = bytearray()

    async def collect(stream: ByteReceiveStream, buffer: bytearray) -> None:
        async for chunk in stream:
            buffer.extend(chunk)

    process = await anyio.open_process(command, stdin=subprocess.DEVNULL, cwd=cwd)
    try:
        with anyio.fail_after(CALL_BUDGET):
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
            if process.returncode is None:
                await anyio.to_thread.run_sync(_end_tree, process.pid)
            await process.aclose()
    if process.returncode != 0:
        raise ValueError(errors.decode("utf-8", errors="replace").strip() or f"legion exited with {process.returncode}")
    return bytes(output)


def _end_tree(pid: int) -> None:
    try:
        parent = psutil.Process(pid)
        tree = [*parent.children(recursive=True), parent]
    except psutil.NoSuchProcess:
        return
    for process in tree:
        with suppress(psutil.NoSuchProcess):
            process.terminate()
    _, alive = psutil.wait_procs(tree, timeout=STOP_SECONDS)
    for process in alive:
        with suppress(psutil.NoSuchProcess):
            process.kill()
    psutil.wait_procs(alive, timeout=STOP_SECONDS)


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
        description="Ping each named account; consumes quota and may be billable, creates a ping folder and Codex session; Foundry checks az; capped at 20s per call.",
        annotations=ToolAnnotations(readOnlyHint=False, idempotentHint=False, openWorldHint=True),
    )
    async def limits(accounts: list[str], timeout: Annotated[float, Field(gt=0, allow_inf_nan=False)] = 120) -> list[AccountLimits]:
        effective_timeout = min(timeout, CALL_BUDGET)
        if len(accounts) * effective_timeout > CALL_BUDGET:
            raise ValueError("call limits once per account")
        arguments = ["limits", "--json", "--timeout", str(effective_timeout)]
        for account in accounts:
            arguments += ["--id", account]
        return TypeAdapter(list[AccountLimits]).validate_json(await _run_cli(arguments, home))

    return server


def main(home: Optional[Path] = None) -> int:
    build(home).run(transport="stdio")
    return 0
