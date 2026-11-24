from pathlib import Path

from . import _accounts, _app, _launchers, _settings_io
from ._home import settings_path
from ._plugin import PLUGIN_ROOT
from ._settings_models import Agent

NOT_READY = "the legion app is not ready"


def _wrote(paths: list[Path]) -> list[str]:
    return [f"wrote: launcher {path}" for path in paths]


def _repair_subscription(agent: Agent, home: Path) -> list[str]:
    state = _launchers.launcher_state(agent, home)
    if state == "intact":
        return _wrote(_launchers.restore_execute(agent, home))
    skipped = f"skip: account {agent.id} (CLI target not found or launcher needs repair)"
    if state == "partial" and agent.command is None:
        return [skipped]
    try:
        return _wrote(_launchers.write_subscription(agent, _accounts._tool(agent.tool), home))
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
def refresh(home: Path, source: Path = PLUGIN_ROOT, lock_timeout: float = 60) -> list[str]:
    lines: list[str] = []
    changed = False
    settings = _settings_io.load(home) if settings_path(home).is_file() else None
    agents = settings.agents if settings else []
    for agent in agents:
        if agent.provider is None:
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
            # A launcher must follow the version the lock holder publishes, so none is written without the lock.
            for agent in agents:
                if agent.provider is not None and agent.provider.kind == "foundry":
                    lines.extend(_write_foundry(agent, home))
        if ready is not None:
            pruned = _app.prune_old_versions(ready, home)
            lines.extend(pruned)
            changed = changed or any(line.startswith("removed ") for line in pruned)
    changed = changed or any(line.startswith("wrote:") for line in lines)
    lines.append("legion generated runtimes and launchers refreshed" if changed else "skip: legion generated runtimes and launchers (already done)")
    return lines
