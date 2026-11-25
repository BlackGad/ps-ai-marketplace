import json
import os
import sys
import threading
import time
import traceback
from typing import Self
from pathlib import Path

import pytest
from click.testing import CliRunner

from legion import _app, _cli, _footprints, _forward, _installer
from legion._generated import header
from legion._run import RunResult

if os.name == "nt":
    import _winapi


def catalog() -> dict:
    return json.loads((Path(__file__).resolve().parents[3] / "plugins/legion/tools.json").read_text(encoding="utf-8"))


def test_purge_preview_keeps_home_and_outside_files(tmp_path: Path) -> None:
    home = tmp_path / "home"
    login = home / ".legion/agents/codex-a/auth.json"
    login.parent.mkdir(parents=True)
    login.write_text("secret", encoding="utf-8")
    outside = tmp_path / "outside.txt"
    outside.write_text("keep", encoding="utf-8")
    plan = _installer.purge_plan(home, catalog())
    assert any(str(home / ".legion") in line for line in plan.lines)
    assert login.exists()
    assert outside.read_text(encoding="utf-8") == "keep"


def test_purge_refuses_changed_footprints_after_preview(tmp_path: Path) -> None:
    home = tmp_path / "home"
    _footprints.add(home, "path-entry", "user PATH", "legion", value=str(home / ".legion/bin"))
    plan = _installer.purge_plan(home, catalog())
    _footprints.add(home, "edit", home / ".legion/notes.md", "new-owner")
    with pytest.raises(_installer.InstallerError, match="records changed after preview"):
        _installer.apply_purge(plan)
    assert (home / ".legion/footprints.json").exists()


def test_purge_refuses_linked_home_and_keeps_outside_target(tmp_path: Path) -> None:
    home = tmp_path / "home"
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "keep").write_text("safe", encoding="utf-8")
    home.mkdir()
    if os.name == "nt":
        _winapi.CreateJunction(str(outside), str(home / ".legion"))
    else:
        (home / ".legion").symlink_to(outside, target_is_directory=True)
    plan = _installer.purge_plan(home, catalog())
    assert any("linked" in line for line in plan.lines)
    _installer.apply_purge(plan)
    assert (outside / "keep").read_text(encoding="utf-8") == "safe"


def test_purge_does_not_read_footprints_through_linked_home(tmp_path: Path) -> None:
    home = tmp_path / "home"
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "footprints.json").write_text("invalid external data", encoding="utf-8")
    home.mkdir()
    if os.name == "nt":
        _winapi.CreateJunction(str(outside), str(home / ".legion"))
    else:
        (home / ".legion").symlink_to(outside, target_is_directory=True)
    plan = _installer.purge_plan(home, catalog())
    assert plan.manual
    assert plan.legion is None
    assert not plan.has_work


def test_purge_rechecks_settings_bytes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    settings = home / ".copilot/settings.json"
    settings.parent.mkdir(parents=True)
    settings.write_text('{"enabledPlugins":{"legion@ps-legion-marketplace":false,"other":true}}', encoding="utf-8")
    monkeypatch.setenv("COPILOT_HOME", str(settings.parent))
    (home / ".legion").mkdir()
    plan = _installer.purge_plan(home, catalog())
    assert any("Remove entry:" in line for line in plan.lines)
    settings.write_text(settings.read_text(encoding="utf-8") + "\n", encoding="utf-8")
    with pytest.raises(_installer.InstallerError, match="Settings changed after preview"):
        _installer.apply_purge(plan)
    assert "legion@ps-legion-marketplace" in settings.read_text(encoding="utf-8")


def test_purge_is_repeatable(tmp_path: Path) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert not (home / ".legion").exists(), list((home / ".legion").iterdir())
    assert _installer.purge_plan(home, catalog()).lines == ["skip: purge (already done)"]


def test_closed_stdin_listing_and_only_needed_install_steps(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    def fake_run(command: str, arguments: list[str], **kwargs: object) -> RunResult:
        assert kwargs.get("cwd") is not None
        calls.append([command, *arguments])
        if arguments[-2:] == ["list", "--json"] and "marketplace" in arguments:
            return RunResult(exit_code=0, output='[{"name":"ps-legion-marketplace"}]', error="", timed_out=False)
        if arguments[-2:] == ["list", "--json"]:
            return RunResult(exit_code=0, output='[{"id":"legion@ps-legion-marketplace","enabled":true}]', error="", timed_out=False)
        return RunResult(exit_code=0, output="", error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", fake_run)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    folder = tmp_path / "claude"
    folder.mkdir()
    lines = _installer.install(home=tmp_path, catalog=catalog(), tools=["claude"], config_dir=folder, source=tmp_path, yes=True)
    assert len(calls) >= 2
    assert any("already done" in line for line in lines)
    assert not any("marketplace add" in line and not line.startswith("skip:") for line in lines)


def test_windows_cli_uses_resolved_cmd_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "codex")
    command = str(tmp_path / "codex.cmd")
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: command)
    monkeypatch.setattr(_installer, "run_command", lambda program, _args, **_kw: RunResult(exit_code=0, output=program, error="", timed_out=False))
    assert _installer._execute(entry, ["plugin", "list"], tmp_path) == command


