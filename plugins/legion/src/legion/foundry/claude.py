import json
from pathlib import Path

from .._home import home_path
from .._settings_models import Agent, ToolDescriptor
from .._validate import load_descriptors
from ._az import AzAccessToken
from ._types import Launch


def configure(agent: Agent, home: Path) -> bool:
    path = home_path(agent.config_dir, home) / "settings.json"
    try:
        settings = json.loads(path.read_text(encoding="utf-8-sig")) if path.exists() else {}
        if not isinstance(settings, dict):
            raise TypeError
    except (ValueError, TypeError, UnicodeError):
        raise ValueError("settings.json is not valid JSON; fix or remove it") from None
    assert agent.provider is not None
    settings["modelPicker"] = {"replaceBuiltInOptions": True, "options": [{"model": item.name, "label": item.name} for item in agent.provider.deployments]}
    content = json.dumps(settings, ensure_ascii=False, indent=2) + "\n"
    if path.is_file() and path.read_text(encoding="utf-8") == content:
        return False
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8", newline="")
    return True


def launch(agent: Agent, home: Path, _token: AzAccessToken) -> Launch:
    assert agent.provider is not None
    variables = {
        "CLAUDE_CONFIG_DIR": str(home_path(agent.config_dir, home)),
        "CLAUDE_CODE_USE_FOUNDRY": "1",
        "ANTHROPIC_FOUNDRY_BASE_URL": agent.provider.endpoint + "/anthropic",
        "ANTHROPIC_MODEL": agent.provider.default,
    }
    variables.update({f"ANTHROPIC_DEFAULT_{item.alias.upper()}_MODEL": item.name for item in agent.provider.deployments if item.alias})
    clear = [
        "ANTHROPIC_FOUNDRY_RESOURCE",
        "ANTHROPIC_FOUNDRY_API_KEY",
        "ANTHROPIC_FOUNDRY_AUTH_TOKEN",
        "ANTHROPIC_SMALL_FAST_MODEL",
        "CLAUDE_CODE_USE_BEDROCK",
        "CLAUDE_CODE_USE_VERTEX",
        "CLAUDE_CODE_USE_ANTHROPIC_AWS",
        "CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD",
        "CLAUDE_CODE_USE_MANTLE",
        "CLAUDE_CODE_USE_GATEWAY",
    ]
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "claude")
    if descriptor.foundry:
        clear.extend(f"ANTHROPIC_DEFAULT_{alias.upper()}_MODEL" for alias in descriptor.foundry.aliases)
    return Launch(set=variables, clear=clear)
