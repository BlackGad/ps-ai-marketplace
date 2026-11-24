from collections.abc import MutableMapping
from pathlib import Path
from typing import Any

import tomlkit
from tomlkit.exceptions import TOMLKitError

from .._generated import write_generated
from .._home import home_path
from .._settings_models import Agent
from ._az import AzAccessToken, RESOURCE, az
from ._types import Launch


# Assigning replaces the item and its quote style, so a value that already matches is left as the owner wrote it.
def set_value(table: MutableMapping[str, Any], key: str, value: Any) -> None:
    if key not in table or table[key] != value:
        table[key] = value


def configure(agent: Agent, home: Path) -> bool:
    path = home_path(agent.config_dir, home) / "config.toml"
    original = path.read_bytes() if path.exists() else b""
    bom = original.startswith(b"\xef\xbb\xbf")
    newline = "\r\n" if b"\r\n" in original else "\n"
    try:
        doc = tomlkit.parse(original.decode("utf-8-sig"))
    except (TOMLKitError, UnicodeError):
        raise ValueError("config.toml is not valid TOML; fix it before configuring Foundry") from None
    assert agent.provider is not None
    set_value(doc, "model", agent.provider.default)
    set_value(doc, "model_provider", "legion-foundry")
    if "model_providers" not in doc:
        doc["model_providers"] = tomlkit.table()
    providers = doc["model_providers"]
    if "legion-foundry" not in providers:
        providers["legion-foundry"] = tomlkit.table()
    provider = providers["legion-foundry"]
    set_value(provider, "base_url", agent.provider.endpoint + "/openai/v1")
    set_value(provider, "wire_api", "responses")
    if "auth" not in provider:
        provider["auth"] = tomlkit.table()
    auth = provider["auth"]
    set_value(auth, "command", str(az()))
    set_value(auth, "args", ["account", "get-access-token", "--resource", RESOURCE, "--query", "accessToken", "-o", "tsv"])
    set_value(auth, "refresh_interval_ms", 1800000)
    content = tomlkit.dumps(doc).replace("\r\n", "\n").replace("\n", newline).encode("utf-8")
    if bom:
        content = b"\xef\xbb\xbf" + content
    if content == original:
        return False
    return write_generated(path, content.decode("utf-8"), executable=False)


def launch(agent: Agent, home: Path, _token: AzAccessToken) -> Launch:
    return Launch(set={"CODEX_HOME": str(home_path(agent.config_dir, home))}, clear=[])
