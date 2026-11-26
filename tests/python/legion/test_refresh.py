import json
import os
from collections.abc import Callable
from pathlib import Path
from typing import Any

import pytest
from app_fakes import (
    MARKER,
    VERSION,
    FakeUv,
    make_link,
    make_source,
    old_app,
)
from filelock import FileLock
from launcher_fakes import fake_cli, ready_app

from legion.services.installation import _installed_runtime, _refresh
from legion.services.accounts import _launchers
from legion.services.repository import _footprints
from legion.core import _generated, _settings_io
from legion.core._home import bin_folder, settings_path

REFRESHED = "legion generated runtimes and launchers refreshed"
UNCHANGED = "skip: legion generated runtimes and launchers (already done)"

# Every test runs against a fake uv, so no test can start the real one.
pytestmark = pytest.mark.usefixtures("uv")


@pytest.fixture
def uv(monkeypatch: pytest.MonkeyPatch) -> FakeUv:
    return FakeUv(monkeypatch)


# The stock CLIs the accounts start with; an old launcher goes only when its account's program is found.
@pytest.fixture(autouse=True)
def stock_clis(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = tmp_path / "stock bin"
    for name in ("claude", "codex"):
        fake_cli(folder, name)
    monkeypatch.setenv("PATH", os.pathsep.join([str(folder), os.environ.get("PATH", "")]))


def run(home: Path, source: Path | None = None, lock_timeout: float = 60) -> list[str]:
    return _refresh.refresh(home, source or make_source(home.parent / f"source-{home.name}"), lock_timeout)


FOUNDRY = {"kind": "foundry", "endpoint": "https://example.test", "default": "m", "deployments": [{"name": "m"}]}


# claude-* accounts are Foundry accounts, the others subscription accounts.
def account_settings(home: Path, accounts: list[str]) -> None:
    agents: list[dict[str, Any]] = [{"id": account, "tool": "codex", "configDir": str(home / account)} for account in accounts]
    for entry in agents:
        if entry["id"].startswith("claude"):
            entry.update(tool="claude", provider=FOUNDRY)
    path = settings_path(home)
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps({"schemaVersion": 1, "agents": agents, "channels": []}), encoding="utf-8")


# A launcher as an older legion wrote it: the ownership header names the account it is called after.
def old_launchers(home: Path, account: str) -> list[Path]:
    paths = _launchers.launcher_paths(account, home)
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix == ".cmd":
            text = _generated.header(f"account {account}", True) + "\r\n@exit /b 0\r\n"
        else:
            text = "#!/bin/sh\n" + _generated.header(f"account {account}", False) + "\nexec old-command\n"
        path.write_text(text, encoding="utf-8", newline="")
    return paths


def snapshot(home: Path) -> dict[str, bytes | None]:
    return {str(path.relative_to(home)): (path.read_bytes() if path.is_file() else None) for path in sorted(home.rglob("*"))}


def test_refresh_removes_owned_account_launchers_and_footprints(tmp_path: Path) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a", "claude-a"])
    # A launcher of an account renamed or removed earlier goes too: its header names the file's own account.
    owned = [*old_launchers(tmp_path, "codex-a"), *old_launchers(tmp_path, "claude-a"), *old_launchers(tmp_path, "renamed-a")]
    _footprints.add(tmp_path, "file", owned[0], "account:codex-a")
    lines = run(tmp_path)
    for path in owned:
        assert f"removed {path}" in lines
        assert not path.exists()
    assert not any(entry.path == "~/.legion/bin/codex-a" for entry in _footprints.read(tmp_path).entries)
    assert lines[-1] == REFRESHED


def test_refresh_skips_unowned_launcher(tmp_path: Path) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a", "codex-b"])
    foreign = bin_folder(tmp_path) / "codex-a"
    foreign.parent.mkdir(parents=True)
    foreign.write_text("#!/bin/sh\nowner file\n", encoding="utf-8")
    # A legion header for another account is not this file's own.
    other = bin_folder(tmp_path) / "codex-b"
    other.write_text("#!/bin/sh\n" + _generated.header("account codex-a", False) + "\n", encoding="utf-8")
    # A file under an id that is no longer configured is reported too.
    former = bin_folder(tmp_path) / "former-a"
    former.write_text("#!/bin/sh\nowner file\n", encoding="utf-8")
    lines = run(tmp_path)
    assert f"skip: {foreign} (not legion's)" in lines
    assert f"skip: {other} (not legion's)" in lines
    assert f"skip: {former} (not legion's)" in lines
    assert foreign.read_text(encoding="utf-8") == "#!/bin/sh\nowner file\n"
    assert other.is_file()


def test_refresh_repeat_prints_skip(tmp_path: Path) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a"])
    old_launchers(tmp_path, "codex-a")
    assert run(tmp_path)[-1] == REFRESHED
    again = run(tmp_path)
    assert not any(line.startswith("removed ") for line in again)
    assert again[-1] == UNCHANGED


