import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest
from filelock import FileLock

from legion import _app, _footprints
from legion._generated import is_owned, shell_literal

from app_fakes import MARKER, VERSION, FakeUv, make_link, make_source, old_app

if sys.platform == "win32":
    pass

MISSING = "uv is missing. Ask the owner before installing it, then run the legion installer again."


@pytest.fixture
def uv(monkeypatch: pytest.MonkeyPatch) -> FakeUv:
    return FakeUv(monkeypatch)


def test_ready_versions_uses_recorded_marked_safe_versions(tmp_path: Path) -> None:
    app = tmp_path / ".legion" / "app"
    for name in ("1.2.0", "1.10.0", "2.0.0"):
        folder = app / name
        folder.mkdir(parents=True)
        _footprints.add(tmp_path, "app-version", folder, "install")
    (app / "1.2.0" / ".legion-app-ready").touch()
    (app / "1.10.0" / ".legion-app-ready").touch()
    assert [item.path for item in _app.ready_versions(tmp_path)] == [app / "1.10.0", app / "1.2.0"]


# ---- app sync, owner commands and prune ----


def test_fresh_sync_copies_syncs_in_the_versions_environment_marks_and_records(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    lines, ready = _app.sync_app(home, source)
    target = home / ".legion" / "app" / VERSION
    assert lines == [f"legion app {VERSION} ready"]
    assert ready == target
    assert (target / "src" / "module.py").read_text(encoding="utf-8") == "x = 1\n"
    assert uv.calls == [("uv", ["sync", "--project", str(target), "--frozen", "--quiet"], str(_app.python_environment(target, home)))]
    assert (target / MARKER).is_file()
    assert [entry.path for entry in _footprints.read(home).entries if entry.kind == "app-version"] == [f"~/.legion/app/{VERSION}"]
    assert [path.name for path in (home / ".legion" / "app").iterdir()] == [VERSION]
    assert [item.path for item in _app.ready_versions(home)] == [target]


@pytest.mark.usefixtures("uv")
def test_the_copy_is_recorded_before_it_is_renamed_into_place(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    seen: list[bool] = []
    real_rename = Path.rename

    def rename(self: Path, target: Path) -> Path:
        seen.append(any(entry.kind == "app-version" for entry in _footprints.read(home).entries))
        return real_rename(self, target)

    monkeypatch.setattr(Path, "rename", rename)
    _app.sync_app(home, source)
    assert seen == [True]


def test_same_version_again_skips_without_running_uv(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    _app.sync_app(home, source)
    lines, ready = _app.sync_app(home, source)
    assert lines == [f"skip: legion app {VERSION} (already done)"]
    assert ready == home / ".legion" / "app" / VERSION
    assert len(uv.calls) == 1


def test_an_unfinished_version_is_synced_again_in_place(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    _app.sync_app(home, source)
    target = home / ".legion" / "app" / VERSION
    (target / MARKER).unlink()
    assert _app.ready_versions(home) == []
    lines, ready = _app.sync_app(home, source)
    assert lines == [f"legion app {VERSION} ready"]
    assert uv.calls[-1][1] == ["sync", "--project", str(target), "--frozen", "--quiet"]
    assert (target / MARKER).is_file()
    assert ready == target


def test_an_older_source_never_replaces_a_newer_app(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    newer, _ = old_app(home, "99.0.0")
    lines, ready = _app.sync_app(home, source)
    assert lines == [f"skip: legion app {VERSION} (newer 99.0.0 in place)"]
    assert ready == newer
    assert uv.calls == []
    assert not (home / ".legion" / "app" / VERSION).exists()


@pytest.mark.usefixtures("uv")
def test_a_newer_source_goes_in_beside_the_older_version(tmp_path: Path) -> None:
    home, source = tmp_path / "home", make_source(tmp_path, "2.0.0")
    old, _ = old_app(home, "1.9.0")
    lines, ready = _app.sync_app(home, source)
    assert lines == ["legion app 2.0.0 ready"]
    assert ready == home / ".legion" / "app" / "2.0.0"
    assert old.is_dir()


def test_a_version_folder_that_is_not_legions_is_left_alone(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    foreign = home / ".legion" / "app" / VERSION
    foreign.mkdir(parents=True)
    (foreign / "note.txt").write_text("mine", encoding="utf-8")
    lines, ready = _app.sync_app(home, source)
    assert lines == [f"skip: {foreign} (not legion's)"]
    assert ready is None
    assert [path.name for path in foreign.iterdir()] == ["note.txt"]
    assert uv.calls == []


def test_a_linked_environment_folder_is_refused_before_uv_runs(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(home / ".legion" / "python", elsewhere)
    lines, ready = _app.sync_app(home, source)
    assert len(lines) == 1
    assert lines[0].endswith("(linked version or environment)")
    assert ready is None
    assert uv.calls == []
    assert list(elsewhere.iterdir()) == []


def test_a_linked_version_folder_is_refused(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    target = home / ".legion" / "app" / VERSION
    make_link(target, elsewhere)
    _footprints.add(home, "app-version", target, "legion")
    lines, ready = _app.sync_app(home, source)
    assert lines == [f"skip: {target} (linked version or environment)"]
    assert ready is None
    assert uv.calls == []
    assert list(elsewhere.iterdir()) == []


def test_a_link_that_appears_during_the_sync_stops_it_before_the_marker(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    uv.effect = lambda target: make_link(target / "linked", elsewhere)
    lines, ready = _app.sync_app(home, source)
    target = home / ".legion" / "app" / VERSION
    assert lines == [f"skip: {target} (linked)"]
    assert ready is None
    assert not (target / MARKER).exists()


def test_a_failed_sync_shows_the_error_keeps_the_old_version_and_marks_nothing(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    old, _ = old_app(home, "0.0.1")
    uv.exit_code, uv.error = 3, "fixture sync failure\n"
    lines, ready = _app.sync_app(home, source)
    assert lines == ["fixture sync failure", f"legion app {VERSION} not ready (uv sync exited 3); run legion setup again"]
    assert ready == old
    assert not (home / ".legion" / "app" / VERSION / MARKER).exists()
    uv.exit_code, uv.error = 0, ""
    assert _app.sync_app(home, source)[0] == [f"legion app {VERSION} ready"]
    assert len(uv.calls) == 2


def test_a_copy_of_a_published_app_carries_no_ready_marker_into_the_next_home(tmp_path: Path, uv: FakeUv) -> None:
    first, second = tmp_path / "first", tmp_path / "second"
    _app.sync_app(first, make_source(tmp_path))
    published = first / ".legion" / "app" / VERSION
    assert (published / MARKER).is_file()
    uv.exit_code = 3
    lines, ready = _app.sync_app(second, published)
    target = second / ".legion" / "app" / VERSION
    assert lines[-1] == f"legion app {VERSION} not ready (uv sync exited 3); run legion setup again"
    assert ready is None
    assert not (target / MARKER).exists()
    assert _app.ready_versions(second) == []
    uv.exit_code = 0
    assert _app.sync_app(second, published)[0] == [f"legion app {VERSION} ready"]
    assert len(uv.calls) == 3


def test_a_recorded_unfinished_version_with_a_link_is_refused_before_uv_reads_it(tmp_path: Path, uv: FakeUv) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    unfinished, _ = old_app(home, VERSION, ready=False)
    make_link(unfinished / "linked", elsewhere)
    lines, ready = _app.sync_app(home, source)
    assert lines == [f"skip: {unfinished} (linked)"]
    assert ready is None
    assert uv.calls == []
    assert not (unfinished / MARKER).exists()


@pytest.mark.parametrize("version", ["../other", "1.0.0/../x", ""])
def test_a_manifest_version_that_is_not_a_version_is_refused_before_any_path_is_built(tmp_path: Path, uv: FakeUv, version: str) -> None:
    home, source = tmp_path / "home", make_source(tmp_path, version)
    with pytest.raises(_app.AppError, match="version"):
        _app.sync_app(home, source)
    assert uv.calls == []
    assert not (home / ".legion" / "other").exists()
    assert not (home / ".legion" / "app").exists()


def test_missing_uv_is_one_plain_line_and_copies_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home, source = tmp_path / "home", make_source(tmp_path)
    monkeypatch.setattr(_app, "find_uv", lambda: None)
    lines, ready = _app.sync_app(home, source)
    assert lines == [MISSING]
    assert ready is None
    assert not (home / ".legion" / "app" / VERSION).exists()


def test_a_busy_sync_lock_is_reported_without_waiting(tmp_path: Path) -> None:
    app = tmp_path / ".legion" / "app"
    app.mkdir(parents=True)
    with FileLock(str(app / ".sync.lock")), _app.app_lock(tmp_path, timeout=0) as held:
        assert held is False
    with _app.app_lock(tmp_path, timeout=0) as held:
        assert held is True


def test_a_linked_app_folder_is_refused_before_anything_is_written(tmp_path: Path) -> None:
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / "home" / ".legion" / "app", elsewhere)
    with pytest.raises(_app.AppError, match="link"), _app.app_lock(tmp_path / "home"):
        pass
    assert list(elsewhere.iterdir()) == []


def test_prune_keeps_the_current_and_the_previous_version_and_removes_older_ones(tmp_path: Path) -> None:
    oldest, oldest_env = old_app(tmp_path, "0.0.1")
    previous, previous_env = old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    assert _app.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not oldest.exists()
    assert not oldest_env.exists()
    assert previous.is_dir()
    assert previous_env.is_dir()
    assert [entry.path for entry in _footprints.read(tmp_path).entries] == ["~/.legion/app/0.0.2", "~/.legion/app/0.0.3"]


def test_prune_removes_an_unfinished_older_version(tmp_path: Path) -> None:
    unfinished, environment = old_app(tmp_path, "0.0.1", ready=False)
    current, _ = old_app(tmp_path, "0.0.3")
    assert _app.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not unfinished.exists()
    assert not environment.exists()


def test_prune_never_removes_an_unrecorded_or_linked_version(tmp_path: Path) -> None:
    stranger, stranger_env = old_app(tmp_path, "0.0.1", recorded=False)
    current, _ = old_app(tmp_path, "5.0.0")
    elsewhere, _ = old_app(tmp_path / "elsewhere", "0.0.2", recorded=False)
    linked = tmp_path / ".legion" / "app" / "0.0.2"
    make_link(linked, elsewhere)
    _footprints.add(tmp_path, "app-version", linked, "legion")
    assert _app.prune_old_versions(current, tmp_path) == [f"skip: {linked} (linked or not legion's)"]
    assert stranger.is_dir()
    assert stranger_env.is_dir()
    assert (elsewhere / MARKER).is_file()


def test_prune_keeps_a_version_that_cannot_be_removed_and_says_so(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    held, _ = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")

    def locked(*_arguments: Any, **_keywords: Any) -> None:
        raise PermissionError("in use")

    with monkeypatch.context() as patch:
        patch.setattr(_app.shutil, "rmtree", locked)
        assert _app.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
    assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)
    assert _app.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not held.exists()


@pytest.mark.skipif(sys.platform != "win32", reason="only Windows refuses to delete an open file")
def test_prune_skips_a_version_whose_environment_a_running_legion_holds(tmp_path: Path) -> None:
    held, environment = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    with (environment / "python.txt").open("rb"):
        assert _app.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
        assert (environment / "python.txt").is_file()
        assert (held / "plugin.json").is_file()
        assert (held / MARKER).is_file()
        assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)
    assert _app.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not held.exists()
    assert not environment.exists()


@pytest.mark.skipif(sys.platform != "win32", reason="only Windows refuses to rename a folder with an open file")
def test_prune_skips_a_version_whose_source_a_running_legion_holds(tmp_path: Path) -> None:
    held, environment = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    with (held / "plugin.json").open("rb"):
        assert _app.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
        assert (held / "plugin.json").is_file()
        assert (held / MARKER).is_file()
        assert (environment / "python.txt").is_file()
        assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)
    assert _app.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]


@pytest.mark.parametrize("locked_tree", ["source", "environment"])
def test_failed_prune_rename_keeps_both_trees_and_record(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, locked_tree: str) -> None:
    held, environment = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    blocked = held if locked_tree == "source" else environment
    real = Path.replace

    def replace(source: Path, target: str | Path) -> Path:
        if source == blocked:
            raise PermissionError("in use")
        return real(source, target)

    monkeypatch.setattr(Path, "replace", replace)
    assert _app.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
    assert (held / "plugin.json").is_file()
    assert (held / MARKER).is_file()
    assert (environment / "python.txt").is_file()
    assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)


def test_a_version_whose_environment_cannot_be_removed_keeps_its_source_and_record(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    held, environment = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    real = shutil.rmtree

    def rmtree(target: Any, *arguments: Any, **keywords: Any) -> None:
        if Path(target).parent == environment.parent and Path(target).name.startswith(f".pruning-{environment.name}-"):
            raise PermissionError("in use")
        real(target, *arguments, **keywords)

    monkeypatch.setattr(_app.shutil, "rmtree", rmtree)
    assert _app.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
    assert (held / "plugin.json").is_file()
    assert not (held / MARKER).exists()
    assert environment.is_dir()
    assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)


def test_partial_environment_delete_invalidates_restored_app(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    held, environment = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    real = shutil.rmtree

    def partial_delete(target: Any, *arguments: Any, **keywords: Any) -> None:
        if Path(target).name.startswith(f".pruning-{environment.name}-"):
            (Path(target) / "python.txt").unlink()
            raise PermissionError("in use")
        real(target, *arguments, **keywords)

    monkeypatch.setattr(_app.shutil, "rmtree", partial_delete)
    assert _app.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
    assert held.is_dir()
    assert not (held / MARKER).exists()
    assert environment.is_dir()
    assert not (environment / "python.txt").exists()
    assert all(version.path != held for version in _app.ready_versions(tmp_path))
    assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)


def test_a_removed_folder_is_renamed_and_invalidated_before_deletion(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    path, _ = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    seen: list[bool] = []
    real = shutil.rmtree

    def rmtree(target: Any, *arguments: Any, **keywords: Any) -> None:
        if Path(target).parent == path.parent and Path(target).name.startswith(f".pruning-{path.name}-"):
            seen.append(not (Path(target) / MARKER).exists() and not path.exists())
        real(target, *arguments, **keywords)

    monkeypatch.setattr(_app.shutil, "rmtree", rmtree)
    _app.prune_old_versions(current, tmp_path)
    assert seen == [True]


def test_unix_command_text_quotes_the_app_the_environment_and_the_selected_home(tmp_path: Path) -> None:
    home = tmp_path / "owner's 100% home"
    app = home / ".legion" / "app" / "1.2.3"
    expected = (
        f"#!/bin/sh\n# Generated by legion: owner command\ncommand -v uv >/dev/null 2>&1 || {{ echo '{MISSING}' >&2; exit 127; }}\n"
        f'if [ "$1" = uninstall ]; then exec uv run --no-project --python 3.12 {shell_literal(str(app / "src/legion/_self_uninstall.py"))} {shell_literal(str(app))} "$@"; fi\n'
        f"export UV_PROJECT_ENVIRONMENT={shell_literal(str(_app.python_environment(app, home)))}\n"
        f'exec uv run --project {shell_literal(str(app))} --frozen --quiet legion --home {shell_literal(str(home))} "$@"\n'
    )
    assert _app.shim_text(app, home, windows=False) == expected


def test_the_default_home_adds_no_home_argument() -> None:
    app = Path.home() / ".legion" / "app" / "1.2.3"
    assert "--home" not in _app.shim_text(app, Path.home(), windows=False)
    assert "--home" not in _app.shim_text(app, Path.home(), windows=True)


def test_windows_command_text_finds_everything_from_its_own_folder(tmp_path: Path) -> None:
    home = tmp_path / "home 100%"
    app = home / ".legion" / "app" / "1.2.3"
    name = _app.python_environment(app, home).name
    expected = (
        "@rem Generated by legion: owner command\r\n"
        f"@where /q uv || (>&2 echo {MISSING}& exit /b 127)\r\n"
        '@if /i "%~1"=="uninstall" uv run --no-project --python 3.12 "%~dp0..\\app\\1.2.3\\src\\legion\\_self_uninstall.py" "%~dp0..\\app\\1.2.3" %*\r\n'
        '@if /i "%~1"=="uninstall" exit /b\r\n'
        f'@set "UV_PROJECT_ENVIRONMENT=%~dp0..\\python\\{name}" & uv run --project "%~dp0..\\app\\1.2.3" --frozen --quiet legion --home "%~dp0..\\.." %* & (goto) 2>nul & '
        'set "UV_PROJECT_ENVIRONMENT=%UV_PROJECT_ENVIRONMENT%" & "%COMSPEC%" /d /c "set /a LEGION_EXIT=0x%%=ExitCode%% >nul & call exit %%^LEGION_EXIT%%"\r\n'
    )
    text = _app.shim_text(app, home, windows=True)
    assert text == expected
    assert text.isascii()
    assert "100%" not in text


@pytest.mark.skipif(sys.platform != "win32", reason="cmd is Windows only")
def test_windows_owner_uninstall_dispatches_helper_and_returns_its_failure(tmp_path: Path) -> None:
    home = tmp_path / "home"
    app = home / ".legion/app/1.2.3"
    app.mkdir(parents=True)
    bin_folder = tmp_path / "fake-bin"
    bin_folder.mkdir()
    log = tmp_path / "uv-args.txt"
    (bin_folder / "uv.cmd").write_text(f'@echo off\r\necho %* > "{log}"\r\nexit /b 23\r\n', encoding="ascii")
    command = home / ".legion/bin/legion.cmd"
    command.parent.mkdir(parents=True)
    command.write_text(_app.shim_text(app, home, windows=True), encoding="ascii")
    env = os.environ.copy()
    where = shutil.which("where.exe")
    assert where
    env["PATH"] = str(bin_folder) + os.pathsep + str(Path(where).parent)
    result = subprocess.run([str(Path(where).parent / "cmd.exe"), "/d", "/c", str(command), "uninstall", "--yes"], env=env, capture_output=True, text=True, check=False)
    assert result.returncode == 23
    assert "--no-project --python 3.12" in log.read_text(encoding="ascii")
    assert "_self_uninstall.py" in log.read_text(encoding="ascii")


def test_owner_commands_are_written_once_and_never_over_a_foreign_file(tmp_path: Path) -> None:
    app, _ = old_app(tmp_path, "1.2.3")
    changed = _app.write_owner_commands(app, tmp_path)
    names = ["legion", "legion.cmd"] if sys.platform == "win32" else ["legion"]
    bin_folder = tmp_path / ".legion" / "bin"
    assert changed == [bin_folder / name for name in names]
    for name in names:
        assert is_owned(bin_folder / name, "owner command")
    assert _app.write_owner_commands(app, tmp_path) == []
    (bin_folder / "legion").write_text("owner file", encoding="utf-8")
    assert _app.write_owner_commands(app, tmp_path) == []
    assert (bin_folder / "legion").read_text(encoding="utf-8") == "owner file"


@pytest.mark.skipif(sys.platform == "win32", reason="Windows has no execute bit")
def test_owner_command_gets_its_execute_bit_back(tmp_path: Path) -> None:
    app, _ = old_app(tmp_path, "1.2.3")
    _app.write_owner_commands(app, tmp_path)
    command = tmp_path / ".legion" / "bin" / "legion"
    command.chmod(0o644)
    assert _app.write_owner_commands(app, tmp_path) == [command]
    assert command.stat().st_mode & 0o100


def test_owner_commands_are_not_written_through_a_linked_bin_folder(tmp_path: Path) -> None:
    app, _ = old_app(tmp_path, "1.2.3")
    elsewhere = tmp_path / "elsewhere"
    elsewhere.mkdir()
    make_link(tmp_path / ".legion" / "bin", elsewhere)
    assert _app.write_owner_commands(app, tmp_path) == []
    assert list(elsewhere.iterdir()) == []
