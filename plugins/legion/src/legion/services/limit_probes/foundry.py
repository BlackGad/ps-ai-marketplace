# A Foundry account has no window: it reports whether az can get a Cognitive Services token. The token never leaves this module.

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    ValidationError,
)

from legion.core._run import run_command
from legion.services.limit_probes._ping import find_executable

TOKEN_ARGUMENTS = ["account", "get-access-token", "--resource", "https://cognitiveservices.azure.com", "-o", "json"]


# Only the presence of the token is used; az prints more fields, which are ignored.
class AccessToken(BaseModel):
    access_token: str = Field(alias="accessToken", min_length=1)


class TokenCheck(BaseModel):
    model_config = ConfigDict(frozen=True)

    ok: bool
    error: str = ""


# Never logs in: az login is interactive and belongs to setup.
def check_token(timeout: float) -> TokenCheck:
    try:
        az = find_executable("az")
    except RuntimeError:
        return TokenCheck(ok=False, error="az is not installed; ask legion to install the Azure CLI")
    result = run_command(az, TOKEN_ARGUMENTS, timeout=timeout)
    if result.timed_out:
        return TokenCheck(ok=False, error="az timed out")
    if result.exit_code != 0:
        # Its output can hold the token even on failure, so only the exit code is shown.
        return TokenCheck(ok=False, error=f"az could not get a token (exit code {result.exit_code})")
    try:
        AccessToken.model_validate_json(result.output)
    except ValidationError:
        return TokenCheck(ok=False, error="az returned no access token")
    return TokenCheck(ok=True)
