import hashlib
import json
import os
import shutil
import sys
import tempfile
from collections.abc import Iterator
from pathlib import Path

import pytest

if sys.platform == "win32":
    import _winapi
    import winreg

REPO = Path(__file__).resolve().parents[2]
CLEARED_ENVIRONMENT = ("LEGION_ROLE", "LEGION_TASK", "PYTHONSTARTUP", "PYTHONUSERBASE", "CODEX_THREAD_ID")


# The real user PATH is read only here: value and value type, or None when missing.
def user_path_snapshot() -> tuple[str, int] | None:
    if sys.platform != "win32":
        return None
    try:
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment") as key:
            value, kind = winreg.QueryValueEx(key, "Path")
            return str(value), kind
    except FileNotFoundError:
        return None


# Mirrors the fence in tests/run.ps1: every test runs with a temp home reached through a link, and the
# fake-real folder beside it must come out of the test unchanged.
class Fence:
    def __init__(self, root: Path) -> None:
        physical = root / "physical"
        (physical / "home").mkdir(parents=True)
        self.root = root
        self.config_environments = config_environments()
        self.link = root / "linked"
        self.outside = root / "fake-real"
        self.outside.mkdir()
        (self.outside / "keep.txt").write_text("owner sentinel", encoding="utf-8")
        if sys.platform == "win32":
            _winapi.CreateJunction(str(physical), str(self.link))
        else:
            self.link.symlink_to(physical, target_is_directory=True)
        self.home = self.link / "home"
        self.temp = self.home / "temp"
        self.temp.mkdir()
        self.sentinel = self.snapshot()
        self.user_path = user_path_snapshot()
        self.user_path_file = self.home / "user-path.txt"

    def snapshot(self) -> str:
        entries = sorted(path for path in self.outside.rglob("*") if path.is_file())
        return "|".join(f"{path}:{hashlib.sha256(path.read_bytes()).hexdigest()}" for path in entries)

    def check(self) -> None:
        assert self.snapshot() == self.sentinel, "Test changed the fake real folder"
        assert user_path_snapshot() == self.user_path, "Test changed the real user PATH value or registry value kind"
        record = self.home / "socket-attempts"
        assert not record.exists() or not record.read_bytes(), "Child attempted a socket connection"

    def remove(self, base: Path) -> None:
        assert self.root.resolve().is_relative_to(base.resolve()), "Unsafe fence cleanup"
        # Unlink first: recursive cleanup must never walk through the home link.
        if sys.platform == "win32":
            self.link.rmdir()
        else:
            self.link.unlink()
        shutil.rmtree(self.root)


def config_environments() -> list[str]:
    catalog = json.loads((REPO / "plugins" / "legion" / "tools.json").read_text(encoding="utf-8"))
    return [tool["configEnv"] for tool in catalog["tools"]]


# Fixture Git reads no inherited Git setting and no system config, so it cannot write an index or trace elsewhere.
def fence_git(monkeypatch: pytest.MonkeyPatch) -> None:
    for name in list(os.environ):
        if name.startswith("GIT_"):
            monkeypatch.delenv(name, raising=False)
    monkeypatch.setenv("GIT_CONFIG_NOSYSTEM", "1")


@pytest.fixture
def pwsh_path() -> Path:
    value = os.environ.get("LEGION_TEST_PWSH")
    if not value:
        pytest.fail("set LEGION_TEST_PWSH to the absolute path of pwsh, e.g. (Get-Command pwsh).Source")
    path = Path(value)
    assert path.is_absolute(), f"PowerShell interpreter path is not absolute: {path}"
    assert path.is_file(), f"PowerShell interpreter is missing: {path}"
    return path


@pytest.fixture(autouse=True)
def fence(tmp_path_factory: pytest.TempPathFactory, monkeypatch: pytest.MonkeyPatch) -> Iterator[Fence]:
    base = tmp_path_factory.getbasetemp()
    fence = Fence(Path(tempfile.mkdtemp(prefix="fence-", dir=base)))
    for name in ("HOME", "USERPROFILE"):
        monkeypatch.setenv(name, str(fence.home))
    for name in ("TMPDIR", "TEMP", "TMP"):
        monkeypatch.setenv(name, str(fence.temp))
    for name in ("UV_CACHE_DIR", "LOCALAPPDATA", "APPDATA", "XDG_CACHE_HOME", "XDG_CONFIG_HOME"):
        folder = fence.home / name
        folder.mkdir()
        monkeypatch.setenv(name, str(folder))
    # Children cannot inherit Python mocks. Standard proxy settings reject requests locally,
    # including on hosts with a proxy bypass list or lowercase proxy variables.
    for name in ("HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY"):
        for spelling in (name, name.lower()):
            monkeypatch.setenv(spelling, "http://127.0.0.1:1")
    for name in ("NO_PROXY", "no_proxy"):
        monkeypatch.setenv(name, "")
    monkeypatch.setattr(tempfile, "tempdir", str(fence.temp))
    # A child interpreter would otherwise write its bytecode cache wherever the developer's setting points.
    monkeypatch.setenv("PYTHONPYCACHEPREFIX", str(fence.temp / "pycache"))
    for name in fence.config_environments:
        monkeypatch.setenv(name, str(fence.home / name))
    for name in CLEARED_ENVIRONMENT:
        monkeypatch.delenv(name, raising=False)
    # Saved PATH writes land in a fence file; the process PATH is restored after the test.
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(fence.user_path_file))
    monkeypatch.setenv("PATH", os.environ.get("PATH", ""))
    fence_git(monkeypatch)
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", str(fence.home / "gitconfig"))
    # sitecustomize is loaded by child Python interpreters, including hooks started through uv.
    socket_fence = str(REPO / "tests/python/socket_fence")
    monkeypatch.setenv("PYTHONPATH", os.pathsep.join(filter(None, (socket_fence, os.environ.get("PYTHONPATH")))))
    monkeypatch.setenv("PYTHON_TEST_SOCKET_RECORD", str(fence.home / "socket-attempts"))
    try:
        yield fence
        fence.check()
    finally:
        fence.remove(base)