def test_refresh_keeps_launchers_behind_a_linked_bin_folder(tmp_path: Path) -> None:
    home = tmp_path / "home"
    elsewhere = tmp_path / "elsewhere"
    old_launchers(elsewhere, "codex-a")
    make_link(bin_folder(home), bin_folder(elsewhere))
    account_settings(home, ["codex-a"])
    lines = _launchers.remove_old_launchers(_settings_io.load(home).agents, home)
    assert lines == []
    assert all(path.is_file() for path in _launchers.launcher_paths("codex-a", elsewhere))


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


def test_refresh_publishes_then_removes_launchers_and_prunes_in_order(tmp_path: Path, uv: FakeUv, monkeypatch: pytest.MonkeyPatch) -> None:
    old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    account_settings(tmp_path, ["claude-a"])
    order: list[str] = []

    def recorded(name: str, real: Callable[..., Any]) -> Callable[..., Any]:
        def call(*arguments: Any, **keywords: Any) -> Any:
            order.append(name)
            return real(*arguments, **keywords)

        return call

    monkeypatch.setattr(_refresh._launchers, "remove_old_launchers", recorded("launchers", _launchers.remove_old_launchers))
    monkeypatch.setattr(_refresh._installed_runtime, "sync_app", recorded("sync", _installed_runtime.sync_app))
    monkeypatch.setattr(_refresh._installed_runtime, "write_owner_commands", recorded("commands", _installed_runtime.write_owner_commands))
    monkeypatch.setattr(_refresh._installed_runtime, "prune_old_versions", recorded("prune", _installed_runtime.prune_old_versions))
    lines = run(tmp_path)
    assert order == ["sync", "commands", "launchers", "prune"]
    assert "removed legion app 0.0.1" in lines
    assert len(uv.calls) == 1


def test_refresh_twice_leaves_the_home_tree_unchanged(tmp_path: Path) -> None:
    home = tmp_path / "home"
    old_app(home, "0.0.1")
    account_settings(home, ["claude-a", "codex-a"])
    old_launchers(home, "codex-a")
    source = make_source(tmp_path)
    assert run(home, source=source)[-1] == REFRESHED
    after_first = snapshot(home)
    assert run(home, source=source)[-1] == UNCHANGED
    assert snapshot(home) == after_first


def test_a_busy_sync_lock_skips_the_app(tmp_path: Path, uv: FakeUv) -> None:
    ready_app(tmp_path, "1.0.0")
    account_settings(tmp_path, ["claude-a"])
    run(tmp_path)
    uv.calls.clear()
    ready_app(tmp_path, "2.0.0")
    with FileLock(str(tmp_path / ".legion" / "app" / ".sync.lock")):
        lines = run(tmp_path, lock_timeout=0)
    assert "skip: legion app sync (another sync is still running; run legion setup again)" in lines
    assert lines[-1] == UNCHANGED
    assert uv.calls == []


def test_a_failed_sync_leaves_the_commands_as_they_are(tmp_path: Path, uv: FakeUv) -> None:
    account_settings(tmp_path, ["claude-a"])
    uv.exit_code = 3
    lines = run(tmp_path)
    assert f"legion app {VERSION} not ready (uv sync exited 3); run legion setup again" in lines
    assert "skip: command legion (the legion app is not ready)" in lines
    assert not (tmp_path / ".legion" / "bin").exists()
    assert not (tmp_path / ".legion" / "app" / VERSION / MARKER).exists()


# Without the legion command that replaces them, the old launchers are the only way to start the accounts, so they stay.
def test_refresh_keeps_old_launchers_until_the_legion_command_is_in_place(tmp_path: Path, uv: FakeUv) -> None:
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    uv.exit_code = 3
    lines = run(tmp_path)
    assert not any(line.startswith("removed ") for line in lines)
    assert all(path.is_file() for path in launchers)


# An account whose program cannot be found keeps its old launcher until the owner fixes it; the reason is printed.
def test_refresh_keeps_the_old_launcher_of_an_account_without_a_program(tmp_path: Path) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a"])
    settings = _settings_io.load(tmp_path)
    settings.agents[0].command = str(tmp_path / "gone-codex")
    _settings_io.save(tmp_path, settings)
    launchers = old_launchers(tmp_path, "codex-a")
    lines = run(tmp_path)
    for path in launchers:
        assert f"skip: {path} (target needed: codex-a; ask the owner for the registered executable)" in lines
        assert path.is_file()


def test_a_linked_app_folder_is_refused_before_anything_is_written(tmp_path: Path) -> None:
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / "home" / ".legion" / "app", elsewhere)
    with pytest.raises(_installed_runtime.AppError, match="link"):
        run(tmp_path / "home")
    assert list(elsewhere.iterdir()) == []


def test_a_linked_legion_folder_is_refused_before_settings_lock(tmp_path: Path) -> None:
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / "home" / ".legion", elsewhere)
    with pytest.raises((_installed_runtime.AppError, _settings_io.SettingsError), match="link"):
        run(tmp_path / "home")
    assert list(elsewhere.iterdir()) == []


def kept(lines: list[str], launchers: list[Path]) -> bool:
    return all(path.is_file() for path in launchers) and not any(line.startswith("removed ") and "bin" in line for line in lines)


