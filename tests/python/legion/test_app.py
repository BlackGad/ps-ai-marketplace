import subprocess
import sys
import ctypes
from pathlib import Path
from typing import Any

from legion import _app, _footprints

if sys.platform == "win32":
    import _winapi


def test_ready_versions_uses_recorded_marked_safe_versions(tmp_path: Path) -> None:
    app = tmp_path / ".legion" / "app"
    for name in ("1.2.0", "1.10.0", "2.0.0"):
        folder = app / name
        folder.mkdir(parents=True)
        _footprints.add(tmp_path, "app-version", folder, "install")
    (app / "1.2.0" / ".legion-app-ready").touch()
    (app / "1.10.0" / ".legion-app-ready").touch()
    assert [item.path for item in _app.ready_versions(tmp_path)] == [app / "1.10.0", app / "1.2.0"]


def test_python_environment_matches_powershell_for_plain_linked_case_and_temp(tmp_path: Path, fence: Any, pwsh_path: Path) -> None:
    paths = [tmp_path / "plain", tmp_path / "MixedCase", Path(fence.temp)]
    for path in paths[:2]:
        path.mkdir()
    linked = tmp_path / "linked"
    try:
        linked.symlink_to(paths[0], target_is_directory=True)
        paths.append(linked)
    except (OSError, NotImplementedError):
        if sys.platform == "win32":
            _winapi.CreateJunction(str(paths[0]), str(linked))
            paths.append(linked)
    nested = tmp_path / "outer" / "deep"
    nested.mkdir(parents=True)
    lexical_link = tmp_path / "nested-link"
    try:
        lexical_link.symlink_to(nested, target_is_directory=True)
    except (OSError, NotImplementedError):
        if sys.platform == "win32":
            _winapi.CreateJunction(str(nested), str(lexical_link))
    if lexical_link.exists():
        paths.append(lexical_link / ".." / "MixedCase")
    if sys.platform == "win32":
        long_name = tmp_path / "Long Folder Name"
        long_name.mkdir()
        short_name = ctypes.create_unicode_buffer(32768)
        if ctypes.windll.kernel32.GetShortPathNameW(str(long_name), short_name, len(short_name)) and short_name.value != str(long_name):
            paths.append(Path(short_name.value))
    script = tmp_path / "env.ps1"
    script.write_text(". $args[0]; Get-LegionPythonEnvironment -PluginRoot $args[1] -HomeRoot $args[2]", encoding="utf-8")
    lib = Path(__file__).resolve().parents[3] / "plugins" / "legion" / "bin" / "lib" / "paths.ps1"
    for path in paths:
        result = subprocess.run([str(pwsh_path), "-NoProfile", "-File", str(script), str(lib), str(path), str(tmp_path)], capture_output=True, text=True, check=True)
        assert Path(result.stdout.strip()) == _app.python_environment(path, tmp_path)
