import shutil
import sys
from pathlib import Path
from typing import Any

import pytest

from legion.services.installation import _installed_runtime
from legion.services.repository import _footprints

from app_fakes import MARKER, make_link, old_app


def test_ready_versions_uses_recorded_marked_safe_versions(tmp_path: Path) -> None:
    app = tmp_path / ".legion" / "app"
    for name in ("1.2.0", "1.10.0", "2.0.0"):
        folder = app / name
        folder.mkdir(parents=True)
        _footprints.add(tmp_path, "app-version", folder, "install")
    (app / "1.2.0" / ".legion-app-ready").touch()
    (app / "1.10.0" / ".legion-app-ready").touch()
    assert [item.path for item in _installed_runtime.ready_versions(tmp_path)] == [app / "1.10.0", app / "1.2.0"]


# ---- the legacy layout's prune ----


def test_prune_keeps_the_current_and_the_previous_version_and_removes_older_ones(tmp_path: Path) -> None:
    oldest, oldest_env = old_app(tmp_path, "0.0.1")
    previous, previous_env = old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not oldest.exists()
    assert not oldest_env.exists()
    assert previous.is_dir()
    assert previous_env.is_dir()
    assert [entry.path for entry in _footprints.read(tmp_path).entries] == ["~/.legion/app/0.0.2", "~/.legion/app/0.0.3"]


def test_prune_removes_an_unfinished_older_version(tmp_path: Path) -> None:
    unfinished, environment = old_app(tmp_path, "0.0.1", ready=False)
    current, _ = old_app(tmp_path, "0.0.3")
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not unfinished.exists()
    assert not environment.exists()


def test_prune_never_removes_an_unrecorded_or_linked_version(tmp_path: Path) -> None:
    stranger, stranger_env = old_app(tmp_path, "0.0.1", recorded=False)
    current, _ = old_app(tmp_path, "5.0.0")
    elsewhere, _ = old_app(tmp_path / "elsewhere", "0.0.2", recorded=False)
    linked = tmp_path / ".legion" / "app" / "0.0.2"
    make_link(linked, elsewhere)
    _footprints.add(tmp_path, "app-version", linked, "legion")
    assert _installed_runtime.prune_old_versions(current, tmp_path) == [f"skip: {linked} (linked or not legion's)"]
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
        patch.setattr(_installed_runtime.shutil, "rmtree", locked)
        assert _installed_runtime.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
    assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not held.exists()


@pytest.mark.skipif(sys.platform != "win32", reason="only Windows refuses to delete an open file")
def test_prune_skips_a_version_whose_environment_a_running_legion_holds(tmp_path: Path) -> None:
    held, environment = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    with (environment / "python.txt").open("rb"):
        assert _installed_runtime.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
        assert (environment / "python.txt").is_file()
        assert (held / "plugin.json").is_file()
        assert (held / MARKER).is_file()
        assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]
    assert not held.exists()
    assert not environment.exists()


@pytest.mark.skipif(sys.platform != "win32", reason="only Windows refuses to rename a folder with an open file")
def test_prune_skips_a_version_whose_source_a_running_legion_holds(tmp_path: Path) -> None:
    held, environment = old_app(tmp_path, "0.0.1")
    old_app(tmp_path, "0.0.2")
    current, _ = old_app(tmp_path, "0.0.3")
    with (held / "plugin.json").open("rb"):
        assert _installed_runtime.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
        assert (held / "plugin.json").is_file()
        assert (held / MARKER).is_file()
        assert (environment / "python.txt").is_file()
        assert any(entry.path == "~/.legion/app/0.0.1" for entry in _footprints.read(tmp_path).entries)
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["removed legion app 0.0.1"]


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
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
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

    monkeypatch.setattr(_installed_runtime.shutil, "rmtree", rmtree)
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
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

    monkeypatch.setattr(_installed_runtime.shutil, "rmtree", partial_delete)
    assert _installed_runtime.prune_old_versions(current, tmp_path) == ["skip: legion app 0.0.1 (in use; removed at the next sync)"]
    assert held.is_dir()
    assert not (held / MARKER).exists()
    assert environment.is_dir()
    assert not (environment / "python.txt").exists()
    assert all(version.path != held for version in _installed_runtime.ready_versions(tmp_path))
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

    monkeypatch.setattr(_installed_runtime.shutil, "rmtree", rmtree)
    _installed_runtime.prune_old_versions(current, tmp_path)
    assert seen == [True]
