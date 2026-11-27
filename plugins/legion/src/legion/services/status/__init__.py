import shutil
from pathlib import Path
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict

from legion.services.repository import _lease
from legion.services.installation import _knowledge_hub
from legion.services.status import _status
from legion.core._home import (
    bin_folder,
    home_path,
    legion_home,
    settings_path,
)
from legion.core._run import run_command
from legion.core._settings_models import PersonalisationSettings, ToolDescriptor
from legion.core._validate import load_descriptors, read_text


class SettingsState(BaseModel):
    model_config = ConfigDict(frozen=True)

    state: Literal["ok", "missing", "unreadable", "invalid"]
    path: str


class AccountStatus(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: str
    tool: str
    config_dir: str
    legion_version: Optional[str]


class ChannelStatus(BaseModel):
    model_config = ConfigDict(frozen=True)

    id: str
    kind: str
    accounts: list[str]


class RepositoryStatus(BaseModel):
    model_config = ConfigDict(frozen=True)

    mode: Literal["none", "Private", "Shared"] = "none"
    lease: Optional[_lease.State] = None
    handoff: Optional[bool] = None


class KnowledgeStatus(BaseModel):
    model_config = ConfigDict(frozen=True)

    state: Literal["on", "off", "declined"]
    hub: Optional[Literal["ready", "missing", "invalid"]] = None
    hub_repository: Optional[bool] = None
    missing_accounts: list[str]


class StatusReport(BaseModel):
    model_config = ConfigDict(frozen=True)

    settings: SettingsState
    accounts: list[AccountStatus]
    on_path: bool
    commands: Literal["yes", "blocked", "missing", "not executable"]
    channels: list[ChannelStatus]
    repository: RepositoryStatus
    knowledge: KnowledgeStatus
    warnings: list[str]


def repository_status(repo: Path) -> RepositoryStatus:
    legion = repo / ".legion"
    required = ["configuration/project.json", "configuration/workflow.md", "scripts/index.md"]
    if any(not (legion / file).is_file() for file in required):
        return RepositoryStatus()
    private = (legion / ".git").exists()
    root = legion if private else repo
    paths = required if private else [f".legion/{file}" for file in required]
    git = shutil.which("git")
    if git is None:
        return RepositoryStatus()
    try:
        result = run_command(git, ["-C", str(root), "ls-files", "--error-unmatch", "--", *paths], timeout=5)
        if result.exit_code != 0:
            return RepositoryStatus()
    except OSError:
        return RepositoryStatus()
    return RepositoryStatus(mode="Private" if private else "Shared", lease=_lease.state(repo).state, handoff=(legion / "state/handoff.md").is_file())


def status(repo: Path, home: Optional[Path] = None) -> StatusReport:
    home = legion_home(home)
    file = settings_path(home)
    settings = None
    state: Literal["ok", "missing", "unreadable", "invalid"] = "ok"
    # Never expose broken settings or validation errors containing their values.
    try:
        settings = PersonalisationSettings.model_validate_json(read_text(file))
    except FileNotFoundError:
        state = "missing"
    except OSError:
        state = "unreadable"
    except ValueError:
        state = "invalid"
    try:
        tools = load_descriptors(ToolDescriptor, "tool.json")
    except (OSError, ValueError):
        tools = []
    accounts = []
    missing_wiki = []
    knowledge = settings.knowledge_enabled if settings else None
    if settings is not None:
        for agent in settings.agents:
            matches = [tool for tool in tools if tool.id == agent.tool]
            tool = matches[0] if len(matches) == 1 else None
            config = home_path(agent.config_dir, home)
            version = _status.installed_version(config, tool) if tool else None
            if knowledge and (tool is None or _status.installed_version(config, tool, "wiki") is None):
                missing_wiki.append(agent.id)
            accounts.append(AccountStatus(id=agent.id, tool=agent.tool, config_dir=agent.config_dir, legion_version=version))
    folder = bin_folder(home)
    return StatusReport(
        settings=SettingsState(state=state, path=str(file)),
        accounts=accounts,
        on_path=_status.on_path(folder),
        commands=_status.command_status(folder),
        channels=[ChannelStatus(id=channel.id, kind=channel.kind, accounts=channel.accounts) for channel in settings.channels] if settings else [],
        repository=repository_status(repo),
        knowledge=KnowledgeStatus(
            state="on" if knowledge else "declined" if knowledge is False else "off",
            hub=_knowledge_hub.hub_status(home) if knowledge else None,
            hub_repository=_knowledge_hub.is_repository(home) if knowledge else None,
            missing_accounts=missing_wiki,
        ),
        warnings=_status.channel_warnings(settings, home, tools) if settings else [],
    )
