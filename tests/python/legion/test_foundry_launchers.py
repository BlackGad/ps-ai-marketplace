import re
import subprocess
import sys
from pathlib import Path

import pytest
from launcher_fakes import ready_app

from legion.services import _launchers
from legion.core._settings_models import Agent

PROVIDER = {"kind": "foundry", "endpoint": "https://example.test", "default": "claude-a", "deployments": [{"name": "claude-a"}]}


def foundry_agent(account: str, folder: Path) -> Agent:
    return Agent.model_validate({"id": account, "tool": "claude", "configDir": str(folder), "provider": PROVIDER})


def program_named_in(text: str) -> Path:
    found = re.search(r"""^@"([^"]+)" --home|^exec '([^']+)' --home""", text, re.MULTILINE)
    assert found is not None
    return Path(found.group(1) or found.group(2))


def test_every_foundry_launcher_names_a_program_that_exists_on_this_system(tmp_path: Path) -> None:
    ready_app(tmp_path)
    plan = _launchers.plan_foundry(foundry_agent("claude-a", tmp_path / "config"), tmp_path)
    assert plan
    for path, text in plan.items():
        assert program_named_in(text).is_file(), f"{path.name} names a missing program"


@pytest.mark.parametrize("windows", [True, False])
def test_foundry_text_form_follows_the_flag_and_forwards_arguments_after_a_separator(windows: bool) -> None:
    text = _launchers.foundry_text("claude-a", Path("/env"), Path("/home"), windows)
    assert ("\r\n" in text) == windows
    assert text.startswith("#!/bin/sh") != windows
    assert (" foundry run --account claude-a -- %*" in text) == windows
    assert (" foundry run --account 'claude-a' -- \"$@\"" in text) != windows


@pytest.mark.skipif(sys.platform == "win32", reason="a Windows launcher needs a real legion.exe")
def test_foundry_launcher_runs_the_app_program_with_arguments_intact(tmp_path: Path) -> None:
    home = tmp_path / "home with space"
    program = ready_app(home)
    program.write_text('#!/bin/sh\nfor a in "$@"; do echo "arg=$a"; done\nexit 3\n', encoding="utf-8")
    program.chmod(0o755)
    _launchers.write_foundry(foundry_agent("claude-a", home / "config"), home)
    result = subprocess.run([str(home / ".legion" / "bin" / "claude-a"), "--help", "two words"], capture_output=True, text=True, check=False)
    assert result.returncode == 3
    expected = ["--home", str(home), "foundry", "run", "--account", "claude-a", "--", "--help", "two words"]
    assert result.stdout.splitlines() == [f"arg={item}" for item in expected]
