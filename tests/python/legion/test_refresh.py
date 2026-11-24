import json
from pathlib import Path
from types import SimpleNamespace

import pytest

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
    monkeypatch.setattr(_refresh._settings_io, "load", lambda _home: SimpleNamespace(agents=[agent]))
    monkeypatch.setattr(_refresh._launchers, "launcher_state", lambda *_args: "intact")
    monkeypatch.setattr(_refresh._launchers, "restore_execute", lambda *_args: [launcher])
    assert f"wrote: launcher {launcher}" in _refresh.refresh(tmp_path)
