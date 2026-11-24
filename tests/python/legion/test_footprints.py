import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import pytest
from filelock import FileLock, Timeout

from legion import _footprints

if sys.platform == "win32":
    import _winapi

LIB = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "lib"
PWSH = shutil.which("pwsh")


def powershell(script: str, *args: Path | str) -> subprocess.CompletedProcess[str]:
    assert PWSH is not None
    file = Path(os.environ["TMP"]) / "legion-cross-language.ps1"
    file.write_text(script, encoding="utf-8")
    try:
        return subprocess.run([PWSH, "-NoProfile", "-File", str(file), *map(str, args)], capture_output=True, text=True, check=True)
    finally:
        file.unlink()


def test_add_records_home_relative_path_and_merges_owners(tmp_path: Path) -> None:
    target = tmp_path / ".legion" / "bin" / "tool"
    _footprints.add(tmp_path, "file", target, "first")
    _footprints.add(tmp_path, "file", target, "second")
    data = json.loads(_footprints.footprint_index(tmp_path).read_text(encoding="utf-8"))
    assert data == {"schemaVersion": 1, "entries": [{"kind": "file", "path": "~/.legion/bin/tool", "key": "", "value": "", "owners": ["first", "second"]}]}


def test_remove_owner_deletes_owned_folder_but_keeps_edit(tmp_path: Path) -> None:
    folder = tmp_path / ".legion" / "old"
    folder.mkdir(parents=True)
    (folder / "child").write_text("x", encoding="utf-8")
    _footprints.add(tmp_path, "folder", folder, "account:a")
    _footprints.add(tmp_path, "edit", tmp_path / ".legion" / "notes.md", "account:a")
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"Remove folder: {folder}"]
    assert not folder.exists()
    assert [(entry.kind, entry.owners) for entry in _footprints.read(tmp_path).entries] == [("edit", [])]


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


@pytest.mark.skipif(PWSH is None, reason="pwsh unavailable")
def test_powershell_add_python_remove_and_python_add_powershell_read(tmp_path: Path) -> None:
    folder = tmp_path / ".legion" / "old"
    folder.mkdir(parents=True)
    script = ". $args[0]; Add-LegionFootprint -HomeRoot $args[1] -Kind folder -Path $args[2] -Owner account:a"
    powershell(script, LIB / "footprints.ps1", tmp_path, folder)
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"Remove folder: {folder}"]
    _footprints.add(tmp_path, "path-entry", "user PATH", "account:b")
    script = ". $args[0]; @(Get-LegionFootprints -HomeRoot $args[1] -Kind path-entry) | ConvertTo-Json -Compress"
    result = powershell(script, LIB / "footprints.ps1", tmp_path)
    assert json.loads(result.stdout)["owners"] == ["account:b"]


@pytest.mark.skipif(PWSH is None, reason="pwsh unavailable")
def test_powershell_and_python_share_footprint_lock(tmp_path: Path) -> None:
    assert PWSH is not None
    index = _footprints.footprint_index(tmp_path)
    index.parent.mkdir(parents=True)
    marker = tmp_path / "ready"
    script = ". $args[0]; $lock = Open-LegionLockFile -Path $args[1]; [IO.File]::WriteAllText($args[2], 'ready'); [Console]::WriteLine('ready'); [Console]::ReadLine() | Out-Null; $lock.Dispose()"
    script_file = tmp_path / "hold.ps1"
    script_file.write_text(script, encoding="utf-8")
    child = subprocess.Popen(
        [PWSH, "-NoProfile", "-File", str(script_file), str(LIB / "footprints.ps1"), str(index) + ".lock", str(marker)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        assert child.stdout.readline().strip() == "ready"
        assert marker.read_text(encoding="utf-8") == "ready"
        with pytest.raises(Timeout), FileLock(str(index) + ".lock", timeout=0):
            pass
    finally:
        assert child.stdin is not None
        if child.poll() is None:
            child.communicate("\n", timeout=5)
    with FileLock(str(index) + ".lock", timeout=0):
        script = ". $args[0]; $lock = Open-LegionLockFile -Path $args[1]; if ($null -eq $lock) { 'busy' } else { $lock.Dispose(); 'free' }"
        assert powershell(script, LIB / "footprints.ps1", str(index) + ".lock").stdout.strip() == "busy"
