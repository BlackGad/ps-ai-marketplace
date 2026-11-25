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
    monkeypatch.setenv("LEGION_UV_COPY", "callers value")
    seen: list[tuple[Path, Path, list[str]]] = []

    def run(command: list[str], *, env: dict[str, str], check: bool) -> subprocess.CompletedProcess[str]:
        assert check is False
        assert command[0] == "uv"
        project = Path(command[command.index("--project") + 1])
        seen.append((project, Path(env["UV_PROJECT_ENVIRONMENT"]), command))
        # uv's own lock files go to the temporary folder; keeping it in the scratch folder removes them too.
        assert Path(env["TEMP"]) == Path(env["TMP"]) == project.parent / "temp"
        assert Path(env["TEMP"]).is_dir()
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
    # Uninstall needs only the CLI; the default group would also install the MCP SDK into the throwaway copy.
    assert "--no-default-groups" in command[: command.index("legion")]
    assert not app.exists()


def test_self_uninstall_uses_the_explicit_temporary_uv_for_inner_cleanup(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    app = tmp_path / "home/.legion/app/1.2.3"
    app.mkdir(parents=True)
    temporary_uv = tmp_path / "temporary-uv.exe"
    temporary_uv.write_bytes(b"fake")
    monkeypatch.setenv("LEGION_UV_COPY", "callers value")
    monkeypatch.setenv("UV_PROJECT_ENVIRONMENT", "callers environment")
    commands: list[list[str]] = []

    def run(command: list[str], *, env: dict[str, str], check: bool) -> subprocess.CompletedProcess[str]:
        commands.append(command)
        assert env["LEGION_UV_COPY"] == "callers value"
        assert env["UV_PROJECT_ENVIRONMENT"] != "callers environment"
        assert check is False
        return subprocess.CompletedProcess(command, 7)

    monkeypatch.setattr(_self_uninstall.subprocess, "run", run)
    assert _self_uninstall.run(app, ["uninstall", "--purge", "--yes"], temporary_uv) == 7
    assert commands[0][0] == str(temporary_uv)
    assert temporary_uv.exists()
    assert not Path(commands[0][commands[0].index("--project") + 1]).exists()
    assert _self_uninstall.os.environ["UV_PROJECT_ENVIRONMENT"] == "callers environment"
