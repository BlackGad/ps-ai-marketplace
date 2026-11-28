import json
import os
import shutil
import subprocess
import sys
import tempfile
from inspect import unwrap
from pathlib import Path
from typing import Optional

import pytest
from legion.services.installation import _user_path as user_path
import conftest
from conftest import (
    Fence,
    fence_git,
    pwsh_path,
    refuse_registry_write,
)

if sys.platform == "win32":
    import winreg


def test_missing_powershell_path_fails_with_setup_hint(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("LEGION_TEST_PWSH", raising=False)
    with pytest.raises(pytest.fail.Exception, match="set LEGION_TEST_PWSH to the absolute path of pwsh"):
        unwrap(pwsh_path)()


def test_fence_points_the_environment_at_the_linked_home(fence: Fence) -> None:
    assert Path(os.environ["HOME"]) == fence.home
    assert Path(os.environ["USERPROFILE"]) == fence.home
    assert Path(tempfile.gettempdir()) == fence.temp
    assert fence.link.is_dir()
    assert fence.config_environments
    for name in fence.config_environments:
        assert Path(os.environ[name]) == fence.home / name
    assert "LEGION_ROLE" not in os.environ
    assert "LEGION_TASK" not in os.environ
    # A Codex session names its thread here; lease tests assume no thread.
    assert "CODEX_THREAD_ID" not in os.environ
    # A child interpreter writes its bytecode cache and reads startup and user files only inside the fence.
    assert Path(os.environ["PYTHONPYCACHEPREFIX"]) == fence.temp / "pycache"
    assert "PYTHONSTARTUP" not in os.environ
    assert "PYTHONUSERBASE" not in os.environ
    assert {name for name in os.environ if name.startswith("GIT_")} == {"GIT_CONFIG_NOSYSTEM", "GIT_CONFIG_GLOBAL"}
    assert os.environ["GIT_CONFIG_NOSYSTEM"] == "1"


def test_fence_keeps_git_config_inside_temporary_home(fence: Fence) -> None:
    for name in ("XDG_CONFIG_HOME", "GIT_CONFIG_GLOBAL"):
        assert Path(os.environ[name]).resolve().is_relative_to(fence.home.resolve()), name


def test_fence_catches_a_change_to_the_fake_real_folder(fence: Fence) -> None:
    fence.check()
    sentinel = fence.outside / "keep.txt"
    sentinel.write_text("changed by a test", encoding="utf-8")
    with pytest.raises(AssertionError, match="fake real folder"):
        fence.check()
    sentinel.write_text("owner sentinel", encoding="utf-8")
    fence.check()


def test_child_inherits_cache_and_network_fences(fence: Fence) -> None:
    names = ["UV_CACHE_DIR", "LOCALAPPDATA", "APPDATA", "XDG_CACHE_HOME", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "NO_PROXY"]
    script = "import json, os, sys; print(json.dumps({name: os.environ.get(name) for name in sys.argv[1:]}))"
    child = subprocess.run([sys.executable, "-c", script, *names], capture_output=True, text=True, check=True)
    environment = json.loads(child.stdout)
    for name in names[:4]:
        assert environment[name], name
        assert Path(environment[name]).resolve().is_relative_to(fence.home.resolve()), name
    for name in names[4:7]:
        assert environment[name] == "http://127.0.0.1:1", name
    # Windows omits empty environment values when it starts a child.
    assert not environment["NO_PROXY"]


def test_child_socketpair_allows_asyncio_without_network() -> None:
    script = "import asyncio, socket\na, b = socket.socketpair()\na.send(b'x')\nassert b.recv(1) == b'x'\na.close()\nb.close()\nasyncio.run(asyncio.sleep(0))"
    child = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, timeout=10, check=False)
    assert child.returncode == 0, child.stderr


def test_child_socket_denial_records_even_swallowed_requests(fence: Fence) -> None:
    script = """
import socket, urllib.error, urllib.request
assert socket.socket.__module__ == 'sitecustomize', 'child socket denial is missing'
for scheme in ('http', 'https'):
    try:
        urllib.request.urlopen(f"{scheme}://network-fence.invalid", timeout=1)
    except urllib.error.URLError:
        pass
    else:
        raise AssertionError('request escaped the socket denial')
for method in ('connect', 'connect_ex'):
    with socket.socket() as connection:
        try:
            getattr(connection, method)(('127.0.0.1', 1))
        except OSError:
            pass
"""
    child = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, timeout=5, check=False)
    assert child.returncode == 0, child.stderr
    record = fence.home / "socket-attempts"
    try:
        assert len(record.read_text(encoding="utf-8").splitlines()) == 4
        with pytest.raises(AssertionError, match="socket"):
            fence.check()
    finally:
        record.unlink(missing_ok=True)


# Fixture Git never writes outside the fixture through an inherited setting, such as an index or a trace file.
def test_fixture_git_ignores_inherited_settings(fence: Fence, tmp_path: Path) -> None:
    git = shutil.which("git")
    assert git is not None
    index, trace = fence.outside / "index", fence.outside / "trace2.json"
    index.write_bytes(b"outside index sentinel")
    repo = tmp_path / "repo"
    repo.mkdir()
    (repo / "file.txt").write_text("fixture", encoding="utf-8")
    try:
        with pytest.MonkeyPatch.context() as patch:
            patch.setenv("GIT_INDEX_FILE", str(index))
            patch.setenv("GIT_TRACE2_EVENT", str(trace))
            fence_git(patch)
            for words in (["init", "--quiet"], ["add", "file.txt"]):
                result = subprocess.run([git, "-C", str(repo), *words], stdin=subprocess.DEVNULL, capture_output=True, text=True, check=False)
                assert result.returncode == 0, result.stderr
        assert index.read_bytes() == b"outside index sentinel"
        assert not trace.exists()
        assert (repo / ".git" / "index").is_file()
    finally:
        index.unlink()
        trace.unlink(missing_ok=True)


@pytest.mark.skipif(sys.platform != "win32", reason="Windows saved PATH")
def test_default_fence_sends_user_path_writes_to_the_fence_file_not_the_registry(fence: Fence, monkeypatch: pytest.MonkeyPatch) -> None:
    assert sys.platform == "win32"
    writes: list[tuple[object, ...]] = []
    monkeypatch.setattr(winreg, "SetValueEx", lambda *args: writes.append(args))
    user_path.add(fence.home, fence.home / ".legion/bin")
    assert str(fence.home / ".legion/bin") in fence.user_path_file.read_text(encoding="utf-8")
    assert writes == []


@pytest.mark.skipif(sys.platform != "win32", reason="Windows registry")
def test_fence_refuses_direct_registry_writes() -> None:
    assert sys.platform == "win32"
    assert winreg.SetValueEx is refuse_registry_write
    assert winreg.DeleteValue is refuse_registry_write
    with pytest.raises(AssertionError, match="wrote the registry"):
        refuse_registry_write()


@pytest.mark.parametrize(
    ("before", "after"),
    [(("a", 1), ("b", 1)), (("a", 1), ("a", 2)), (None, ("a", 1)), (("a", 1), None)],
    ids=["value", "kind", "missing-to-present", "present-to-missing"],
)
def test_fence_check_fails_when_the_user_path_snapshot_changes(fence: Fence, before: Optional[tuple[str, int]], after: Optional[tuple[str, int]]) -> None:
    original = fence.user_path
    fence.user_path = before
    try:
        with pytest.MonkeyPatch.context() as patch:
            patch.setattr(conftest, "user_path_snapshot", lambda: after)
            with pytest.raises(AssertionError, match="real user PATH"):
                fence.check()
    finally:
        fence.user_path = original
