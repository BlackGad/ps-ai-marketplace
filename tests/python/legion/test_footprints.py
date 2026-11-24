import json
import os
import queue
import subprocess
import sys
import threading
from pathlib import Path

import pytest
from filelock import FileLock

from legion import _footprints
from legion._generated import header

if sys.platform == "win32":
    import _winapi

LIB = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "lib"


def powershell(pwsh_path: Path, script: str, *args: Path | str) -> subprocess.CompletedProcess[str]:
    file = Path(os.environ["TMP"]) / "legion-cross-language.ps1"
    file.write_text(script, encoding="utf-8")
    try:
        return subprocess.run([str(pwsh_path), "-NoProfile", "-File", str(file), *map(str, args)], capture_output=True, text=True, check=True)
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


@pytest.mark.parametrize("name", ["Documents", ".legion"])
def test_remove_owner_preserves_folder_outside_legion_tree(tmp_path: Path, name: str) -> None:
    folder = tmp_path / name
    folder.mkdir(parents=True)
    child = folder / "keep.txt"
    child.write_text("owner data", encoding="utf-8")
    _footprints.add(tmp_path, "folder", folder, "account:a")
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"skip: {folder} (linked or not legion's)"]
    assert child.read_text(encoding="utf-8") == "owner data"


def test_powershell_link_safety_compares_recorded_target(tmp_path: Path, pwsh_path: Path) -> None:
    target = tmp_path / "target"
    target.mkdir()
    link = tmp_path / ".legion" / "link"
    link.parent.mkdir()
    if sys.platform == "win32":
        _winapi.CreateJunction(str(target), str(link))
    else:
        link.symlink_to(target, target_is_directory=True)
    recorded = str(link.readlink())
    entry = _footprints.Footprint(kind="link", path="~/.legion/link", value=recorded, owners=["account:a"])
    assert _footprints.is_safe(entry, tmp_path)
    assert not _footprints.is_safe(entry.model_copy(update={"value": "other"}), tmp_path)
    power_shell_target = powershell(pwsh_path, "(Get-Item -LiteralPath $args[0] -Force).LinkTarget", link).stdout.strip()
    assert _footprints.is_safe(entry.model_copy(update={"value": power_shell_target}), tmp_path)


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


def test_powershell_add_python_remove_and_python_add_powershell_read(tmp_path: Path, pwsh_path: Path) -> None:
    folder = tmp_path / ".legion" / "old"
    folder.mkdir(parents=True)
    script = ". $args[0]; Add-LegionFootprint -HomeRoot $args[1] -Kind folder -Path $args[2] -Owner account:a"
    powershell(pwsh_path, script, LIB / "footprints.ps1", tmp_path, folder)
    assert _footprints.remove_owner(tmp_path, ["account:a"]) == [f"Remove folder: {folder}"]
    _footprints.add(tmp_path, "path-entry", "user PATH", "account:b")
    script = ". $args[0]; @(Get-LegionFootprints -HomeRoot $args[1] -Kind path-entry) | ConvertTo-Json -Compress"
    result = powershell(pwsh_path, script, LIB / "footprints.ps1", tmp_path)
    assert json.loads(result.stdout)["owners"] == ["account:b"]
    _footprints.add(tmp_path, "edit", tmp_path / ".legion" / "notes.md", "account:c")
    suffix = ".cmd" if sys.platform == "win32" else ""
    command = tmp_path / ".legion" / "bin" / f"legion{suffix}"
    command.parent.mkdir(parents=True)
    text = f"{header('owner command', True)}\r\n" if suffix else f"#!/bin/sh\n{header('owner command', False)}\n"
    command.write_bytes(text.encode("utf-8"))
    _footprints.add(tmp_path, "file", command, "account:c")
    script = ". $args[0]; Remove-LegionFootprintOwner -HomeRoot $args[1] -Owner account:c"
    powershell(pwsh_path, script, LIB / "footprints.ps1", tmp_path)
    assert not command.exists()
    edits = [entry for entry in _footprints.read(tmp_path).entries if entry.kind == "edit"]
    assert len(edits) == 1
    assert edits[0].owners == []


def test_powershell_and_python_share_footprint_lock(tmp_path: Path, pwsh_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    index = _footprints.footprint_index(tmp_path)
    index.parent.mkdir(parents=True)
    marker = tmp_path / "ready"
    script = ". $args[0]; $lock = Open-LegionLockFile -Path $args[1]; [IO.File]::WriteAllText($args[2], 'ready'); [Console]::WriteLine('ready'); [Console]::ReadLine() | Out-Null; $lock.Dispose()"
    script_file = tmp_path / "hold.ps1"
    script_file.write_text(script, encoding="utf-8")
    child = subprocess.Popen(
        [str(pwsh_path), "-NoProfile", "-File", str(script_file), str(LIB / "footprints.ps1"), str(index) + ".lock", str(marker)],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert child.stdout is not None
        output = child.stdout
        messages: queue.Queue[str] = queue.Queue()
        threading.Thread(target=lambda: messages.put(output.readline()), daemon=True).start()
        try:
            ready = messages.get(timeout=30)
        except queue.Empty:
            child.kill()
            _, diagnostics = child.communicate(timeout=60)
            pytest.fail(f"PowerShell lock child did not become ready: {diagnostics}")
        if ready.strip() != "ready":
            if child.poll() is None:
                assert child.stdin is not None
                child.stdin.write("\n")
                child.stdin.flush()
            try:
                _, diagnostics = child.communicate(timeout=60)
            except subprocess.TimeoutExpired:
                child.kill()
                _, diagnostics = child.communicate(timeout=5)
            pytest.fail(f"PowerShell lock child reported {ready.strip()!r}: {diagnostics}")
        assert marker.read_text(encoding="utf-8") == "ready"
        real_lock = _footprints.FileLock

        def immediate(path: str, timeout: int) -> FileLock:
            assert timeout == 30
            return real_lock(path, timeout=0)

        with monkeypatch.context() as patch:
            patch.setattr(_footprints, "FileLock", immediate)
            with pytest.raises(_footprints.FootprintError, match="Footprint index is busy"), _footprints.lock(tmp_path):
                pass
    finally:
        if child.poll() is None:
            assert child.stdin is not None
            child.stdin.write("\n")
            child.stdin.flush()
        try:
            child.communicate(timeout=60)
        except subprocess.TimeoutExpired:
            child.kill()
            child.communicate(timeout=5)
            pytest.fail("PowerShell lock child stalled after release")
    with _footprints.lock(tmp_path):
        script = ". $args[0]; $lock = Open-LegionLockFile -Path $args[1]; if ($null -eq $lock) { 'busy' } else { $lock.Dispose(); 'free' }"
        assert powershell(pwsh_path, script, LIB / "footprints.ps1", str(index) + ".lock").stdout.strip() == "busy"
