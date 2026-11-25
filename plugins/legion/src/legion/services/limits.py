from collections.abc import Sequence
from pathlib import Path
from typing import Optional

from pydantic import BaseModel, ConfigDict

from .._home import legion_home, settings_path
from .._settings_models import Agent, PersonalisationSettings
from .._validate import read_text
from ..limits import DEFAULT_TIMEOUT, LimitsError, account_rows
from ..limits._ping import LimitRow, first_line


class AccountLimits(BaseModel):
    model_config = ConfigDict(frozen=True)

    account: str
    tool: str
    rows: list[LimitRow]


def configured_accounts(home: Optional[Path]) -> list[Agent]:
    file = settings_path(legion_home(home))
    if not file.is_file():
        raise LimitsError("No legion settings yet; run legion setup.")
    try:
        return PersonalisationSettings.model_validate_json(read_text(file)).agents
    except (OSError, ValueError) as error:
        raise LimitsError("legion settings are not valid: " + first_line(str(error))) from None


def limits(home: Optional[Path], accounts: Sequence[str], timeout: float = DEFAULT_TIMEOUT) -> list[AccountLimits]:
    if not accounts:
        raise LimitsError("name at least one account")
    home = legion_home(home)
    agents = {agent.id: agent for agent in configured_accounts(home)}
    # Validate the complete selection before starting any potentially billable probe.
    selected = []
    for account in accounts:
        if account not in agents:
            raise LimitsError(f"unknown account '{account}'")
        selected.append(agents[account])
    return [AccountLimits(account=agent.id, tool=agent.tool, rows=account_rows(agent, home, timeout)) for agent in selected]