def test_powershell_owner_spelling_matches_existing_index(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / ".codex"
    folder.mkdir(parents=True)
    owner = f"codex:{folder.resolve()}"
    if sys.platform == "win32":
        owner = owner.lower()
    command = home / ".legion/bin/legion"
    command.parent.mkdir(parents=True)
    command.write_text("#!/bin/sh\n" + header("owner command", False) + "\n", encoding="utf-8")
    _footprints.add(home, "file", command, owner)
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "codex")
    assert _installer._owner(entry, folder) == owner
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: "codex")
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args: False)
    _installer.install(home, ["codex"], config_dir=folder, uninstall=True, yes=True, catalog=catalog())
    assert not command.exists()


def test_local_source_is_absolute_when_cli_runs_elsewhere(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "claude")
    source = tmp_path / "marketplace"
    source.mkdir()
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: False)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    lines: list[str] = []
    _installer._install_steps(entry, tmp_path, Path("marketplace"), "release", True, lines)
    assert source.as_posix() in lines[0]


def test_install_prompt_discloses_path_edit(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: "claude")
    questions: list[str] = []
    monkeypatch.setattr("builtins.input", lambda question: questions.append(question) or "n")
    _installer.install(tmp_path, ["claude"], catalog=catalog())
    assert len(questions) == 1
    assert "PATH" in questions[0]


def test_installer_cli_reports_footprint_error_without_traceback(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer, "install", lambda *_args, **_kwargs: (_ for _ in ()).throw(_footprints.FootprintError("index busy")))
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "install", "--yes"])
    assert result.exit_code == 1
    assert "index busy" in result.output
    assert "Traceback" not in result.output


def test_plugin_listing_does_not_match_dev_fork(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "codex")
    monkeypatch.setattr(_installer, "_listing", lambda *_args: "legion@ps-legion-marketplace-dev 1.2.3")
    assert _installer._plugin_state(entry, tmp_path)[0] is False


def test_codex_marketplace_without_root_is_not_ready(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "codex")
    monkeypatch.setattr(_installer, "_listing", lambda *_args: '{"marketplaces":[{"name":"ps-legion-marketplace"}]}')
    assert not _installer._marketplace(entry, tmp_path, require_root=True)


def test_copilot_root_uses_from_line_only_for_legion(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "copilot")
    unrelated = tmp_path / "unrelated"
    expected = tmp_path / "expected"
    for root in (unrelated, expected):
        manifest = root / "plugins/legion/plugin.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
        registry = root / ".claude-plugin/marketplace.json"
        registry.parent.mkdir()
        registry.write_text('{"plugins":[{"name":"legion","source":"plugins/legion"}]}', encoding="utf-8")
    listing = f"other@marketplace 1.0.0\n  from {unrelated}\nlegion@ps-legion-marketplace 1.2.3\n  from {expected}"
    monkeypatch.setattr(_installer, "_listing", lambda *_args: listing)
    assert _installer._plugin_root(entry, tmp_path) == expected / "plugins/legion"


