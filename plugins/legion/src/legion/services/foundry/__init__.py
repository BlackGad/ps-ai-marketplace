from types import ModuleType

from legion.core._settings_models import Agent


from legion.services.foundry import claude, codex, copilot

RECIPES = {"claude": claude, "codex": codex, "copilot": copilot}


def recipe(agent: Agent) -> ModuleType:
    return RECIPES[agent.tool]
