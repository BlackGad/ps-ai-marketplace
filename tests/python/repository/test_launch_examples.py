import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

import pytest
from conftest import REPO

WORKER_ARGS = {
    "claude": ["-p", "--permission-mode", "bypassPermissions", "--strict-mcp-config"],
    "codex": ["exec", "--dangerously-bypass-approvals-and-sandbox", "-C", "repo with spaces", "-o", "report with spaces.last.md", "-"],
    "copilot": ["-p", "Read and follow the task in task prompt with spaces.md.", "-s", "--allow-all-tools", "--deny-tool=shell(git push)"],
}


@pytest.mark.parametrize(("tool", "args"), WORKER_ARGS.items(), ids=WORKER_ARGS)
def test_documented_worker_passes_complete_argv(tool: str, args: list[str], pwsh_path: Path, tmp_path: Path) -> None:
    reference = (REPO / f"plugins/legion/skills/legion-{tool}/references/run.md").read_text(encoding="utf-8")
    example = re.search(r"(?s)```powershell\n(.*?)\n```", reference)
    assert example, f"{tool} needs a PowerShell worker example"

    recorder = tmp_path / "record args.py"
    recorder.write_text(
        "import json, sys\nfrom pathlib import Path\nPath('args.json').write_text(json.dumps(sys.argv[1:]), encoding='utf-8')\n",
        encoding="utf-8",
    )
    # Use a native command boundary so PowerShell forwards the literal --.
    if os.name == "nt":
        legion = tmp_path / "legion.cmd"
        legion.write_text(f'@"{sys.executable}" "{recorder}" %*\n', encoding="utf-8")
    else:
        legion = tmp_path / "legion"
        legion.write_text(f'#!/bin/sh\nexec {shlex.quote(sys.executable)} {shlex.quote(str(recorder))} "$@"\n', encoding="utf-8")
        legion.chmod(0o755)
    setup = """
$ErrorActionPreference = 'Stop'
$legionHome = 'legion home'
$account = 'codex-a'
$repoPath = 'repo with spaces'
$report = 'report with spaces'
$promptText = "task`nwith lines"
$promptPath = 'task prompt with spaces.md'
"""
    result = subprocess.run(
        [str(pwsh_path), "-NoProfile", "-NonInteractive", "-Command", setup + example[1]],
        cwd=tmp_path,
        env={**os.environ, "PATH": str(tmp_path) + os.pathsep + os.environ["PATH"]},
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stderr
    assert json.loads((tmp_path / "args.json").read_text(encoding="utf-8")) == ["--home", "legion home", "run", "--account", "codex-a", "--", *args]
    if tool != "codex":
        assert (tmp_path / "report with spaces.stdout.md").is_file()
