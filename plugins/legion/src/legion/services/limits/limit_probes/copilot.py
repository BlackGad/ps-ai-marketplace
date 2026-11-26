# Copilot CLI has no limit readout. A quota error means the account is out; a normal answer only shows it works now.

from pathlib import Path

from legion.services.accounts._launch import AccountCommand
from legion.services.limits.limit_probes._ping import (
    LimitRow,
    Ping,
    ping,
    ping_failure,
)

ARGUMENTS = ["-p", "ping", "-s"]


def read(command: AccountCommand, _folder: Path, timeout: float) -> list[LimitRow]:
    return rows(ping(command, ARGUMENTS, timeout))


def rows(result: Ping) -> list[LimitRow]:
    if result.exit_code == 0:
        return [LimitRow(status="answers; no limit readout")]
    return [LimitRow(status=ping_failure(result, "quota"))]
