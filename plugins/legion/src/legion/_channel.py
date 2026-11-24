# Channel bindings in the owner's settings: add, remove, and a files-only readiness check.

import re
import shutil
from pathlib import Path

from . import _settings_io
from ._home import home_path
from ._settings_models import (
    NAME_PATTERN,
    Agent,
    Channel,
    ChannelDescriptor,
    PersonalisationSettings,
)
from ._validate import load_descriptors


class ChannelError(Exception):
    pass


def _descriptor(kind: str) -> ChannelDescriptor:
    matches = [descriptor for descriptor in load_descriptors(ChannelDescriptor, "channel.json") if descriptor.id == kind]
    if not matches:
        raise ChannelError(f"unknown channel kind '{kind}'")
    return matches[0]


def _agent(settings: PersonalisationSettings, account: str) -> Agent:
    matches = [agent for agent in settings.agents if agent.id == account]
    if not matches:
        raise ChannelError(f"unknown account '{account}'")
    return matches[0]


def _bindable_agent(settings: PersonalisationSettings, account: str, descriptor: ChannelDescriptor) -> Agent:
    agent = _agent(settings, account)
    if agent.tool not in descriptor.launch:
        raise ChannelError(f"account '{account}' uses {agent.tool}, which {descriptor.id} does not support")
    if agent.provider is not None:
        raise ChannelError(f"account '{account}' runs through Foundry: channels are not available on third-party providers")
    return agent


def add(home: Path, channel_id: str, kind: str, target: str, accounts: list[str]) -> str:
    if not re.fullmatch(NAME_PATTERN, channel_id):
        raise ChannelError(f"id '{channel_id}' must match ^{NAME_PATTERN}$")
    settings = _settings_io.load(home)
    descriptor = _descriptor(kind)
    for account in accounts:
        _bindable_agent(settings, account, descriptor)
    existing = [channel for channel in settings.channels if channel.id == channel_id]
    if existing:
        if (existing[0].kind, existing[0].target, existing[0].accounts) != (kind, target, accounts):
            raise ChannelError(f"channel {channel_id} exists with other values; remove it first")
        return f"skip: channel {channel_id} (already done)"
    # Not validated here: save checks the whole settings, this binding included.
    settings.channels.append(Channel.model_construct(id=channel_id, kind=kind, target=target, accounts=accounts))
    _settings_io.save(home, settings)
    return f"added: channel {channel_id}"


def remove(home: Path, channel_id: str) -> str:
    settings = _settings_io.load_unchecked(home)
    kept = [channel for channel in settings.channels if channel.id != channel_id]
    if len(kept) == len(settings.channels):
        return f"skip: channel remove {channel_id} (already done)"
    _settings_io.save(home, settings.model_copy(update={"channels": kept}))
    return f"removed: channel {channel_id}"


# Reads files only and starts no CLI. A bot folder's token file is looked for, never opened.
def check(home: Path, kind: str, accounts: list[str]) -> list[str]:
    settings = _settings_io.load(home)
    descriptor = _descriptor(kind)
    ready = descriptor.ready
    lines: list[str] = []
    if ready is not None and ready.command:
        lines.append(f"{ready.command:<10} {'found' if shutil.which(ready.command) else 'not found'}")
    for account in accounts:
        agent = _agent(settings, account)
        if agent.tool not in descriptor.launch:
            lines.append(f"{account:<10} not supported ({kind} supports: {', '.join(descriptor.launch)})")
            continue
        folder = ready.plugin_folder.get(agent.tool) if ready is not None else None
        if not folder:
            lines.append(f"{account:<10} {kind} plugin not needed")
            continue
        found = (home_path(agent.config_dir, home) / folder).is_dir()
        lines.append(f"{account:<10} {kind} plugin {'found' if found else 'not found'}")
    states = descriptor.state or {}
    for binding in settings.channels:
        if binding.kind != kind:
            continue
        tools = [agent.tool for account in binding.accounts for agent in settings.agents if agent.id == account and agent.tool in states]
        if not tools:
            continue
        state = states[tools[0]]
        token = home / ".legion" / state.folder / binding.id / state.token_file
        lines.append(f"{binding.id:<10} bot folder: {'ready' if token.is_file() else f'missing token ({state.setup})'}")
    return lines
