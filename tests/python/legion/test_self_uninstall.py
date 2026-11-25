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


def test_self_uninstall_uses_the_shims_temporary_uv_for_inner_cleanup(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app = tmp_path / "home/.legion/app/1.2.3"
    app.mkdir(parents=True)
    temporary_uv = tmp_path / "temporary-uv.exe"
    temporary_uv.write_bytes(b"fake")
    monkeypatch.setenv("LEGION_UV_COPY", str(temporary_uv))
    monkeypatch.setenv("UV_PROJECT_ENVIRONMENT", "callers environment")
    commands: list[list[str]] = []

    def run(command: list[str], *, env: dict[str, str], check: bool) -> subprocess.CompletedProcess[str]:
        commands.append(command)
        assert env["LEGION_UV_COPY"] == str(temporary_uv)
        assert env["UV_PROJECT_ENVIRONMENT"] != "callers environment"
        assert check is False
        return subprocess.CompletedProcess(command, 7)

    monkeypatch.setattr(_self_uninstall.subprocess, "run", run)
    assert _self_uninstall.run(app, ["uninstall", "--purge", "--yes"]) == 7
    assert commands[0][0] == str(temporary_uv)
    assert temporary_uv.exists()
    assert not Path(commands[0][commands[0].index("--project") + 1]).exists()
    assert _self_uninstall.os.environ["UV_PROJECT_ENVIRONMENT"] == "callers environment"
