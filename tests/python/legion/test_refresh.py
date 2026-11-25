import json
from collections.abc import Callable
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest
from app_fakes import MARKER, VERSION, FakeUv, make_link, make_source, old_app
from filelock import FileLock
from launcher_fakes import ready_app

from legion.services import _app, _launchers, _refresh
from legion.core import _settings_io
from legion.core._home import settings_path
from legion.core._settings_models import Agent

REFRESHED = "legion generated runtimes and launchers refreshed"
UNCHANGED = "skip: legion generated runtimes and launchers (already done)"

# Every test runs against a fake uv, so no test can start the real one.
pytestmark = pytest.mark.usefixtures("uv")


@pytest.fixture
def uv(monkeypatch: pytest.MonkeyPatch) -> FakeUv:
    return FakeUv(monkeypatch)


def run(home: Path, source: Path | None = None, lock_timeout: float = 60) -> list[str]:
    return _refresh.refresh(home, source or make_source(home.parent / f"source-{home.name}"), lock_timeout)


def foundry_settings(home: Path, accounts: list[str]) -> None:
    agents = [
        {"id": account, "tool": "claude", "configDir": str(home / account), "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "m", "deployments": [{"name": "m"}]}}
        for account in accounts
    ]
    path = settings_path(home)
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps({"schemaVersion": 1, "agents": agents, "channels": []}), encoding="utf-8")


def snapshot(home: Path) -> dict[str, bytes | None]:
    return {str(path.relative_to(home)): (path.read_bytes() if path.is_file() else None) for path in sorted(home.rglob("*"))}


def test_refresh_writes_missing_foundry_launcher_and_preserves_foreign(tmp_path: Path) -> None:
    home = tmp_path / "home"
    ready_app(home)
    foundry_settings(home, ["claude-a"])
    lines = run(home)
    assert any(line.startswith("wrote: launcher ") for line in lines)
    launcher = home / ".legion" / "bin" / "claude-a"
    assert "foundry run --account" in launcher.read_text(encoding="utf-8")
    assert run(home)[-1] == UNCHANGED
    launcher.write_text("owner file", encoding="utf-8")
    assert any("wrapper collision" in line for line in run(home))
    assert launcher.read_text(encoding="utf-8") == "owner file"


