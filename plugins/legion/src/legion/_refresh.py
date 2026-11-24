from pathlib import Path

from . import _accounts, _launchers, _settings_io


def refresh(home: Path) -> list[str]:
    lines: list[str] = []
    try:
        settings = _settings_io.load(home)
    except _settings_io.SettingsError as error:
        if str(error) == "No legion settings yet; add an agent first.":
            settings = None
        else:
            raise
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
                if "wrapper collision" in str(error):
                    lines.append(str(error))
                    continue
                if "not ready" in str(error):
                    lines.append(f"skip: account {agent.id} (the legion app is not ready)")
                    continue
                raise
        else:
            continue
        lines.extend(f"wrote: launcher {path}" for path in changed)
    lines.append("legion generated runtimes and launchers refreshed" if any(line.startswith("wrote:") for line in lines) else "skip: legion generated runtimes and launchers (already done)")
    return lines
