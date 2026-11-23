import json
from pathlib import Path
from typing import Any

import fastjsonschema

PLUGIN_ROOT = Path(__file__).resolve().parents[2]
FRAME = "$: {}; run legion setup to update your settings"


def _load_descriptors(file_name: str) -> list[dict[str, Any]]:
    paths = sorted((PLUGIN_ROOT / "skills").glob(f"legion-*/{file_name}"))
    return [json.loads(path.read_text(encoding="utf-8")) for path in paths]


def _reference_issues(data: dict[str, Any], tools: list[dict[str, Any]], channel_kinds: list[dict[str, Any]]) -> list[str]:
    issues: list[str] = []
    tool_ids = [tool["id"] for tool in tools]
    ids: list[str] = []
    for agent in data["agents"]:
        if agent["id"] in ids:
            issues.append(f"agents: duplicate id '{agent['id']}'")
        if agent["tool"] not in tool_ids:
            issues.append(f"agents: unknown tool '{agent['tool']}'")
        ids.append(agent["id"])
    channel_ids: list[str] = []
    for channel in data["channels"]:
        if channel["id"] in channel_ids:
            issues.append(f"channels: duplicate id '{channel['id']}'")
        channel_ids.append(channel["id"])
        for account in channel["accounts"]:
            if account not in ids:
                issues.append(f"channel '{channel['id']}': unknown account '{account}'")
        kinds = [kind for kind in channel_kinds if kind["id"] == channel["kind"]]
        if not kinds:
            issues.append(f"unknown channel kind '{channel['kind']}'")
            continue
        for account in channel["accounts"]:
            agents = [agent for agent in data["agents"] if agent["id"] == account]
            if agents and agents[0]["tool"] not in kinds[0]["launch"]:
                issues.append(f"channel '{channel['id']}': unsupported tool '{agents[0]['tool']}'")
    return issues


def _provider_issues(data: dict[str, Any], tools: list[dict[str, Any]]) -> list[str]:
    issues: list[str] = []
    for index, agent in enumerate(data["agents"]):
        provider = agent.get("provider")
        if provider is None:
            continue
        prefix = f"agents[{index}].provider:"
        if provider["kind"] != "foundry":
            issues.append(f"{prefix} unsupported provider '{provider['kind']}'")
            continue
        matching = [tool for tool in tools if tool["id"] == agent["tool"]]
        if not matching:
            issues.append(f"{prefix} unknown tool '{agent['tool']}'")
            continue
        foundry = matching[0]["foundry"]
        if foundry is None:
            issues.append(f"{prefix} tool '{agent['tool']}' does not support Foundry")
            continue
        names: list[str] = []
        aliases: list[str] = []
        for deployment in provider["deployments"]:
            if deployment["name"] in names:
                issues.append(f"{prefix} duplicate deployment '{deployment['name']}'")
            names.append(deployment["name"])
            alias = deployment.get("alias")
            if alias:
                if alias in aliases:
                    issues.append(f"{prefix} alias '{alias}' used twice")
                aliases.append(alias)
                if alias not in foundry["aliases"]:
                    issues.append(f"{prefix} alias '{alias}' is not supported by tool '{agent['tool']}'")
        if provider["default"] not in names:
            issues.append(f"{prefix} default '{provider['default']}' is not a deployment")
    return issues


def validate(kind: str, path: Path) -> list[str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8").lstrip("﻿"))
        schema = json.loads((PLUGIN_ROOT / "schemas" / f"{kind}.schema.json").read_text(encoding="utf-8"))
        try:
            fastjsonschema.compile(schema)(data)
        except fastjsonschema.JsonSchemaValueException as error:
            return [FRAME.format(" ".join(error.message.split()))]
        if kind != "personalisation":
            return []
        tools = _load_descriptors("tool.json")
        return _reference_issues(data, tools, _load_descriptors("channel.json")) + _provider_issues(data, tools)
    except Exception as error:
        return [FRAME.format(" ".join(str(error).split()))]
