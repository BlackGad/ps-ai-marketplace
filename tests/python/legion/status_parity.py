import json
import shutil
import subprocess
from pathlib import Path

import pytest


def status_home(tmp_path: Path) -> tuple[Path, Path]:
    home = tmp_path / "home"
    repo = tmp_path / "repo"
    settings = home / ".legion/configuration/personalisation.json"
    settings.parent.mkdir(parents=True)
    settings.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "agents": [{"id": "claude-a", "tool": "claude", "configDir": "~/.claude"}, {"id": "codex-a", "tool": "codex", "configDir": "~/.codex"}],
                "channels": [{"id": "main", "kind": "telegram", "target": "123", "accounts": ["claude-a"]}],
            }
        ),
        encoding="utf-8",
    )
    paths = [".legion/configuration/project.json", ".legion/configuration/workflow.md", ".legion/scripts/index.md", ".legion/state/handoff.md"]
    for name in paths:
        path = repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture", encoding="utf-8")
    git = shutil.which("git")
    assert git is not None
    for words in (["init", "--quiet"], ["add", "--", *paths]):
        result = subprocess.run([git, "-C", str(repo), *words], capture_output=True, check=False)
        assert result.returncode == 0, result.stderr
    return repo, home


@pytest.fixture
def parity_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> tuple[Path, Path]:
    repo, home = status_home(tmp_path)
    monkeypatch.chdir(repo)
    for name in ("CLAUDE_CONFIG_DIR", "CODEX_HOME", "COPILOT_HOME"):
        monkeypatch.delenv(name, raising=False)
    return repo, home
