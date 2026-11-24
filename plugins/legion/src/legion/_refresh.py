from pathlib import Path

from . import _accounts, _launchers, _settings_io
from ._home import settings_path


def refresh(home: Path) -> list[str]:
    lines: list[str] = []
    settings = _settings_io.load(home) if settings_path(home).is_file() else None
    for agent in settings.agents if settings else []:
        if agent.provider is None:
            state = _launchers.launcher_state(agent, home)
            if state == "intact":
                changed = _launchers.restore_execute(agent, home)
                lines.extend(f"wrote: launcher {path}" for path in changed)
                continue
            if state == "partial" and agent.command is None:
                lines.append(f"skip: account {agent.id} (CLI target not found or launcher needs repair)")
                continue
            tool = _accounts._tool(agent.tool)
            try:
                changed = _launchers.write_subscription(agent, tool, home)
            except _launchers.LauncherError:
                lines.append(f"skip: account {agent.id} (CLI target not found or launcher needs repair)")
                continue
        elif agent.provider.kind == "foundry":
            try:
                changed = _launchers.write_foundry(agent, home)
            except _launchers.LauncherError as error:
                lines.append(f"skip: account {agent.id} ({error})")
                continue
        else:
            continue
        lines.extend(f"wrote: launcher {path}" for path in changed)
    lines.append("legion generated runtimes and launchers refreshed" if any(line.startswith("wrote:") for line in lines) else "skip: legion generated runtimes and launchers (already done)")
    return lines
