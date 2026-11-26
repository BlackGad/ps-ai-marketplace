import json
import os
import sys
from pathlib import Path

import pytest

from legion.services.repository import _footprints
from legion.core._settings_models import ToolDescriptor
from legion.core._validate import load_descriptors

if sys.platform == "win32":
    import _winapi


def test_add_records_home_relative_path_and_merges_owners(tmp_path: Path) -> None:
    target = tmp_path / ".legion" / "bin" / "tool"
    _footprints.add(tmp_path, "file", target, "first")
    _footprints.add(tmp_path, "file", target, "second")
    data = json.loads(_footprints.footprint_index(tmp_path).read_text(encoding="utf-8"))
    assert data == {"schemaVersion": 1, "entries": [{"kind": "file", "path": "~/.legion/bin/tool", "key": "", "value": "", "owners": ["first", "second"]}]}


def test_an_index_of_the_previous_release_loses_only_the_retired_kinds(tmp_path: Path) -> None:
    entries = [
        {"kind": "app", "path": "~/.legion/app", "key": "", "value": "", "owners": ["claude:/x"]},
        {"kind": "edit", "path": "/x/settings.json", "key": "permissions.allow", "value": "rule", "owners": ["claude:/x"]},
        {"kind": "link", "path": "~/.legion/link", "key": "", "value": "/y", "owners": ["account:a"]},
        {"kind": "app-version", "path": "~/.legion/app/1.0.0", "key": "", "value": "", "owners": ["legion"]},
        {"kind": "path-entry", "path": "user PATH", "key": "", "value": "C:/bin", "owners": ["legion"]},
    ]
    index = _footprints.footprint_index(tmp_path)
    index.parent.mkdir(parents=True)
    index.write_text(json.dumps({"schemaVersion": 1, "entries": entries}), encoding="utf-8")
    assert [entry.kind for entry in _footprints.read(tmp_path).entries] == ["app-version", "path-entry"]


def test_remove_owner_deletes_owned_folder_but_keeps_other_records(tmp_path: Path) -> None:
    folder = tmp_path / ".legion" / "old"
    folder.mkdir(parents=True)
    (folder / "child").write_text("x", encoding="utf-8")
    _footprints.add(tmp_path, "folder", folder, "account:a")
    _footprints.add(tmp_path, "path-entry", tmp_path / ".legion" / "notes.md", "account:a")
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"Remove folder: {folder}"]
    assert not folder.exists()
    assert [(entry.kind, entry.owners) for entry in _footprints.read(tmp_path).entries] == [("path-entry", [])]


@pytest.mark.parametrize("name", ["Documents", ".legion"])
def test_remove_owner_preserves_folder_outside_legion_tree(tmp_path: Path, name: str) -> None:
    folder = tmp_path / name
    folder.mkdir(parents=True)
    child = folder / "keep.txt"
    child.write_text("owner data", encoding="utf-8")
    _footprints.add(tmp_path, "folder", folder, "account:a")
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"skip: {folder} (linked or not legion's)"]
    assert child.read_text(encoding="utf-8") == "owner data"


def test_remove_entry_matches_absolute_and_home_relative_path(tmp_path: Path) -> None:
    target = tmp_path / ".legion" / "bin" / "tool"
    _footprints.add(tmp_path, "file", target, "account:a")
    _footprints.remove_entry(tmp_path, "file", "~/.legion/bin/tool")
    assert _footprints.read(tmp_path).entries == []


def test_linked_index_parent_refuses_before_write(tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    link = tmp_path / ".legion"
    if sys.platform == "win32":
        _winapi.CreateJunction(str(outside), str(link))
    else:
        link.symlink_to(outside, target_is_directory=True)
    with pytest.raises(_footprints.FootprintError, match="Footprint index contains a link"):
        _footprints.add(tmp_path, "file", link / "bin" / "tool", "account:a")
    assert list(outside.iterdir()) == []


def test_remove_owner_keeps_unowned_file(tmp_path: Path) -> None:
    target = tmp_path / ".legion" / "bin" / "foreign"
    target.parent.mkdir(parents=True)
    target.write_text("foreign", encoding="utf-8")
    _footprints.add(tmp_path, "file", target, "account:a")
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"skip: {target} (linked or not legion's)"]
    assert target.read_text(encoding="utf-8") == "foreign"


def test_link_in_owned_folder_is_not_deleted(tmp_path: Path) -> None:
    folder = tmp_path / ".legion" / "old"
    folder.mkdir(parents=True)
    if sys.platform == "win32":
        _winapi.CreateJunction(str(tmp_path), str(folder / "link"))
    else:
        (folder / "link").symlink_to(tmp_path, target_is_directory=True)
    _footprints.add(tmp_path, "folder", folder, "account:a")
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"skip: {folder} (linked or not legion's)"]
    assert folder.exists()


def test_the_target_owner_names_the_tool_and_the_resolved_folder(tmp_path: Path) -> None:
    claude = next(tool for tool in load_descriptors(ToolDescriptor, "tool.json") if tool.id == "claude")
    folder = tmp_path / "account folder"
    folder.mkdir()
    expected = f"claude:{folder.resolve()}"
    assert _footprints.target_owner(claude, str(folder) + os.sep, tmp_path) == (expected.lower() if sys.platform == "win32" else expected)
    assert _footprints.target_owner(claude, "~/account folder", tmp_path) == _footprints.target_owner(claude, str(folder), tmp_path)
    default = _footprints.target_owner(claude, None, tmp_path)
    assert default.startswith("claude:")
    assert default.endswith(".claude".lower() if sys.platform == "win32" else ".claude")
