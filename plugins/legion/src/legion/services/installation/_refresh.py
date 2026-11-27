from pathlib import Path

from legion.services.accounts import _launchers
from legion.services.installation import _uv_tool
from legion.core import _settings_io
from legion.core._home import owner_path_safe, settings_path
from legion.core._plugin import PLUGIN_ROOT


# Legion is installed as a uv tool from the plugin at `source`; accounts then launch through legion itself, so the
# per-account launchers older versions wrote are removed. They go only when the tool's legion answers `run`.
# Settings are read under their lock right before, and the lock is held until the files are gone.
# `detached` leaves the uv step to a helper that runs after this process exits, so it cannot clean the launchers yet.
def refresh(home: Path, source: Path = PLUGIN_ROOT, detached: bool = False) -> list[str]:
    if not owner_path_safe(home / ".legion", home):
        raise _settings_io.SettingsError("The legion folder contains a link; resolve it before refreshing")
    # Broken settings stop the refresh before anything is installed.
    with _settings_io.writer(home, require_existing=False):
        if settings_path(home).is_file():
            _settings_io.load(home)
    lines = _uv_tool.install(source, detached=detached)
    uv = _uv_tool.find_uv()
    if detached or uv is None or not _launchers.candidates(home):
        return lines
    if not _uv_tool.has_account_run(uv):
        return [*lines, "skip: old account launchers (the legion command cannot start accounts yet)"]
    with _settings_io.writer(home, require_existing=False):
        settings = _settings_io.load(home) if settings_path(home).is_file() else None
        return [*lines, *_launchers.remove_old_launchers(settings.agents if settings else [], home)]