def test_uninstall_refresh_failure_keeps_command_hint(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = tmp_path / "account"
    folder.mkdir()
    command = tmp_path / ".legion/bin/legion"
    _footprints.add(tmp_path, "file", command, _footprints.target_owner("codex", folder))
    monkeypatch.setattr(_installer, "_plugin_root", lambda *_args: (_ for _ in ()).throw(RuntimeError("ambiguous")))
    lines: list[str] = []
    _installer.refresh_remaining(tmp_path, catalog(), lines)
    assert lines == ["Kept command: ~/.legion/bin/legion (run legion setup)"]


def test_purge_preview_does_not_claim_running_app_version_removal(tmp_path: Path) -> None:
    app = tmp_path / ".legion/app/1.2.3"
    app.mkdir(parents=True)
    (app / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    _footprints.add(tmp_path, "app", app.parent, "codex:one")
    _footprints.add(tmp_path, "app-version", app, "legion")
    assert not any("Remove app version" in line for line in _installer.preview_owned(tmp_path, ["codex:one"]))


def test_purge_keeps_other_plugin_data_and_cache(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / ".claude"
    folder.mkdir(parents=True)
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(folder))
    own = folder / "plugins/cache/ps-legion-marketplace/legion"
    own.mkdir(parents=True)
    other = folder / "plugins/cache/other-marketplace/other"
    other.mkdir(parents=True)
    (other / "data").write_text("keep", encoding="utf-8")
    copilot = home / ".copilot"
    copilot.mkdir()
    monkeypatch.setenv("COPILOT_HOME", str(copilot))
    other_data = copilot / "plugin-data/ps-legion-marketplace/other/keep.txt"
    other_data.parent.mkdir(parents=True)
    other_data.write_text("other plugin", encoding="utf-8")
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert not own.exists()
    assert (other / "data").read_text(encoding="utf-8") == "keep"
    assert other_data.read_text(encoding="utf-8") == "other plugin"


def test_partly_installed_target_only_installs_missing_plugin(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "claude")
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: True)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    calls: list[list[str]] = []
    monkeypatch.setattr(_installer, "_step", lambda _entry, arguments, *_args: calls.append(arguments))
    _installer._install_steps(entry, tmp_path, tmp_path, "release", False, [])
    assert entry["plugin"]["install"] in calls
    assert not any(arguments[:3] == ["plugin", "marketplace", "add"] for arguments in calls)


def test_purge_waits_for_writer_and_removes_lock_last(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    configuration = home / ".legion/configuration"
    configuration.mkdir(parents=True)
    plan = _installer.purge_plan(home, catalog())
    entered = threading.Event()
    release = threading.Event()
    written = threading.Event()
    errors: list[str] = []
    original = _installer.shutil.rmtree

    def slow_remove(path: Path) -> None:
        if path == configuration:
            entered.set()
            assert release.wait(5)
        original(path)

    def purge() -> None:
        try:
            _installer.apply_purge(plan)
        except Exception:
            errors.append(traceback.format_exc())

    def writer() -> None:
        try:
            _footprints.add(home, "path-entry", "user PATH", "legion", value="new")
            written.set()
        except Exception:
            errors.append(traceback.format_exc())

    monkeypatch.setattr(_installer.shutil, "rmtree", slow_remove)
    purge_thread = threading.Thread(target=purge)
    writer_thread = threading.Thread(target=writer)
    purge_thread.start()
    try:
        assert entered.wait(5)
        assert (home / ".legion/footprints.json.lock").exists()
        writer_thread.start()
        time.sleep(0.1)
        assert not written.is_set()
    finally:
        release.set()
        purge_thread.join(10)
        if writer_thread.ident is not None:
            writer_thread.join(10)
    assert not errors, "\n".join(errors)
    assert written.is_set()
    assert [(entry.kind, entry.value) for entry in _footprints.read(home).entries] == [("path-entry", "new")]


def test_self_purge_keeps_running_copy_and_clears_other_data(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    app = home / ".legion/app/1.2.3"
    app.mkdir(parents=True)
    monkeypatch.setattr(_footprints._plugin, "PLUGIN_ROOT", app)
    (app / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    _footprints.add(home, "app-version", app, "legion")
    data = home / ".legion/configuration/notes.md"
    data.parent.mkdir()
    data.write_text("notes", encoding="utf-8")
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert app.is_dir()
    assert not data.exists()


def test_uninstall_purge_asks_twice_and_dry_run_neither_prompts_nor_runs_cli(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / ".codex"
    folder.mkdir(parents=True)
    (home / ".legion/configuration").mkdir(parents=True)
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: "codex")
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args: False)
    command = home / ".legion/bin/legion"
    _footprints.add(home, "file", command, _footprints.target_owner("codex", folder))
    questions: list[str] = []
    monkeypatch.setattr("builtins.input", lambda question: questions.append(question) or "y")
    monkeypatch.setattr(_installer, "_step", lambda *_args: pytest.fail("CLI command ran"))
    _installer.install(home, ["codex"], config_dir=folder, uninstall=True, purge=True, dry_run=True, catalog=catalog())
    assert questions == []
    _installer.install(home, ["codex"], config_dir=folder, uninstall=True, purge=True, catalog=catalog())
    assert len(questions) == 2


def test_cli_uninstall_is_python_not_forwarded(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setattr(_forward, "run", lambda *_: pytest.fail("forwarded to PowerShell"))
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "uninstall", "--yes"])
    assert result.exit_code == 0, result.output
    assert "Nothing to uninstall." in result.output


def test_last_owner_removes_recorded_app_version_and_environment(tmp_path: Path) -> None:
    app = tmp_path / ".legion/app/1.2.3"
    app.mkdir(parents=True)
    (app / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    environment = _app.python_environment(app, tmp_path)
    environment.mkdir(parents=True)
    (environment / "python.txt").write_text("ready", encoding="utf-8")
    _footprints.add(tmp_path, "app-version", app, "legion")
    _footprints.add(tmp_path, "app", app.parent, "claude:one")
    _footprints.add(tmp_path, "app", app.parent, "codex:two")
    assert _footprints.remove_owner(tmp_path, ["claude:one"]) == []
    assert app.exists()
    assert _footprints.remove_owner(tmp_path, ["codex:two"]) == [f"Remove app version: {app}"]
    assert not app.exists()
    assert not environment.exists()


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_purge_jsonc_removes_only_legion_member_and_keeps_comments(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, newline: str) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    folder = home / ".copilot"
    folder.mkdir()
    monkeypatch.setenv("COPILOT_HOME", str(folder))
    path = folder / "settings.json"
    before = newline.join(["// owner comment", "{", '"enabledPlugins": {"a":true, /* keep */ "legion@ps-legion-marketplace":false,"b":false},', '"note":"legion@ps-legion-marketplace"', "}"])
    path.write_bytes(before.encode("utf-8"))
    plan = _installer.purge_plan(home, catalog())
    _installer.apply_purge(plan)
    expected = before.replace('"legion@ps-legion-marketplace":false,', "")
    assert path.read_bytes() == expected.encode("utf-8")


def test_purge_toml_removes_only_legion_tables(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    folder = home / ".codex"
    folder.mkdir()
    monkeypatch.setenv("CODEX_HOME", str(folder))
    path = folder / "config.toml"
    path.write_bytes(b'# owner\r\n[plugins."legion@ps-legion-marketplace"]\r\nenabled = false\r\n[plugins."other"]\r\nenabled = true\r\n')
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert path.read_bytes() == b'# owner\r\n[plugins."other"]\r\nenabled = true\r\n'


@pytest.mark.skipif(os.name != "nt", reason="Windows saved PATH")
def test_install_records_path_once_and_purge_removes_only_its_entry(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    home.mkdir()
    saved = tmp_path / "user-path.txt"
    saved.write_text("other;", encoding="utf-8")
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(saved))
    monkeypatch.setenv("PATH", "fixture-only")
    lines: list[str] = []
    _installer.ensure_path(home, False, lines)
    _installer.ensure_path(home, False, lines)
    assert saved.read_text(encoding="utf-8") == f"other;{home / '.legion/bin'}"
    assert os.environ["PATH"].startswith(str(home / ".legion/bin") + os.pathsep)
    assert any("already done" in line for line in lines)
    plan = _installer.purge_plan(home, catalog())
    assert any("Remove user PATH entry:" in line for line in plan.lines)
    _installer.apply_purge(plan)
    assert saved.read_text(encoding="utf-8") == "other"
    assert os.environ["PATH"] == "fixture-only"


@pytest.mark.skipif(os.name == "nt", reason="POSIX shell profile")
def test_profile_path_preserves_owner_text_and_purge_restores_it(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    home.mkdir()
    profile = home / ".profile"
    profile.write_text("owner line", encoding="utf-8")
    monkeypatch.setenv("SHELL", "/bin/sh")
    lines: list[str] = []
    _installer.ensure_path(home, False, lines)
    assert profile.read_text(encoding="utf-8") == 'owner line\n# Added by legion\nexport PATH="$HOME/.legion/bin:$PATH"\n'
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert profile.read_text(encoding="utf-8") == "owner line"


def test_purge_keeps_app_and_python_but_removes_other_legion_data(tmp_path: Path) -> None:
    home = tmp_path / "home"
    app = home / ".legion/app/1.2.3"
    app.mkdir(parents=True)
    (app / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    _footprints.add(home, "app-version", app, "legion")
    notes = home / ".legion/configuration/notes.md"
    notes.parent.mkdir()
    notes.write_text("owner notes", encoding="utf-8")
    python = home / ".legion/python/env-012345abcdef"
    python.mkdir(parents=True)
    plan = _installer.purge_plan(home, catalog())
    assert plan.legion == home / ".legion"
    _installer.apply_purge(plan)
    assert app.is_dir()
    assert python.is_dir()
    assert not notes.exists()
    assert _footprints.read(home).entries[0].kind == "app-version"


def test_remaining_owner_refreshes_command_after_selected_uninstall(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = tmp_path / "remaining"
    folder.mkdir()
    command = tmp_path / ".legion/bin/legion"
    _footprints.add(tmp_path, "file", command, f"codex:{folder}")
    root = tmp_path / "installed"
    root.mkdir()
    monkeypatch.setattr(_installer, "_plugin_root", lambda *_: root)
    called: list[tuple[str, Path]] = []
    monkeypatch.setattr(_installer, "_refresh_target", lambda entry, target, *_: called.append((entry["id"], target)) or [])
    _installer.refresh_remaining(tmp_path, catalog(), [])
    assert called == [("codex", folder)]


@pytest.mark.skipif(os.name == "nt", reason="POSIX uv interpreter links")
def test_purge_unlinks_only_known_python_environment_links(tmp_path: Path) -> None:
    home = tmp_path / "home"
    outside = tmp_path / "outside-python"
    outside.write_text("interpreter", encoding="utf-8")
    bin_dir = home / ".legion/python/env-012345abcdef/bin"
    bin_dir.mkdir(parents=True)
    (bin_dir / "python3").symlink_to(outside)
    plan = _installer.purge_plan(home, catalog())
    assert plan.legion == home / ".legion"
    assert any("Remove link:" in line for line in plan.lines)
    _installer.apply_purge(plan)
    assert not (home / ".legion").exists()
    assert outside.read_text(encoding="utf-8") == "interpreter"


@pytest.mark.skipif(os.name == "nt", reason="POSIX uv interpreter links")
def test_purge_keeps_interpreter_link_with_retained_app_version(tmp_path: Path) -> None:
    home = tmp_path / "home"
    app = home / ".legion/app/1.2.3"
    app.mkdir(parents=True)
    _footprints.add(home, "app-version", app, "legion")
    outside = tmp_path / "python"
    outside.write_text("interpreter", encoding="utf-8")
    bin_dir = home / ".legion/python/env-012345abcdef/bin"
    bin_dir.mkdir(parents=True)
    link = bin_dir / "python3"
    link.symlink_to(outside)
    plan = _installer.purge_plan(home, catalog())
    assert link not in plan.links
    _installer.apply_purge(plan)
    assert link.is_symlink()


def test_purge_removes_all_owned_json_members(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / ".claude"
    folder.mkdir(parents=True)
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(folder))
    path = folder / "settings.json"
    path.write_text('{"enabledPlugins":{"legion@ps-legion-marketplace":true,"other":true},"extraKnownMarketplaces":{"ps-legion-marketplace":{"source":"x"},"other":{}}}', encoding="utf-8")
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert json.loads(path.read_text(encoding="utf-8")) == {"enabledPlugins": {"other": True}, "extraKnownMarketplaces": {"other": {}}}


def test_purge_claude_json_removes_same_plugin_key_in_two_parents(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / ".claude"
    path = folder / "plugins/installed_plugins.json"
    path.parent.mkdir(parents=True)
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(folder))
    path.write_text('{"enabledPlugins":{"legion@ps-legion-marketplace":true},"plugins":{"legion@ps-legion-marketplace":{"x":1},"other":{}}}', encoding="utf-8")
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert json.loads(path.read_text(encoding="utf-8")) == {"enabledPlugins": {}, "plugins": {"other": {}}}


def test_purge_profile_preserves_later_owner_line(tmp_path: Path) -> None:
    profile = tmp_path / ".profile"
    profile.write_bytes(b'a\n# Added by legion\nexport PATH="$HOME/.legion/bin:$PATH"\nb\n')
    edit = _installer._profile_edit(profile, "\n", 'export PATH="$HOME/.legion/bin:$PATH"')
    assert edit is not None
    assert edit.after == b"a\nb\n"


def test_purge_with_selected_config_includes_other_accounts(tmp_path: Path) -> None:
    home = tmp_path / "home"
    account = home / ".legion/agents/claude-a"
    account.mkdir(parents=True)
    settings = home / ".legion/configuration/personalisation.json"
    settings.parent.mkdir(parents=True)
    settings.write_text(json.dumps({"agents": [{"tool": "claude", "configDir": str(account)}]}), encoding="utf-8")
    cache = account / "plugins/cache/ps-legion-marketplace"
    cache.mkdir(parents=True)
    plan = _installer.purge_plan(home, catalog(), config_dir=tmp_path / "selected")
    assert cache in plan.paths


def test_purge_edits_without_legion_home_do_not_create_it(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / ".copilot"
    folder.mkdir(parents=True)
    monkeypatch.setenv("COPILOT_HOME", str(folder))
    settings = folder / "settings.json"
    settings.write_text('{"enabledPlugins":{"legion@ps-legion-marketplace":true}}', encoding="utf-8")
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert not (home / ".legion").exists()


def test_purge_rejects_catalog_path_outside_tool_folder(tmp_path: Path) -> None:
    home = tmp_path / "home"
    folder = home / ".claude"
    folder.mkdir(parents=True)
    outside = home / "outside"
    outside.mkdir()
    selected = catalog()
    selected["tools"][0]["plugin"]["purge"]["paths"] = ["../outside"]
    with pytest.raises(_installer.InstallerError, match="Unsafe relative path"):
        _installer.purge_plan(home, selected)
    assert outside.is_dir()


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_purge_leaves_unsafe_jsonc_unchanged(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, newline: str) -> None:
    home = tmp_path / "home"
    folder = home / ".claude"
    folder.mkdir(parents=True)
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(folder))
    settings = folder / "settings.json"
    content = "{" + newline + '"enabledPlugins":{"legion@ps-legion-marketplace":true},' + newline + '"broken": [}'
    settings.write_bytes(content.encode())
    plan = _installer.purge_plan(home, catalog())
    assert any("Manual step:" in line and str(settings) in line for line in plan.lines)
    _installer.apply_purge(plan)
    assert settings.read_bytes() == content.encode()


@pytest.mark.skipif(os.name != "nt", reason="Windows directory junction")
def test_purge_removes_recorded_junction_without_following_target(tmp_path: Path) -> None:
    assert os.name == "nt"
    home = tmp_path / "home"
    target = tmp_path / "target"
    target.mkdir()
    (target / "keep").write_text("safe", encoding="utf-8")
    link = home / ".legion/bin/pwsh"
    link.parent.mkdir(parents=True)
    _winapi.CreateJunction(str(target), str(link))
    _footprints.add(home, "link", link, "legion", value=str(link.readlink()))
    plan = _installer.purge_plan(home, catalog())
    assert link in plan.links
    _installer.apply_purge(plan)
    assert not link.exists()
    assert (target / "keep").read_text(encoding="utf-8") == "safe"


def test_purge_removes_copilot_empty_parent_after_its_plugin_data(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    folder = home / ".copilot"
    child = folder / "plugin-data/ps-legion-marketplace/legion"
    child.mkdir(parents=True)
    (child / "data").write_text("owned", encoding="utf-8")
    monkeypatch.setenv("COPILOT_HOME", str(folder))
    plan = _installer.purge_plan(home, catalog())
    assert any("(if empty)" in line for line in plan.lines)
    _installer.apply_purge(plan)
    assert not (folder / "plugin-data/ps-legion-marketplace").exists()


def test_uninstall_removes_only_recorded_allow_rule(tmp_path: Path) -> None:
    home = tmp_path / "home"
    settings = home / ".legion/agents/claude-a/settings.json"
    settings.parent.mkdir(parents=True)
    text = '{"permissions":{"allow":["owner-rule","Bash(LEGION_ROLE=*)"]},"other":true}'
    settings.write_text(text, encoding="utf-8")
    owner = f"claude:{settings.parent}"
    _footprints.add(home, "edit", settings, owner, key="permissions.allow", value="Bash(LEGION_ROLE=*)")
    lines: list[str] = []
    _installer.remove_owned_edits(home, [owner], lines)
    assert settings.read_text(encoding="utf-8") == text.replace(',"Bash(LEGION_ROLE=*)"', "")
    assert any("Remove entry:" in line for line in lines)
    assert not [entry for entry in _footprints.read(home).entries if entry.kind == "edit"]


def test_copilot_jsonc_inventory_edit_keeps_owner_comments(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    folder = home / ".copilot"
    folder.mkdir()
    monkeypatch.setenv("COPILOT_HOME", str(folder))
    path = folder / "config.json"
    text = '// owner comment\n{"installedPlugins":[{"name":"other","marketplace":"else"}, /* keep */ {"name":"legion","marketplace":"ps-legion-marketplace"}],"note":"owner"}'
    path.write_text(text, encoding="utf-8")
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert path.read_text(encoding="utf-8") == text.replace(', /* keep */ {"name":"legion","marketplace":"ps-legion-marketplace"}', "")


@pytest.mark.parametrize("tool_id", ["claude", "codex", "copilot"])
def test_install_and_uninstall_target_use_fake_cli_and_refresh(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, tool_id: str) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == tool_id)
    command = entry["command"]
    folder = tmp_path / "config"
    root = folder / "installed-legion"
    installed = {"marketplace": False, "plugin": False}
    calls: list[list[str]] = []

    def fake_run(program: str, arguments: list[str], **kwargs: object) -> RunResult:
        assert program == command
        assert kwargs["cwd"] is not None
        calls.append(arguments)
        if arguments == entry["plugin"]["marketplaceList"]:
            found = [{"name": "ps-legion-marketplace", "root": str(folder)}] if installed["marketplace"] else []
            output = json.dumps({"marketplaces": found} if tool_id == "codex" else found)
        elif arguments == entry["plugin"]["list"]:
            if tool_id == "claude":
                output = json.dumps([{"id": "legion@ps-legion-marketplace", "enabled": True, "installPath": str(root)}] if installed["plugin"] else [])
            else:
                output = f"legion@ps-legion-marketplace 1.2.3 {root}" if installed["plugin"] else ""
        else:
            output = ""
            if arguments == entry["plugin"]["install"]:
                installed["plugin"] = True
                root.mkdir(parents=True, exist_ok=True)
                (root / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
            elif arguments == entry["plugin"]["uninstall"]:
                installed["plugin"] = False
            elif arguments == entry["plugin"]["marketplaceRemove"]:
                installed["marketplace"] = False
            elif arguments[:3] == ["plugin", "marketplace", "add"]:
                installed["marketplace"] = True
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", fake_run)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(tmp_path / "saved-path.txt"))
    monkeypatch.setenv("PATH", "fixture-only")
    (tmp_path / "saved-path.txt").write_text("", encoding="utf-8")
    refreshed: list[Path] = []
    monkeypatch.setattr(_installer, "_refresh_target", lambda *_args: refreshed.append(_args[-1]) or [])
    first = _installer.install(tmp_path, [tool_id], source=tmp_path, config_dir=folder, yes=True, catalog=catalog())
    assert installed == {"marketplace": True, "plugin": True}
    assert refreshed == [root]
    assert "installed: legion 1.2.3 (release)" in first
    assert any(arguments[:3] == ["plugin", "marketplace", "add"] for arguments in calls)
    assert entry["plugin"]["install"] in calls
    calls.clear()
    repeat = _installer.install(tmp_path, [tool_id], source=tmp_path, config_dir=folder, yes=True, catalog=catalog())
    assert any("already done" in line for line in repeat)
    assert entry["plugin"]["install"] not in calls
    _installer.install(tmp_path, [tool_id], config_dir=folder, yes=True, uninstall=True, catalog=catalog())
    assert installed == {"marketplace": False, "plugin": False}


def test_update_refreshes_new_installed_copy_and_reports_version(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "claude")
    folder = tmp_path / "config"
    root = folder / "plugin"
    root.mkdir(parents=True)
    manifest = root / "plugin.json"
    manifest.write_text('{"name":"legion","version":"1.0.0"}', encoding="utf-8")
    calls: list[list[str]] = []

    def fake_run(_command: str, arguments: list[str], **_kwargs: object) -> RunResult:
        calls.append(arguments)
        if arguments == entry["plugin"]["marketplaceList"]:
            output = '[{"name":"ps-legion-marketplace"}]'
        elif arguments == entry["plugin"]["list"]:
            version = json.loads(manifest.read_text(encoding="utf-8"))["version"]
            output = json.dumps([{"id": "legion@ps-legion-marketplace", "enabled": False, "installPath": str(root), "version": version}])
        else:
            output = ""
            if arguments == entry["plugin"]["update"]:
                manifest.write_text('{"name":"legion","version":"1.1.0"}', encoding="utf-8")
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", fake_run)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    refreshed: list[Path] = []
    monkeypatch.setattr(_installer, "_refresh_target", lambda *_args: refreshed.append(_args[-1]) or [])
    lines = _installer.install(tmp_path, ["claude"], config_dir=folder, update=True, yes=True, catalog=catalog())
    assert refreshed == [root]
    assert "legion 1.0.0 -> 1.1.0" in lines
    assert entry["plugin"]["marketplaceUpdate"] in calls
    assert entry["plugin"]["update"] in calls


def test_other_marketplace_source_loads_its_catalog_for_selected_ref(monkeypatch: pytest.MonkeyPatch) -> None:
    urls: list[str] = []

    class FakeResponse:
        def __enter__(self) -> Self:
            return self

        def __exit__(self, *_args: object) -> None:
            return None

        def read(self) -> bytes:
            return json.dumps(catalog()).encode("utf-8")

    def fake_open(url: str, **_kwargs: object) -> FakeResponse:
        urls.append(url)
        return FakeResponse()

    monkeypatch.setattr(_installer, "urlopen", fake_open, raising=False)
    assert _installer._catalog("example/marketplace", "main", None)["schemaVersion"] == 1
    assert urls == ["https://raw.githubusercontent.com/example/marketplace/main/plugins/legion/tools.json"]


def test_copilot_directory_marketplace_listing_finds_plugin_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "copilot")
    folder = tmp_path / "config"
    folder.mkdir()
    marketplace = tmp_path / "marketplace"
    manifest = marketplace / "plugins/legion/plugin.json"
    manifest.parent.mkdir(parents=True)
    manifest.write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    registry = marketplace / ".claude-plugin/marketplace.json"
    registry.parent.mkdir()
    registry.write_text('{"plugins":[{"name":"legion","source":"plugins/legion"}]}', encoding="utf-8")
    monkeypatch.setattr(_installer, "_listing", lambda *_: f"legion@ps-legion-marketplace 1.2.3\n  from {marketplace}")
    assert _installer._plugin_root(entry, folder) == manifest.parent


def test_missing_marketplace_reinstalls_plugin_even_when_stale_listing_is_enabled(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog()["tools"] if tool["id"] == "claude")
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: False)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (True, True, [], "1.0.0"))
    lines: list[str] = []
    _installer._install_steps(entry, tmp_path, tmp_path, "release", True, lines)
    assert any("plugin install legion@ps-legion-marketplace" in line for line in lines)


def test_empty_uninstall_names_kept_settings_and_account_logins(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    configuration = home / ".legion/configuration"
    accounts = home / ".legion/agents"
    configuration.mkdir(parents=True)
    accounts.mkdir()
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: None)
    lines = _installer.install(home, uninstall=True, yes=True, catalog=catalog())
    assert f"Kept settings and notes: {configuration}" in lines
    assert f"Kept account folders and logins: {accounts}" in lines


def test_uninstall_rejects_malformed_owner_record_before_cli_listing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _footprints.add(tmp_path, "file", tmp_path / ".legion/bin/legion", "codex:relative/config")
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    monkeypatch.setattr(_installer, "_listing", lambda *_: pytest.fail("CLI listing started"))
    with pytest.raises(_installer.InstallerError, match="Invalid target owner"):
        _installer.install(tmp_path, ["codex"], uninstall=True, yes=True, catalog=catalog())


def test_purge_leaves_inline_legion_toml_for_manual_edit(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    folder = home / ".codex"
    folder.mkdir()
    monkeypatch.setenv("CODEX_HOME", str(folder))
    path = folder / "config.toml"
    text = 'marketplaces = { "ps-legion-marketplace" = { source = "example" }, other = { source = "owner" } }\n'
    path.write_text(text, encoding="utf-8")
    plan = _installer.purge_plan(home, catalog())
    assert any("Manual step:" in line and str(path) in line for line in plan.lines)
    _installer.apply_purge(plan)
    assert path.read_text(encoding="utf-8") == text


@pytest.mark.parametrize("encoding", ["utf-8-sig", "utf-16"])
def test_purge_preserves_settings_bom_and_encoding(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, encoding: str) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    folder = home / ".copilot"
    folder.mkdir()
    monkeypatch.setenv("COPILOT_HOME", str(folder))
    path = folder / "settings.json"
    before = '{"enabledPlugins":{"legion@ps-legion-marketplace":false,"owner":true},"label":"✓"}'
    expected = before.replace('"legion@ps-legion-marketplace":false,', "")
    path.write_bytes(before.encode(encoding))
    _installer.apply_purge(_installer.purge_plan(home, catalog()))
    assert path.read_bytes() == expected.encode(encoding)


def test_profile_edit_keeps_utf16_and_crlf(tmp_path: Path) -> None:
    profile = tmp_path / ".profile"
    line = 'export PATH="$HOME/.legion/bin:$PATH"'
    profile.write_bytes(("owner\r\n# Added by legion\r\n" + line + "\r\n").encode("utf-16"))
    edit = _installer._profile_edit(profile, "", line)
    assert edit is not None
    assert edit.after == "owner\r\n".encode("utf-16")


def test_confirmation_prints_target_preview_before_asking(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    lines = ["Target: codex in selected folder", "codex plugin remove legion@ps-legion-marketplace"]

    def answer(_question: str) -> str:
        assert "Target: codex in selected folder" in capsys.readouterr().out
        return "n"

    monkeypatch.setattr("builtins.input", answer)
    assert not _installer._confirm("Uninstall? [y/N]", lines)
    assert lines == []


def test_uninstall_preview_lists_owned_command_without_removing_it(tmp_path: Path) -> None:
    command = tmp_path / ".legion/bin/legion"
    command.parent.mkdir(parents=True)
    command.write_text("#!/bin/sh\n" + header("owner command", False) + "\n", encoding="utf-8")
    _footprints.add(tmp_path, "file", command, "codex:one")
    lines = _installer.preview_owned(tmp_path, ["codex:one"])
    assert f"Remove file: {command}" in lines
    assert command.exists()


def test_uninstall_preview_refuses_linked_settings_folder(tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    settings = outside / "settings.json"
    settings.write_text('{"permissions":{"allow":["Bash(LEGION_ROLE=*)"]}}', encoding="utf-8")
    linked = tmp_path / ".legion/agents/linked"
    linked.parent.mkdir(parents=True)
    if os.name == "nt":
        _winapi.CreateJunction(str(outside), str(linked))
    else:
        linked.symlink_to(outside, target_is_directory=True)
    _footprints.add(tmp_path, "edit", linked / "settings.json", "claude:one", key="permissions.allow", value="Bash(LEGION_ROLE=*)")
    assert not any(line.startswith("Remove entry:") for line in _installer.preview_owned(tmp_path, ["claude:one"]))


@pytest.mark.skipif(os.name != "nt", reason="Windows portable PATH")
def test_portable_path_record_only_accepts_path_inside_legion_tools(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    monkeypatch.setenv("LEGION_PORTABLE_PATH_ADDED", str(tmp_path / "outside"))
    _installer.record_portable_path(home)
    assert _footprints.read(home).entries == []
    portable = home / ".legion/tools/pwsh/7.4"
    monkeypatch.setenv("LEGION_PORTABLE_PATH_ADDED", str(portable))
    _installer.record_portable_path(home)
    assert [(entry.kind, entry.value) for entry in _footprints.read(home).entries] == [("path-entry", str(portable))]


def test_plain_install_entry_accepts_bootstrap_lifecycle_options(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[dict[str, object]] = []

    def fake_install(_home: Path, *_args: object, **options: object) -> list[str]:
        calls.append(options)
        return ["ready"]

    monkeypatch.setattr(_installer, "install", fake_install)
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "install", "--tool", "codex", "--source", "example/marketplace", "--ref", "main", "--uninstall", "--purge", "--yes"])
    assert result.exit_code == 0, result.output
    assert calls[0]["uninstall"] is True
    assert calls[0]["purge"] is True


def test_purge_removes_recorded_allow_rule_from_external_account_folder(tmp_path: Path) -> None:
    home = tmp_path / "home"
    settings = tmp_path / "account/settings.json"
    settings.parent.mkdir()
    settings.write_text('{"permissions":{"allow":["owner","Bash(LEGION_ROLE=*)"]}}', encoding="utf-8")
    _footprints.add(home, "edit", settings, f"claude:{settings.parent}", key="permissions.allow", value="Bash(LEGION_ROLE=*)")
    plan = _installer.purge_plan(home, catalog())
    assert any(str(settings) in line and "Remove entry:" in line for line in plan.lines)
    _installer.apply_purge(plan)
    assert settings.read_text(encoding="utf-8") == '{"permissions":{"allow":["owner"]}}'


def test_invalid_toml_is_left_for_manual_purge(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    (home / ".legion").mkdir(parents=True)
    folder = home / ".codex"
    folder.mkdir()
    monkeypatch.setenv("CODEX_HOME", str(folder))
    path = folder / "config.toml"
    path.write_text('[plugins."legion@ps-legion-marketplace"\n', encoding="utf-8")
    plan = _installer.purge_plan(home, catalog())
    assert any("Manual step:" in line for line in plan.lines)
