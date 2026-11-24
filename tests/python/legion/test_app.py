from pathlib import Path
import shutil
import subprocess
from typing import Any

import pytest

from legion import _app, _footprints

PWSH = shutil.which("pwsh")


def test_ready_versions_uses_recorded_marked_safe_versions(tmp_path: Path) -> None:
    app = tmp_path / ".legion" / "app"
    for name in ("1.2.0", "1.10.0", "2.0.0"):
        folder = app / name
        folder.mkdir(parents=True)
        _footprints.add(tmp_path, "app-version", folder, "install")
    (app / "1.2.0" / ".legion-app-ready").touch()
    (app / "1.10.0" / ".legion-app-ready").touch()
    assert [item.path for item in _app.ready_versions(tmp_path)] == [app / "1.10.0", app / "1.2.0"]


@pytest.mark.skipif(PWSH is None, reason="pwsh unavailable")
def test_python_environment_matches_powershell_for_plain_linked_case_and_temp(tmp_path: Path, fence: Any) -> None:
    assert PWSH is not None
    paths = [tmp_path / "plain", tmp_path / "MixedCase", Path(fence.temp)]
    for path in paths[:2]:
        path.mkdir()
    linked = tmp_path / "linked"
    try:
        linked.symlink_to(paths[0], target_is_directory=True)
        paths.append(linked)
    except (OSError, NotImplementedError):
        pass
    script = tmp_path / "env.ps1"
    script.write_text(". $args[0]; Get-LegionPythonEnvironment -PluginRoot $args[1] -HomeRoot $args[2]", encoding="utf-8")
    lib = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "lib" / "paths.ps1"
    for path in paths:
        result = subprocess.run([PWSH, "-NoProfile", "-File", str(script), str(lib), str(path), str(tmp_path)], capture_output=True, text=True, check=True)
        assert Path(result.stdout.strip()) == _app.python_environment(path, tmp_path)