def test_refresh_restores_subscription_execute_permission(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    agent = Agent.model_validate({"id": "codex-a", "tool": "codex", "configDir": str(tmp_path / "config")})
    launcher = tmp_path / ".legion" / "bin" / "codex-a"
    settings_path(tmp_path).parent.mkdir(parents=True)
    settings_path(tmp_path).write_text("{}", encoding="utf-8")
    monkeypatch.setattr(_refresh._settings_io, "load", lambda _home: SimpleNamespace(agents=[agent]))
    monkeypatch.setattr(_refresh._launchers, "launcher_state", lambda *_args: "intact")
    monkeypatch.setattr(_refresh._launchers, "restore_execute", lambda *_args: [launcher])
    assert f"wrote: launcher {launcher}" in run(tmp_path)


def test_refresh_with_no_settings_file_publishes_the_app_and_then_does_nothing(tmp_path: Path) -> None:
    ready_app(tmp_path)
    assert run(tmp_path)[-1] == REFRESHED
    assert run(tmp_path) == [f"skip: legion app {VERSION} (already done)", UNCHANGED]


def test_refresh_with_a_broken_settings_file_still_fails(tmp_path: Path) -> None:
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_text("{", encoding="utf-8")
    with pytest.raises(_refresh._settings_io.SettingsError):
        run(tmp_path)


def test_one_foundry_account_that_cannot_be_written_never_stops_the_next(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    ready_app(tmp_path)
    foundry_settings(tmp_path, ["claude-a", "claude-b"])
    written: list[str] = []

    def write_foundry(agent: Agent, _home: Path) -> list[Path]:
        if agent.id == "claude-a":
            raise _refresh._launchers.LauncherError("linked wrapper path 'x'")
        written.append(agent.id)
        return [Path(agent.id)]

    monkeypatch.setattr(_refresh._launchers, "write_foundry", write_foundry)
    lines = run(tmp_path)
    assert "skip: account claude-a (linked wrapper path 'x')" in lines
    assert written == ["claude-b"]
    assert "wrote: launcher claude-b" in lines


def test_refresh_rewrites_an_owned_foundry_launcher_for_a_newer_ready_app(tmp_path: Path) -> None:
    source = make_source(tmp_path, "1.0.0")
    first = ready_app(tmp_path, "1.0.0")
    foundry_settings(tmp_path, ["claude-a"])
    run(tmp_path, source=source)
    launcher = tmp_path / ".legion" / "bin" / "claude-a"
    assert str(first) in launcher.read_text(encoding="utf-8")
    second = ready_app(tmp_path, "2.0.0")
    lines = run(tmp_path, source=source)
    assert any(line.startswith("wrote: launcher ") for line in lines)
    assert str(second) in launcher.read_text(encoding="utf-8")
    assert str(first) not in launcher.read_text(encoding="utf-8")


def test_refresh_does_the_steps_in_order_so_launchers_move_before_the_old_version_goes(tmp_path: Path, uv: FakeUv, monkeypatch: pytest.MonkeyPatch) -> None:
    old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    foundry_settings(tmp_path, ["claude-a"])
    order: list[str] = []

    def recorded(name: str, real: Callable[..., Any]) -> Callable[..., Any]:
        def call(*arguments: Any, **keywords: Any) -> Any:
            order.append(name)
            return real(*arguments, **keywords)

        return call

    monkeypatch.setattr(_refresh._app, "sync_app", recorded("sync", _app.sync_app))
    monkeypatch.setattr(_refresh._app, "write_owner_commands", recorded("commands", _app.write_owner_commands))
    monkeypatch.setattr(_refresh._launchers, "write_foundry", recorded("foundry", _refresh._launchers.write_foundry))
    monkeypatch.setattr(_refresh._app, "prune_old_versions", recorded("prune", _app.prune_old_versions))
    lines = run(tmp_path)
    assert order == ["sync", "commands", "foundry", "prune"]
    assert "removed legion app 0.0.1" in lines
    new = tmp_path / ".legion" / "app" / VERSION
    launcher = (tmp_path / ".legion" / "bin" / "claude-a").read_text(encoding="utf-8")
    assert str(_app.python_environment(new, tmp_path)) in launcher
    assert len(uv.calls) == 1


def test_refresh_twice_leaves_the_home_tree_unchanged(tmp_path: Path) -> None:
    home = tmp_path / "home"
    old_app(home, "0.0.1")
    foundry_settings(home, ["claude-a"])
    source = make_source(tmp_path)
    assert run(home, source=source)[-1] == REFRESHED
    after_first = snapshot(home)
    assert run(home, source=source)[-1] == UNCHANGED
    assert snapshot(home) == after_first


def test_a_busy_sync_lock_skips_the_app_and_leaves_the_launchers_as_they_are(tmp_path: Path, uv: FakeUv) -> None:
    ready_app(tmp_path, "1.0.0")
    foundry_settings(tmp_path, ["claude-a"])
    run(tmp_path)
    launcher = tmp_path / ".legion" / "bin" / "claude-a"
    before = launcher.read_text(encoding="utf-8")
    uv.calls.clear()
    ready_app(tmp_path, "2.0.0")
    with FileLock(str(tmp_path / ".legion" / "app" / ".sync.lock")):
        lines = run(tmp_path, lock_timeout=0)
    assert "skip: legion app sync (another sync is still running; run legion setup again)" in lines
    assert not any(line.startswith("wrote:") for line in lines)
    assert uv.calls == []
    assert launcher.read_text(encoding="utf-8") == before


def test_a_failed_sync_leaves_the_commands_and_launchers_as_they_are(tmp_path: Path, uv: FakeUv) -> None:
    foundry_settings(tmp_path, ["claude-a"])
    uv.exit_code = 3
    lines = run(tmp_path)
    assert f"legion app {VERSION} not ready (uv sync exited 3); run legion setup again" in lines
    assert "skip: command legion (the legion app is not ready)" in lines
    assert "skip: account claude-a (the legion app is not ready)" in lines
    assert not (tmp_path / ".legion" / "bin").exists()
    assert not (tmp_path / ".legion" / "app" / VERSION / MARKER).exists()


def test_failed_first_upgrade_keeps_a_working_old_foundry_launcher(tmp_path: Path, uv: FakeUv) -> None:
    old_app(tmp_path, "0.15.0")
    foundry_settings(tmp_path, ["claude-a"])
    launcher = tmp_path / ".legion" / "bin" / "claude-a"
    launcher.parent.mkdir(parents=True)
    launcher.write_text("#!/bin/sh\n# Generated by legion: account claude-a\nexec old-foundry-command\n", encoding="utf-8")
    before = launcher.read_bytes()
    uv.exit_code = 3
    run(tmp_path)
    assert launcher.read_bytes() == before


def test_refresh_uses_current_settings_after_sync(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    ready_app(tmp_path)
    foundry_settings(tmp_path, ["claude-a"])
    real = _app.sync_app

    def remove_during_sync(home: Path, source: Path) -> tuple[list[str], Path | None]:
        with _settings_io.writer(home):
            settings = _settings_io.load(home)
            settings.agents.clear()
            _settings_io.save_locked(home, settings)
        return real(home, source)

    monkeypatch.setattr(_refresh._app, "sync_app", remove_during_sync)
    run(tmp_path)
    assert not (tmp_path / ".legion" / "bin" / "claude-a").exists()


def test_refresh_rewrites_an_owned_launcher_for_explicit_command(tmp_path: Path) -> None:
    ready_app(tmp_path)
    command = tmp_path / "custom-command"
    command.write_text("tool", encoding="utf-8")
    agent = {"id": "codex-a", "tool": "codex", "configDir": str(tmp_path / "config"), "command": str(command)}
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps({"schemaVersion": 1, "agents": [agent], "channels": []}), encoding="utf-8")
    for launcher in _launchers.launcher_paths("codex-a", tmp_path):
        launcher.parent.mkdir(parents=True, exist_ok=True)
        header = "@rem" if launcher.suffix == ".cmd" else "#!/bin/sh\n#"
        launcher.write_text(f"{header} Generated by legion: account codex-a\nold-command\n", encoding="utf-8")
    launcher = _launchers.launcher_paths("codex-a", tmp_path)[0]
    run(tmp_path)
    assert str(command) in launcher.read_text(encoding="utf-8")


def test_a_linked_app_folder_is_refused_before_anything_is_written(tmp_path: Path) -> None:
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / "home" / ".legion" / "app", elsewhere)
    with pytest.raises(_app.AppError, match="link"):
        run(tmp_path / "home")
    assert list(elsewhere.iterdir()) == []


def test_a_linked_legion_folder_is_refused_before_settings_lock(tmp_path: Path) -> None:
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / "home" / ".legion", elsewhere)
    with pytest.raises((_app.AppError, _settings_io.SettingsError), match="link"):
        run(tmp_path / "home")
    assert list(elsewhere.iterdir()) == []


def test_refresh_repairs_subscription_launchers_before_the_app_is_published(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    ready_app(tmp_path)
    foundry_settings(tmp_path, [])
    order: list[str] = []
    real = _app.sync_app

    def sync(*arguments: Any, **keywords: Any) -> Any:
        order.append("sync")
        return real(*arguments, **keywords)

    monkeypatch.setattr(_refresh._app, "sync_app", sync)
    monkeypatch.setattr(_refresh, "_repair_subscription", lambda *_arguments: order.append("repair") or [])
    settings_path(tmp_path).write_text(json.dumps({"schemaVersion": 1, "agents": [{"id": "codex-a", "tool": "codex", "configDir": str(tmp_path / "c")}], "channels": []}), encoding="utf-8")
    run(tmp_path)
    assert order == ["repair", "sync"]
