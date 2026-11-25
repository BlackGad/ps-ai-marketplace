import shutil
import subprocess
from pathlib import Path

import pytest

from legion import _self_uninstall


def test_self_uninstall_runs_a_copy_outside_the_app(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    app = home / ".legion/app/1.2.3"
    app.mkdir(parents=True)
    (app / "pyproject.toml").write_text("[project]\nname='legion'\nversion='1.2.3'\n", encoding="utf-8")
    seen: list[tuple[Path, Path, list[str]]] = []

    def run(command: list[str], *, env: dict[str, str], check: bool) -> subprocess.CompletedProcess[str]:
        assert check is False
        project = Path(command[command.index("--project") + 1])
        seen.append((project, Path(env["UV_PROJECT_ENVIRONMENT"]), command))
        assert project != app
        assert (project / "pyproject.toml").is_file()
        shutil.rmtree(app)
        return subprocess.CompletedProcess(command, 0)

    monkeypatch.setattr(_self_uninstall.subprocess, "run", run)
    assert _self_uninstall.run(app, ["uninstall", "--yes"]) == 0
    project, environment, command = seen[0]
    assert not project.exists()
    assert not environment.exists()
    assert command[-4:] == ["--home", str(home), "uninstall", "--yes"]
    assert not app.exists()
