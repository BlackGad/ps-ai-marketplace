import os
import threading
import time
from collections.abc import Callable
from functools import partial
from pathlib import Path
from typing import (
    Annotated,
    Optional,
)

from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations

import anyio
from pydantic import Field

from legion.core._run import CommandCancelled, command_cancellation
from legion.services.limits import AccountLimits, limits as limits_report
from legion.services.status import StatusReport, status as status_report

# Fit even Copilot's documented 30 s default, reserving time for cleanup and serialization.
CALL_BUDGET = 20.0


async def _call[T](function: Callable[[], T], budget: float = CALL_BUDGET) -> T:
    if os.environ.get("LEGION_ROLE") == "member" or os.environ.get("LEGION_TASK"):
        raise ValueError("Legion members do not use MCP tools")
    cancelled = threading.Event()
    finished = threading.Event()
    started = threading.Event()
    deadline = time.monotonic() + budget

    def work() -> T:
        started.set()
        try:
            if cancelled.is_set():
                raise CommandCancelled
            with command_cancellation(cancelled, deadline=deadline):
                return function()
        finally:
            finished.set()

    try:
        with anyio.fail_after(budget):
            return await anyio.to_thread.run_sync(work, abandon_on_cancel=True)
    except TimeoutError:
        raise ValueError("MCP call deadline exceeded") from None
    finally:
        cancelled.set()
        # Do not exit while the worker still owns a probe or its temporary folder.
        with anyio.CancelScope(shield=True):
            if started.is_set():
                await anyio.to_thread.run_sync(finished.wait)


def build(home: Optional[Path] = None) -> FastMCP:
    server = FastMCP("legion", log_level="ERROR")
    # FastMCP disables this SDK validator to permit coercion (including JSON strings
    # into arrays). Validate the advertised schema before any tool conversion.
    server._mcp_server.call_tool(validate_input=True)(server.call_tool)

    @server.tool(description="Read Legion status for a repository, with local version and process checks.", annotations=ToolAnnotations(readOnlyHint=True, openWorldHint=False))
    async def status(repo: Optional[str] = None) -> StatusReport:
        return await _call(partial(status_report, Path(repo) if repo is not None else Path.cwd(), home))

    @server.tool(
        description="Ping each named account; consumes quota and may be billable, creates a ping folder and Codex session; Foundry checks az; capped at 20s per call.",
        annotations=ToolAnnotations(readOnlyHint=False, idempotentHint=False, openWorldHint=True),
    )
    async def limits(accounts: list[str], timeout: Annotated[float, Field(gt=0, allow_inf_nan=False)] = 120) -> list[AccountLimits]:
        effective_timeout = min(timeout, CALL_BUDGET)
        if len(accounts) * effective_timeout > CALL_BUDGET:
            raise ValueError("call limits once per account")
        return await _call(partial(limits_report, home, accounts, effective_timeout), CALL_BUDGET)

    return server


def main(home: Optional[Path] = None) -> int:
    build(home).run(transport="stdio")
    return 0
