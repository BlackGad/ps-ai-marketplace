from pathlib import Path

import pytest

from legion.core._run import RunResult
from legion.services.installation import _constraints


def test_exports_frozen_mcp_pins(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    pins = "mcp==1.30.1\ncolorama==0.4.6 ; sys_platform == 'win32'\n"

    def fake_uv(command: str, arguments: list[str], *, cwd: Path, timeout: float) -> RunResult:
        assert command == "fake-uv"
        assert cwd == tmp_path
        assert timeout == 60
        assert arguments == ["export", "--frozen", "--no-default-groups", "--extra", "mcp", "--no-emit-project", "--no-hashes"]
        return RunResult(exit_code=0, output=pins, error="", timed_out=False)

    monkeypatch.setattr(_constraints, "run_command", fake_uv)
    assert _constraints.export_constraints(tmp_path, "fake-uv") == pins
