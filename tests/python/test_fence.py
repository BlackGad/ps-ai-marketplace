import os
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
