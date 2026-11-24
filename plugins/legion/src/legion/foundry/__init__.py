from types import ModuleType

from .._settings_models import Agent


from . import claude, codex, copilot

RECIPES = {"claude": claude, "codex": codex, "copilot": copilot}


def recipe(agent: Agent) -> ModuleType:
    return RECIPES[agent.tool]
