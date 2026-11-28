from pathlib import Path

import os
import stat
import sys
from types import SimpleNamespace

import pytest
from conftest import Fence

from legion.services.repository import _footprints
from legion.core._home import (
    full_path,
    is_under,
    owner_path_safe,
    resolve_directory,
    same_path,
)

if sys.platform == "win32":
    import _winapi


def test_resolved_containment_follows_links_and_respects_directory_boundaries(fence: Fence) -> None:
    scratch = fence.temp / "paths"
    scratch.mkdir()
    physical = resolve_directory(scratch)
    root = resolve_directory(fence.temp)
    assert is_under(physical, root)
    assert same_path(resolve_directory(scratch), physical)
    assert is_under(resolve_directory(scratch), physical, allow_equal=True)
    assert not is_under(resolve_directory(scratch), physical)
    assert is_under(resolve_directory(scratch / "missing/leaf"), physical)
    assert not is_under(resolve_directory(scratch.with_name("paths-sibling")), physical)
    uppercase = Path(str(scratch).upper())
    same_directory = os.name == "nt" or (uppercase.is_dir() and str(resolve_directory(uppercase)) == str(physical))
    assert same_path(resolve_directory(uppercase), physical) == same_directory
    escape = scratch / "escape"
    if sys.platform == "win32":
        _winapi.CreateJunction(str(fence.outside), str(escape))
    else:
        escape.symlink_to(fence.outside, target_is_directory=True)
    assert not is_under(resolve_directory(escape), physical)


def test_lexical_path_checks_keep_links_visible(tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    home = tmp_path / "home"
    home.mkdir()
    link = home / "linked"
    if sys.platform == "win32":
        _winapi.CreateJunction(str(outside), str(link))
    else:
        link.symlink_to(outside, target_is_directory=True)
    assert is_under(link / "child", home)
    assert not owner_path_safe(link / "child", home)
    assert owner_path_safe(link, link)
    assert owner_path_safe(home / "missing", home)
    assert resolve_directory(link) == outside
    assert full_path(link / "..") == home
    assert same_path(home, home)


@pytest.mark.skipif(sys.platform != "win32", reason="Windows reparse attribute")
def test_other_reparse_points_are_refused_by_walk_and_descendant_scans(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = tmp_path / ".legion" / "app" / "1.0.0"
    folder.mkdir(parents=True)
    child = folder / "other-reparse"
    child.mkdir()
    original = Path.lstat

    def marked(path: Path, *args: object, **kwargs: object) -> object:
        if path == child:
            return SimpleNamespace(st_mode=stat.S_IFDIR, st_file_attributes=stat.FILE_ATTRIBUTE_REPARSE_POINT)
        return original(path, *args, **kwargs)

    monkeypatch.setattr(Path, "lstat", marked)
    assert not owner_path_safe(child, tmp_path)
    entry = _footprints.Footprint(kind="folder", path="~/.legion/app/1.0.0", owners=["account:a"])
    assert not _footprints.is_safe(entry, tmp_path)


def test_descendant_inspection_failure_refuses_tree(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = tmp_path / ".legion" / "old"
    folder.mkdir(parents=True)
    child = folder / "blocked"
    child.mkdir()
    original = Path.lstat

    def denied(path: Path, *args: object, **kwargs: object) -> os.stat_result:
        if path == child:
            raise PermissionError("blocked")
        return original(path, *args, **kwargs)

    monkeypatch.setattr(Path, "lstat", denied)
    entry = _footprints.Footprint(kind="folder", path="~/.legion/old", owners=["account:a"])
    assert not _footprints.is_safe(entry, tmp_path)


@pytest.mark.skipif(sys.platform != "win32", reason="Windows drive relative path")
def test_full_path_makes_other_drive_relative_spelling_absolute() -> None:
    drive = "D" if Path.cwd().drive.upper() != "D:" else "C"
    assert full_path(Path(f"{drive}:folder")).is_absolute()
