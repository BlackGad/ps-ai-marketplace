import json
import shutil
import subprocess
from datetime import datetime
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

from legion.core._run import _cmd_line, run_command

RESOURCE = "https://cognitiveservices.azure.com"


class AzModel(BaseModel):
    model_config = ConfigDict(extra="ignore")


class AzAccessToken(AzModel):
    access_token: str = Field(alias="accessToken")
    expires_on: Optional[int] = None
    expires_on_text: Optional[str] = Field(default=None, alias="expiresOn")

    def expiry(self) -> datetime:
        if self.expires_on is not None:
            return datetime.fromtimestamp(self.expires_on).astimezone()
        if self.expires_on_text is not None:
            return datetime.fromisoformat(self.expires_on_text).astimezone()
        raise ValueError("az returned no token expiry")


class AzCognitiveAccount(AzModel):
    name: str
    resource_group: str = Field(alias="resourceGroup")


class AzDeployment(AzModel):
    name: str
    properties: dict[str, object]

    @property
    def model_name(self) -> str:
        model = self.properties.get("model")
        return str(model.get("name", "")) if isinstance(model, dict) else ""


def az() -> Path:
    found = shutil.which("az")
    if found is None:
        raise ValueError("az is not installed; run legion tool install --tool az")
    return Path(found)


def call(arguments: list[str]) -> str:
    result = run_command(str(az()), arguments)
    if result.exit_code:
        raise ValueError((result.error or result.output).strip())
    return result.output


def token() -> AzAccessToken:
    data = json.loads(call(["account", "get-access-token", "--resource", RESOURCE, "-o", "json"]))
    if not data.get("accessToken"):
        raise ValueError("az returned no access token")
    return AzAccessToken.model_validate(data)


def check_token(login: bool = True) -> AzAccessToken:
    try:
        return token()
    except (ValueError, OSError):
        if not login:
            raise
        command = str(az())
        line: str | list[str] = [command, "login", "-o", "none"]
        if Path(command).suffix.lower() in (".cmd", ".bat"):
            line = _cmd_line(line)
        # Interactive login must inherit the owner's terminal.
        subprocess.run(line, check=False)
        return token()
