import codecs
import json
from pathlib import Path

from pydantic import (
    BaseModel,
    ValidationError,
)
from pydantic_core import ErrorDetails

from ._plugin import PLUGIN_ROOT
from ._settings_models import (
    ChannelDescriptor,
    PersonalisationSettings,
    ProjectSettings,
    ToolDescriptor,
)

FRAME = "$: {}; run legion setup to update your settings"


def _framed(message: str) -> str:
    return FRAME.format(" ".join(message.split()))


# A settings file may be saved as UTF-8 or, with a byte-order mark, as UTF-16.
def read_text(path: Path) -> str:
    data = path.read_bytes()
    encoding = "utf-16" if data[:2] in (codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE) else "utf-8-sig"
    return data.decode(encoding)


# JSON allows a key twice and keeps the last value; legion settings reject it.
def _unique_keys(pairs: list[tuple[str, object]]) -> dict[str, object]:
    keys = [key for key, _ in pairs]
    for key in keys:
        if keys.count(key) > 1:
            raise ValueError(f"duplicate key '{key}'")
    return dict(pairs)


# One schema problem as `agents[0].id: <message>`, the path written like legion's own messages.
def _describe(problem: ErrorDetails) -> str:
    where = "".join(f"[{part}]" if isinstance(part, int) else f".{part}" for part in problem["loc"]).removeprefix(".")
    return f"{where}: {problem['msg']}" if where else problem["msg"]


def load_descriptors[Descriptor: BaseModel](model: type[Descriptor], file_name: str) -> list[Descriptor]:
    paths = sorted((PLUGIN_ROOT / "skills").glob(f"legion-*/{file_name}"))
    return [model.model_validate_json(path.read_text(encoding="utf-8")) for path in paths]


def _reference_issues(settings: PersonalisationSettings, tools: list[ToolDescriptor], channel_kinds: list[ChannelDescriptor]) -> list[str]:
    issues: list[str] = []
    tool_ids = [tool.id for tool in tools]
    ids: list[str] = []
    for agent in settings.agents:
        if agent.id in ids:
            issues.append(f"agents: duplicate id '{agent.id}'")
        if agent.tool not in tool_ids:
            issues.append(f"agents: unknown tool '{agent.tool}'")
        ids.append(agent.id)
    channel_ids: list[str] = []
    for channel in settings.channels:
        if channel.id in channel_ids:
            issues.append(f"channels: duplicate id '{channel.id}'")
        channel_ids.append(channel.id)
        for account in channel.accounts:
            if account not in ids:
                issues.append(f"channel '{channel.id}': unknown account '{account}'")
        kinds = [kind for kind in channel_kinds if kind.id == channel.kind]
        if not kinds:
            issues.append(f"unknown channel kind '{channel.kind}'")
            continue
        for account in channel.accounts:
            agents = [agent for agent in settings.agents if agent.id == account]
            if agents and agents[0].tool not in kinds[0].launch:
                issues.append(f"channel '{channel.id}': unsupported tool '{agents[0].tool}'")
    return issues


def _provider_issues(settings: PersonalisationSettings, tools: list[ToolDescriptor]) -> list[str]:
    issues: list[str] = []
    for index, agent in enumerate(settings.agents):
        provider = agent.provider
        if provider is None:
            continue
        if agent.command is not None:
            issues.append(f"agents[{index}]: command is only for subscription accounts")
        prefix = f"agents[{index}].provider:"
        if provider.kind != "foundry":
            issues.append(f"{prefix} unsupported provider '{provider.kind}'")
            continue
        matching = [tool for tool in tools if tool.id == agent.tool]
        if not matching:
            issues.append(f"{prefix} unknown tool '{agent.tool}'")
            continue
        foundry = matching[0].foundry
        if foundry is None:
            issues.append(f"{prefix} tool '{agent.tool}' does not support Foundry")
            continue
        names: list[str] = []
        aliases: list[str] = []
        for deployment in provider.deployments:
            if deployment.name in names:
                issues.append(f"{prefix} duplicate deployment '{deployment.name}'")
            names.append(deployment.name)
            alias = deployment.alias
            if alias:
                if alias in aliases:
                    issues.append(f"{prefix} alias '{alias}' used twice")
                aliases.append(alias)
                if alias not in foundry.aliases:
                    issues.append(f"{prefix} alias '{alias}' is not supported by tool '{agent.tool}'")
        if provider.default not in names:
            issues.append(f"{prefix} default '{provider.default}' is not a deployment")
    return issues


# The checks a settings model must pass before legion writes it: the schema, then references and providers.
def settings_issues(settings: PersonalisationSettings) -> list[str]:
    try:
        settings = PersonalisationSettings.model_validate(settings.model_dump(by_alias=True, exclude_none=True))
    except ValidationError as error:
        return [_describe(problem) for problem in error.errors()]
    return _semantic_issues(settings)


def _semantic_issues(settings: PersonalisationSettings) -> list[str]:
    tools = load_descriptors(ToolDescriptor, "tool.json")
    return _reference_issues(settings, tools, load_descriptors(ChannelDescriptor, "channel.json")) + _provider_issues(settings, tools)


# Shape problems stop the reference and provider checks, which need a well-formed file.
def validate_text(kind: str, text: str, *, references: bool = True) -> list[str]:
    try:
        # This parse only rejects broken JSON and duplicate keys; the model reads the text itself.
        json.loads(text, object_pairs_hook=_unique_keys)
        model = PersonalisationSettings if kind == "personalisation" else ProjectSettings
        try:
            settings = model.model_validate_json(text)
        except ValidationError as error:
            return [_framed(_describe(problem)) for problem in error.errors()]
        if not isinstance(settings, PersonalisationSettings) or not references:
            return []
        return _semantic_issues(settings)
    except Exception as error:
        return [_framed(str(error))]


def validate(kind: str, path: Path) -> list[str]:
    try:
        return validate_text(kind, read_text(path))
    except Exception as error:
        return [_framed(str(error))]
