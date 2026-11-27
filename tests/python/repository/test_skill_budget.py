import re

import pytest
from conftest import REPO

SKILLS = REPO / "plugins/legion/skills"
CAPS = {
    "legion-personalisation/references/create.md": 20,
    "legion-claude/references/accounts.md": 45,
    "legion-codex/references/accounts.md": 45,
    "legion-copilot/references/accounts.md": 45,
    "legion-personalisation/references/launcher.md": 12,
    "legion-repository/SKILL.md": 35,
    "legion-repository/references/setup.md": 20,
    "legion-telegram/references/connect.md": 10,
    "legion-personalisation/SKILL.md": 40,
}
# Personalisation SKILL.md loads before every flow, so it is excluded from flow totals.
FLOWS = [
    (
        "first setup",
        90,
        (
            "legion-personalisation/references/create.md",
            "legion-personalisation/references/fields.md",
        ),
    ),
    (
        "add claude account",
        130,
        (
            "legion-personalisation/references/create.md",
            "legion-personalisation/references/fields.md",
            "legion-claude/SKILL.md",
            "legion-claude/references/accounts.md",
        ),
    ),
    (
        "add codex account",
        130,
        (
            "legion-personalisation/references/create.md",
            "legion-personalisation/references/fields.md",
            "legion-codex/SKILL.md",
            "legion-codex/references/accounts.md",
        ),
    ),
    (
        "add copilot account",
        130,
        (
            "legion-personalisation/references/create.md",
            "legion-personalisation/references/fields.md",
            "legion-copilot/SKILL.md",
            "legion-copilot/references/accounts.md",
        ),
    ),
    ("remove account", 60, ("legion-personalisation/references/create.md",)),
    (
        "repository",
        80,
        (
            "legion-repository/SKILL.md",
            "legion-repository/references/setup.md",
        ),
    ),
    ("launch", 60, ("legion-personalisation/references/launcher.md",)),
    (
        "telegram",
        90,
        (
            "legion-telegram/SKILL.md",
            "legion-telegram/references/connect.md",
            "legion-telegram/references/install.md",
        ),
    ),
    ("status", 20, ()),
]
OWNED = (
    "legion-personalisation/SKILL.md",
    "legion-personalisation/references/create.md",
    "legion-personalisation/references/fields.md",
    "legion-personalisation/references/launcher.md",
    "legion-claude/references/accounts.md",
    "legion-codex/references/accounts.md",
    "legion-copilot/references/accounts.md",
    "legion-claude/SKILL.md",
    "legion-codex/SKILL.md",
    "legion-copilot/SKILL.md",
    "legion-repository/SKILL.md",
    "legion-repository/references/setup.md",
    "legion-telegram/references/connect.md",
    "legion-telegram/references/install.md",
    "legion-overseer/references/communication.md",
)


def read(relative: str) -> str:
    return (SKILLS / relative).read_text(encoding="utf-8")


@pytest.mark.parametrize(("file", "cap"), CAPS.items(), ids=CAPS)
def test_individual_skill_budget(file: str, cap: int) -> None:
    assert len(read(file).splitlines()) <= cap


@pytest.mark.parametrize(("name", "cap", "files"), FLOWS, ids=[name for name, _, _ in FLOWS])
def test_skill_flow_budget(name: str, cap: int, files: tuple[str, ...]) -> None:
    assert sum(len(read(file).splitlines()) for file in files) <= cap, name


def test_personalisation_and_launcher_rules() -> None:
    create = read("legion-personalisation/references/create.md")
    assert "unrecorded account" in create
    assert "finish setup with `legion setup`" in create
    assert "For `install failed` or `installed: open a new terminal`" not in create
    assert not re.search(r"\birm\b", "\n".join(map(read, OWNED)), re.IGNORECASE)
    personalisation = read("legion-personalisation/SKILL.md")
    assert "[launcher guide](references/launcher.md)" in personalisation
    assert personalisation.count("references/launcher.md") == 1
    launcher = read("legion-personalisation/references/launcher.md")
    assert "use `legion <verb>`" in launcher
    assert "finish setup first" in launcher
    for rule in (
        "exactly one question per message",
        "Save preferences, rulings and lessons that must persist in shared legion files",
        "independent channels with the same priority",
        "first acknowledge it there at once",
    ):
        assert rule in personalisation
    overseer = read("legion-overseer/SKILL.md")
    assert "will not respond for a while" in overseer
    assert "Keep the main session responsive" in overseer
    assert "Only the owner logs in" in read("legion-personalisation/references/fields.md")
    for tool in ("claude", "codex", "copilot"):
        assert "## Foundry agent" in read(f"legion-{tool}/references/accounts.md")
