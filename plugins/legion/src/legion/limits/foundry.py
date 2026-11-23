# A Foundry account has no window: it reports whether az can get a Cognitive Services token. The token never leaves this module.

import json
from dataclasses import dataclass

from .._run import run_command
from ._ping import find_executable

TOKEN_ARGUMENTS = ["account", "get-access-token", "--resource", "https://cognitiveservices.azure.com", "-o", "json"]


@dataclass(frozen=True)
class TokenCheck:
    ok: bool
    error: str = ""


# Never logs in: az login is interactive and belongs to setup.
def check_token(timeout: float) -> TokenCheck:
    try:
        az = find_executable("az")
    except RuntimeError:
        return TokenCheck(ok=False, error="az is not installed; run legion-install-tool.ps1 -Tool az")
    result = run_command(az, TOKEN_ARGUMENTS, timeout=timeout)
    if result.timed_out:
        return TokenCheck(ok=False, error="az timed out")
    if result.exit_code != 0:
        # Its output can hold the token even on failure, so only the exit code is shown.
        return TokenCheck(ok=False, error=f"az could not get a token (exit code {result.exit_code})")
    try:
        data = json.loads(result.output)
    except ValueError:
        data = None
    if not isinstance(data, dict) or not data.get("accessToken"):
        return TokenCheck(ok=False, error="az returned no access token")
    return TokenCheck(ok=True)
