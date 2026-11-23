import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

import pytest
from conftest import Fence


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


def test_child_requests_fail_at_the_local_proxy() -> None:
    script = """
import urllib.error, urllib.request
proxies = urllib.request.getproxies()
for scheme in ("http", "https"):
    assert proxies[scheme] == "http://127.0.0.1:1", proxies
    try:
        urllib.request.urlopen(f"{scheme}://network-fence.invalid", timeout=1)
    except urllib.error.URLError as error:
        assert isinstance(error.reason, (ConnectionRefusedError, TimeoutError)), error
    else:
        raise AssertionError("Test request escaped the local proxy")
"""
    child = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, timeout=5, check=False)
    assert child.returncode == 0, child.stderr
