from pathlib import Path

from legion.services.accounts import _launchers
from legion.services.installation import _installed_runtime
from legion.core import _settings_io
from legion.core._home import owner_path_safe, settings_path
from legion.core._plugin import PLUGIN_ROOT


# The app is published and the owner commands point at it; accounts then launch through legion itself, so the
# per-account launchers older versions wrote are removed, and older app versions are pruned. The app lock covers all three.
def refresh(home: Path, source: Path = PLUGIN_ROOT, lock_timeout: float = 60) -> list[str]:
    if not owner_path_safe(home / ".legion", home):
        raise _settings_io.SettingsError("The legion folder contains a link; resolve it before refreshing")
    lines: list[str] = []
    changed = False
    with _settings_io.writer(home, require_existing=False):
        settings = _settings_io.load(home) if settings_path(home).is_file() else None
    with _installed_runtime.app_lock(home, lock_timeout) as held:
        ready = None
        if not held:
            lines.append("skip: legion app sync (another sync is still running; run legion setup again)")
        else:
            sync_lines, ready = _installed_runtime.sync_app(home, source)
            lines.extend(sync_lines)
            changed = any(line.endswith(" ready") for line in sync_lines)
            if ready is None:
                lines.append("skip: command legion (the legion app is not ready)")
            else:
                changed = bool(_installed_runtime.write_owner_commands(ready, home)) or changed
                lines.extend(_launchers.remove_old_launchers(settings.agents if settings else [], home))
        if ready is not None:
            lines.extend(_installed_runtime.prune_old_versions(ready, home))
    changed = changed or any(line.startswith("removed ") for line in lines)
    lines.append("legion generated runtimes and launchers refreshed" if changed else "skip: legion generated runtimes and launchers (already done)")
    return lines
