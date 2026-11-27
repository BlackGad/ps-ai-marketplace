import json
import os
from pathlib import Path
from typing import Any

import pytest
from app_fakes import FakeUv, make_link, make_source
from launcher_fakes import fake_cli
from settings_fakes import save_settings

from legion.services.installation import _refresh
from legion.services.accounts import _launchers
from legion.services.repository import _footprints
from legion.core import _generated, _settings_io
from legion.core._home import bin_folder, settings_path


# Every test runs against a fake uv, so no test can start the real one.
pytestmark = pytest.mark.usefixtures("uv")


@pytest.fixture
def uv(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> FakeUv:
    return FakeUv(monkeypatch, tmp_path / "uv bin")


# The stock CLIs the accounts start with; an old launcher goes only when its account's program is found.
@pytest.fixture(autouse=True)
def stock_clis(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = tmp_path / "stock bin"
    for name in ("claude", "codex"):
        fake_cli(folder, name)
    monkeypatch.setenv("PATH", os.pathsep.join([str(folder), os.environ.get("PATH", "")]))


def run(home: Path, detached: bool = False) -> list[str]:
    return _refresh.refresh(home, make_source(home.parent / f"source-{home.name}"), detached)


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


def test_refresh_installs_the_tool_and_removes_owned_account_launchers_and_footprints(tmp_path: Path) -> None:
    account_settings(tmp_path, ["codex-a", "claude-a"])
    # A launcher of an account renamed or removed earlier goes too: its header names the file's own account.
    owned = [*old_launchers(tmp_path, "codex-a"), *old_launchers(tmp_path, "claude-a"), *old_launchers(tmp_path, "renamed-a")]
    _footprints.add(tmp_path, "file", owned[0], "account:codex-a")
    lines = run(tmp_path)
    assert "legion command 1.0.0 installed" in lines
    for path in owned:
        assert f"removed {path}" in lines
        assert not path.exists()
    assert not any(entry.path == "~/.legion/bin/codex-a" for entry in _footprints.read(tmp_path).entries)


def test_refresh_skips_unowned_launcher(tmp_path: Path) -> None:
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


def test_refresh_keeps_launchers_behind_a_linked_bin_folder(tmp_path: Path) -> None:
    home = tmp_path / "home"
    elsewhere = tmp_path / "elsewhere"
    old_launchers(elsewhere, "codex-a")
    make_link(bin_folder(home), bin_folder(elsewhere))
    account_settings(home, ["codex-a"])
    lines = _launchers.remove_old_launchers(_settings_io.load(home).agents, home)
    assert lines == []
    assert all(path.is_file() for path in _launchers.launcher_paths("codex-a", elsewhere))


def test_refresh_with_no_settings_file_installs_the_tool_and_a_repeat_skips(tmp_path: Path, uv: FakeUv) -> None:
    assert run(tmp_path)[0] == "legion command 1.0.0 installed"
    assert run(tmp_path) == ["skip: legion command 1.0.0 (already done)"]
    assert len(uv.installs()) == 1


def test_refresh_with_a_broken_settings_file_still_fails_before_uv_runs(tmp_path: Path, uv: FakeUv) -> None:
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_text("{", encoding="utf-8")
    with pytest.raises(_settings_io.SettingsError):
        run(tmp_path)
    assert uv.calls == []


def test_a_linked_legion_folder_is_refused_before_settings_lock(tmp_path: Path, uv: FakeUv) -> None:
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / "home" / ".legion", elsewhere)
    with pytest.raises(_settings_io.SettingsError, match="link"):
        run(tmp_path / "home")
    assert list(elsewhere.iterdir()) == []
    assert uv.calls == []


# The uv step of a detached refresh runs after this process exits, so the tool's legion cannot answer yet.
def test_a_detached_refresh_hands_the_install_over_and_leaves_old_launchers(tmp_path: Path, uv: FakeUv) -> None:
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    lines = run(tmp_path, detached=True)
    assert "legion command 1.0.0 is installed when this command ends" in lines
    assert uv.installs() == []
    assert len(uv.detached) == 1
    assert uv.probes == 0
    assert all(path.is_file() for path in launchers)


def test_refresh_keeps_old_launchers_when_the_tool_cannot_run_accounts(tmp_path: Path, uv: FakeUv) -> None:
    account_settings(tmp_path, ["codex-a"])
    launchers = old_launchers(tmp_path, "codex-a")
    uv.run_help_exit = 2
    lines = run(tmp_path)
    assert all(path.is_file() for path in launchers)
    assert "skip: old account launchers (the legion command cannot start accounts yet)" in lines


# An account whose own command is another account's old launcher, directly or through a linked folder, keeps it.
@pytest.mark.parametrize("through_link", [False, True])
def test_refresh_keeps_an_old_launcher_that_an_account_runs(tmp_path: Path, through_link: bool) -> None:
    account_settings(tmp_path, ["codex-a", "codex-b"])
    launchers = old_launchers(tmp_path, "codex-a")
    folder = bin_folder(tmp_path)
    if through_link:
        make_link(tmp_path / "linked bin", folder)
        folder = tmp_path / "linked bin"
    settings = _settings_io.load(tmp_path)
    settings.agents[1].command = str(folder / launchers[-1].name)
    save_settings(tmp_path, settings)
    lines = run(tmp_path)
    assert f"skip: {launchers[-1]} (account codex-b runs it)" in lines
    assert launchers[-1].is_file()


# The footprint goes before the file, so a failed footprint write leaves the launcher for the next refresh.
def test_a_failed_footprint_removal_keeps_the_launcher(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
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


# The tool's legion is not started when the bin folder holds nothing to clean up.
def test_nothing_to_clean_up_starts_no_probe(tmp_path: Path, uv: FakeUv) -> None:
    account_settings(tmp_path, ["codex-a"])
    run(tmp_path)
    assert uv.probes == 0
