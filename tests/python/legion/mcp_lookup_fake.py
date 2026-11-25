# A real stdio server with slow local storage, after a successful fake Codex ping.
import os
import sys
import time
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Optional
from unittest.mock import patch

from legion.mcp import server
from legion.services.limits.limit_probes import codex


def main(home: Path, log: Path, phase: str, budget: float) -> None:
    scandir = os.scandir
    rate_limits = codex._rate_limits
    session_limits = codex._session_limits
    sessions = home / ".legion/agents/codex-a/sessions"

    def pause() -> None:
        (log / "lookup.started").write_text("ready", encoding="utf-8")
        time.sleep(0.02)

    @contextmanager
    def slow_scandir(path: Path) -> Iterator[Iterator[os.DirEntry[str]]]:
        with scandir(path) as entries:

            def slow_entries() -> Iterator[os.DirEntry[str]]:
                for entry in entries:
                    if phase == "enumerate" and path == sessions:
                        pause()
                    yield entry

            yield slow_entries()

    def slow_record(line: str) -> Optional[codex.RateLimits]:
        if phase == "records":
            pause()
        return rate_limits(line)

    def lookup(folder: Path, ping_folder: Path) -> Optional[codex.RateLimits]:
        outcome = "completed"
        try:
            return session_limits(folder, ping_folder)
        except BaseException as error:
            outcome = type(error).__name__
            raise
        finally:
            (log / "lookup.finished").write_text(outcome, encoding="utf-8")

    codex._rate_limits = slow_record
    codex._session_limits = lookup
    if budget != server.CALL_BUDGET:
        server.CALL_BUDGET = budget
    with patch.object(codex, "scandir", slow_scandir):
        server.main(home)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], float(sys.argv[4]) if len(sys.argv) > 4 else 2.0)
