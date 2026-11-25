from pathlib import Path

from legion.services.accounts import _accounts, _launchers
from legion.services.app import _app
from legion.core import _settings_io
from legion.core._home import owner_path_safe, settings_path
from legion.core._plugin import PLUGIN_ROOT
from legion.core._settings_models import Agent

NOT_READY = "the legion app is not ready"


def _wrote(paths: list[Path]) -> list[str]:
    return [f"wrote: launcher {path}" for path in paths]


def _repair_subscription(agent: Agent, home: Path) -> list[str]:
    state = _launchers.launcher_state(agent, home)
    if state == "intact" and agent.command is None:
        return _wrote(_launchers.restore_execute(agent, home))
    skipped = f"skip: account {agent.id} (CLI target not found or launcher needs repair)"
    if state == "partial" and agent.command is None:
        return [skipped]
    try:
        return _wrote(_launchers.write_subscription(agent, _accounts.get_tool(agent.tool), home))
    except _launchers.LauncherError:
        return [skipped]


def _write_foundry(agent: Agent, home: Path) -> list[str]:
    if not _app.ready_versions(home):
        return [f"skip: account {agent.id} ({NOT_READY})"]
    try:
        return _wrote(_launchers.write_foundry(agent, home))
    except _launchers.LauncherError as error:
        return [f"skip: account {agent.id} ({error})"]


# Order matters: subscription launchers are repaired first, then the app is published, and the Foundry launchers
# point at the version that is ready before any older version is pruned. The app lock covers publish and prune.
def refresh(home: Path, source: Path = PLUGIN_ROOT, lock_timeout: float = 60, skip: frozenset[str] | set[str] = frozenset()) -> list[str]:
    if not owner_path_safe(home / ".legion", home):
        raise _settings_io.SettingsError("The legion folder contains a link; resolve it before refreshing")
    lines: list[str] = []
    changed = False
    with _settings_io.writer(home, require_existing=False):
        settings = _settings_io.load(home) if settings_path(home).is_file() else None
        for agent in settings.agents if settings else []:
            if agent.provider is None and agent.id not in skip:
                lines.extend(_repair_subscription(agent, home))
    with _app.app_lock(home, lock_timeout) as held:
        ready = None
        if not held:
            lines.append("skip: legion app sync (another sync is still running; run legion setup again)")
        else:
            sync_lines, ready = _app.sync_app(home, source)
            lines.extend(sync_lines)
            changed = any(line.endswith(" ready") for line in sync_lines)
            if ready is None:
                lines.append("skip: command legion (the legion app is not ready)")
            else:
                changed = bool(_app.write_owner_commands(ready, home)) or changed
            # A failed publish can return the old ready app. Its launchers must keep calling the old runner.
            published = any(line.endswith((" ready", "(already done)", " in place)")) for line in sync_lines)
            with _settings_io.writer(home, require_existing=False):
                settings = _settings_io.load(home) if settings_path(home).is_file() else None
                for agent in settings.agents if settings else []:
                    if agent.provider is not None and agent.provider.kind == "foundry":
                        lines.extend(_write_foundry(agent, home) if published else [f"skip: account {agent.id} ({NOT_READY})"])
        if ready is not None:
            pruned = _app.prune_old_versions(ready, home)
            lines.extend(pruned)
            changed = changed or any(line.startswith("removed ") for line in pruned)
    changed = changed or any(line.startswith("wrote:") for line in lines)
    lines.append("legion generated runtimes and launchers refreshed" if changed else "skip: legion generated runtimes and launchers (already done)")
    return lines
