import os
import re
import time
import uuid
from pathlib import Path

from .._home import home_path
from .._settings_models import Agent
from ._az import AzAccessToken
from ._types import Launch, ProviderFile, ProviderModel, ProviderSpec

EXPIRED = re.compile(r"copilot-providers-([0-9]+)-[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.json$")


def configure(_agent: Agent, _home: Path) -> bool:
    return False


def cleanup(folder: Path, now: float) -> None:
    if not folder.is_dir():
        return
    for path in folder.glob("copilot-providers-*.json"):
        match = EXPIRED.fullmatch(path.name)
        if match and int(match.group(1)) <= now:
            path.unlink(missing_ok=True)


def write_provider(path: Path, content: ProviderFile) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # O_EXCL protects a token file against replacement; POSIX starts it with owner-only permissions.
    # Windows inherits the profile ACL. SYSTEM and Administrators can read any file, so a custom ACL adds nothing.
    descriptor = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    try:
        with os.fdopen(descriptor, "wb") as stream:
            stream.write(content.model_dump_json(by_alias=True).encode("utf-8"))
    except BaseException:
        path.unlink(missing_ok=True)
        raise


def launch(agent: Agent, home: Path, token: AzAccessToken, now: float | None = None) -> Launch:
    assert agent.provider is not None
    folder = home / ".legion" / "temp"
    cleanup(folder, time.time() if now is None else now)
    expiry = token.expiry()
    path = folder / f"copilot-providers-{int(expiry.timestamp())}-{uuid.uuid4()}.json"
    data = ProviderFile(
        providers=[
            ProviderSpec(name="legion-foundry", type="anthropic", base_url=agent.provider.endpoint + "/anthropic", bearer_token=token.access_token, headers={"anthropic-version": "2023-06-01"})
        ],
        models=[ProviderModel(id=item.name, provider="legion-foundry", model_id=item.model or item.name, wire_model=item.name) for item in agent.provider.deployments],
    )
    return Launch(
        set={"COPILOT_HOME": str(home_path(agent.config_dir, home)), "COPILOT_PROVIDERS_CONFIG": str(path)},
        clear=[],
        provider_file=(path, data),
        notice=f"token valid until {expiry.strftime('%H:%M')}; after that restart with: {agent.id} --resume",
    )