# A failed upgrade leaves the older app in place; one without `legion run` cannot replace the launchers.
def test_refresh_keeps_old_launchers_when_the_upgrade_fails_and_the_old_app_has_no_run(tmp_path: Path, uv: FakeUv) -> None:
    old_app(tmp_path, "0.0.1")
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    uv.exit_code = 3
    lines = run(tmp_path)
    assert kept(lines, launchers)
    assert "skip: command legion (the legion app is not ready)" not in lines
    assert "skip: old account launchers (the legion command cannot start accounts yet)" in lines


# An owner command that is not legion's blocks that entry point, so the launchers it would replace stay.
def test_refresh_keeps_old_launchers_behind_a_foreign_owner_command(tmp_path: Path) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    foreign = bin_folder(tmp_path) / "legion"
    foreign.write_text("#!/bin/sh\nowner file\n", encoding="utf-8")
    lines = run(tmp_path)
    assert kept(lines, launchers)
    assert foreign.read_text(encoding="utf-8") == "#!/bin/sh\nowner file\n"
    assert "skip: old account launchers (the legion command cannot start accounts yet)" in lines


# An account whose own command is another account's old launcher, directly or through a linked folder, keeps it.
@pytest.mark.parametrize("through_link", [False, True])
def test_refresh_keeps_an_old_launcher_that_an_account_runs(tmp_path: Path, through_link: bool) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a", "codex-b"])
    launchers = old_launchers(tmp_path, "codex-a")
    folder = bin_folder(tmp_path)
    if through_link:
        make_link(tmp_path / "linked bin", folder)
        folder = tmp_path / "linked bin"
    settings = _settings_io.load(tmp_path)
    settings.agents[1].command = str(folder / launchers[-1].name)
    _settings_io.save(tmp_path, settings)
    lines = run(tmp_path)
    assert f"skip: {launchers[-1]} (account codex-b runs it)" in lines
    assert launchers[-1].is_file()


# The footprint goes before the file, so a failed footprint write leaves the launcher for the next refresh.
def test_a_failed_footprint_removal_keeps_the_launcher(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    real = _launchers._footprints.remove_entry
    busy = [True]

    def remove_entry(*arguments: Any) -> None:
        if busy:
            raise _footprints.FootprintError("footprint lock busy")
        real(*arguments)

    monkeypatch.setattr(_launchers._footprints, "remove_entry", remove_entry)
    with pytest.raises(_footprints.FootprintError):
        run(tmp_path)
    assert launchers[0].is_file()
    busy.clear()
    assert f"removed {launchers[0]}" in run(tmp_path)


# An account registered while the app syncs is seen: cleanup reads the settings again under their lock.
def test_a_registration_during_the_sync_keeps_the_launcher_it_names(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a", "codex-b"])
    launchers = old_launchers(tmp_path, "codex-a")
    real = _installed_runtime.write_owner_commands

    def register(app: Path, home: Path) -> list[Path]:
        settings = _settings_io.load(home)
        settings.agents[1].command = str(launchers[-1])
        _settings_io.save(home, settings)
        return real(app, home)

    monkeypatch.setattr(_refresh._installed_runtime, "write_owner_commands", register)
    lines = run(tmp_path)
    assert f"skip: {launchers[-1]} (account codex-b runs it)" in lines
    assert launchers[-1].is_file()


# The ready app's own legion must answer `run --help` before the launchers it replaces go.
def test_refresh_keeps_old_launchers_when_the_app_cannot_run_accounts(tmp_path: Path, uv: FakeUv) -> None:
    ready_app(tmp_path)
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    uv.run_help_exit = 2
    lines = run(tmp_path)
    assert kept(lines, launchers)
    assert "skip: old account launchers (the legion command cannot start accounts yet)" in lines


# A failed sync falls back to the older app whatever its diagnostics say, so nothing is removed against it.
def test_a_failed_sync_whose_message_ends_in_ready_keeps_the_launchers(tmp_path: Path, uv: FakeUv) -> None:
    old_app(tmp_path, "0.0.1")
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    uv.exit_code = 3
    uv.error = "resolver ready"
    lines = run(tmp_path)
    assert "resolver ready" in lines
    assert kept(lines, launchers)


# A kept Foundry launcher runs its own version's legion, so older apps stay through two upgrades in a row.
def test_older_apps_stay_through_two_upgrades_while_an_old_foundry_launcher_stays(tmp_path: Path) -> None:
    old, environment = old_app(tmp_path, "0.0.1")
    account_settings(tmp_path, ["claude-a", "codex-b"])
    launchers = old_launchers(tmp_path, "claude-a")
    settings = _settings_io.load(tmp_path)
    settings.agents[1].command = str(launchers[-1])
    _settings_io.save(tmp_path, settings)
    for version in ("1.0.0", "2.0.0"):
        lines = run(tmp_path, source=make_source(tmp_path / f"source {version}", version))
        assert f"legion app {version} ready" in lines
        assert "skip: pruning older legion apps (an old account launcher may still run one)" in lines
    assert old.is_dir()
    assert environment.is_dir()
    assert launchers[-1].is_file()
