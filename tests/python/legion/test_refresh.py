import json
from pathlib import Path
from types import SimpleNamespace

import pytest

from launcher_fakes import ready_app

from legion import _footprints, _refresh
from legion._home import settings_path
from legion._settings_models import Agent


def test_refresh_writes_missing_foundry_launcher_and_preserves_foreign(tmp_path: Path) -> None:
    home = tmp_path / "home"
    app = home / ".legion" / "app" / "1.0.0"
    app.mkdir(parents=True)
    (app / ".legion-app-ready").touch()
    _footprints.add(home, "app-version", app, "legion")
    path = settings_path(home)
    path.parent.mkdir(parents=True)
    data = {
        "schemaVersion": 1,
        "agents": [
            {
                "id": "claude-a",
                "tool": "claude",
                "configDir": str(home / "config"),
                "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "claude-a", "deployments": [{"name": "claude-a"}]},
            }
        ],
        "channels": [],
    }
    path.write_text(json.dumps(data), encoding="utf-8")
    lines = _refresh.refresh(home)
    assert any(line.startswith("wrote: launcher ") for line in lines)
    launcher = home / ".legion" / "bin" / "claude-a"
    assert "foundry run --account" in launcher.read_text(encoding="utf-8")
    assert _refresh.refresh(home)[-1] == "skip: legion generated runtimes and launchers (already done)"
    launcher.write_text("owner file", encoding="utf-8")
    assert any("wrapper collision" in line for line in _refresh.refresh(home))
    assert launcher.read_text(encoding="utf-8") == "owner file"


def test_refresh_restores_subscription_execute_permission(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    agent = Agent.model_validate({"id": "codex-a", "tool": "codex", "configDir": str(tmp_path / "config")})
    launcher = tmp_path / ".legion" / "bin" / "codex-a"
    settings_path(tmp_path).parent.mkdir(parents=True)
    settings_path(tmp_path).write_text("{}", encoding="utf-8")
    monkeypatch.setattr(_refresh._settings_io, "load", lambda _home: SimpleNamespace(agents=[agent]))
    monkeypatch.setattr(_refresh._launchers, "launcher_state", lambda *_args: "intact")
    monkeypatch.setattr(_refresh._launchers, "restore_execute", lambda *_args: [launcher])
    assert f"wrote: launcher {launcher}" in _refresh.refresh(tmp_path)


def foundry_settings(home: Path, accounts: list[str]) -> None:
    agents = [
        {"id": account, "tool": "claude", "configDir": str(home / account), "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "m", "deployments": [{"name": "m"}]}}
        for account in accounts
    ]
    path = settings_path(home)
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps({"schemaVersion": 1, "agents": agents, "channels": []}), encoding="utf-8")


def test_refresh_with_no_settings_file_does_nothing(tmp_path: Path) -> None:
    assert _refresh.refresh(tmp_path) == ["skip: legion generated runtimes and launchers (already done)"]


def test_refresh_with_a_broken_settings_file_still_fails(tmp_path: Path) -> None:
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_text("{", encoding="utf-8")
    with pytest.raises(_refresh._settings_io.SettingsError):
        _refresh.refresh(tmp_path)


def test_one_foundry_account_that_cannot_be_written_never_stops_the_next(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    foundry_settings(tmp_path, ["claude-a", "claude-b"])
    written: list[str] = []

    def write_foundry(agent: Agent, _home: Path) -> list[Path]:
        if agent.id == "claude-a":
            raise _refresh._launchers.LauncherError("linked wrapper path 'x'")
        written.append(agent.id)
        return [Path(agent.id)]

    monkeypatch.setattr(_refresh._launchers, "write_foundry", write_foundry)
    lines = _refresh.refresh(tmp_path)
    assert "skip: account claude-a (linked wrapper path 'x')" in lines
    assert written == ["claude-b"]
    assert "wrote: launcher claude-b" in lines


def test_refresh_rewrites_an_owned_foundry_launcher_for_a_newer_ready_app(tmp_path: Path) -> None:
    first = ready_app(tmp_path, "1.0.0")
    foundry_settings(tmp_path, ["claude-a"])
    _refresh.refresh(tmp_path)
    launcher = tmp_path / ".legion" / "bin" / "claude-a"
    assert str(first) in launcher.read_text(encoding="utf-8")
    second = ready_app(tmp_path, "2.0.0")
    lines = _refresh.refresh(tmp_path)
    assert any(line.startswith("wrote: launcher ") for line in lines)
    assert str(second) in launcher.read_text(encoding="utf-8")
    assert str(first) not in launcher.read_text(encoding="utf-8")
