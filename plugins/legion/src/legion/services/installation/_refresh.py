from pathlib import Path
from typing import Optional

from legion.services.installation import _uv_tool
from legion.core import _settings_io
from legion.core._home import owner_path_safe, settings_path
from legion.core._plugin import PLUGIN_ROOT


# Legion is installed as a uv tool from the plugin at `source`; accounts launch through legion itself.
# Settings are read under their lock right before, and broken settings stop the refresh before anything is installed.
# `detached` and `update_shell` are passed on to the uv install.
def refresh(home: Path, source: Path = PLUGIN_ROOT, detached: Optional[bool] = None, update_shell: bool = False) -> list[str]:
    if not owner_path_safe(home / ".legion", home):
        raise _settings_io.SettingsError("The legion folder contains a link; resolve it before refreshing")
    with _settings_io.writer(home, require_existing=False):
        if settings_path(home).is_file():
            _settings_io.load(home)
    return _uv_tool.install(source, home, detached=detached, update_shell=update_shell)
