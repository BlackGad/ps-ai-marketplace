import re
from pathlib import Path

import pytest
from conftest import REPO

SKILLS = REPO / "plugins/legion/skills"


def read(relative: str) -> str:
    return (SKILLS / relative).read_text(encoding="utf-8")


@pytest.mark.parametrize(
    "file",
    [*sorted(SKILLS.rglob("*.md")), REPO / "README.md", REPO / "docs/reference.md"],
    ids=lambda path: path.relative_to(REPO).as_posix(),
)
def test_local_markdown_links_resolve(file: Path) -> None:
    for link in re.findall(r"\[[^\]]+\]\(([^)]+)\)", file.read_text(encoding="utf-8")):
        target = link.split("#", 1)[0]
        if target and not re.match(r"https?://", target, re.IGNORECASE):
            assert (file.parent / target).exists(), target


@pytest.mark.parametrize("skill", ["personalisation", "overseer", "repository", "knowledge", "member", "update"])
def test_skill_stops_when_a_required_skill_is_missing(skill: str) -> None:
    content = "\n".join(file.read_text(encoding="utf-8") for file in (SKILLS / f"legion-{skill}").rglob("*.md"))
    assert re.search(r"stop[^\n]*(missing|does not exist)|missing[^\n]*stop", content, re.IGNORECASE)


@pytest.mark.parametrize("tool", ["claude", "codex", "copilot"])
def test_tool_skills_keep_owner_approval_and_resume_constraints(tool: str) -> None:
    folder = f"legion-{tool}/references"
    accounts = read(f"{folder}/accounts.md")
    run = read(f"{folder}/run.md")
    install = read(f"{folder}/install.md")
    assert re.search(r"owner.*log in|owner.*login", accounts, re.IGNORECASE)
    assert re.search(r"same account and folder|same account.*repository folder", run, re.IGNORECASE)
    assert "--yes" in install
    if tool != "copilot":
        assert "SHA-256" in install
        assert re.search(r"vendor|checksum|integrity", install, re.IGNORECASE)
        assert re.search("Stop before launching a reviewer", run, re.IGNORECASE)


def test_reviewer_denials_and_foundry_limits() -> None:
    run = read("legion-copilot/references/run.md")
    assert "--deny-tool=write --deny-tool=shell" in run
    assert re.search(r"cannot enforce.*stop", run, re.IGNORECASE)
    accounts = read("legion-copilot/references/accounts.md")
    for phrase in ("fixed bearer token", "does not refresh", "legion run --account <id> -- --resume"):
        assert phrase in accounts
    assert "not yet proven against Foundry" in read("legion-codex/references/accounts.md")
    reviews = read("legion-overseer/references/reviews.md").lower()
    assert "tool-enforced read-only" in reviews
    assert "stop" in reviews


def test_knowledge_installation_and_updates_need_owner_approval() -> None:
    knowledge = read("legion-knowledge/references/llm-wiki-setup.md")
    assert "never run" in knowledge
    assert "only when" in knowledge
    assert "A summoned unit cannot summon" in read("legion-member/SKILL.md")
    update = read("legion-update/SKILL.md")
    assert re.search(r"owner.s yes", update, re.IGNORECASE)
    assert re.search(r"run .legion. in the repository", update, re.IGNORECASE)


def test_overseer_default_routing_and_reviewer_independence() -> None:
    task = read("legion-overseer/references/task-loop.md")
    routing = re.search(r"(?s)## Default routing.*?## First legion dispatch", task)
    assert routing
    for phrase in (
        "reviewer is never the author",
        "another provider",
        "task tier, capacity and cost",
        "not provider-independent",
        "no distinct account",
        "must establish exhaustion",
        "Owner notes win for the roles they name",
    ):
        assert phrase.lower() in routing[0].lower()
    reviews = read("legion-overseer/references/reviews.md").lower()
    assert "settle only the roles they name" in reviews
    assert "without preferences" not in reviews
    assert "always distinct" in reviews
    for file in ("SKILL.md", "references/reviews.md", "references/task-loop.md"):
        content = read(f"legion-overseer/{file}")
        assert "default routing" in content, file
        assert not re.search(r"spread (work|reviews)|prefer cheaper accounts|choose a different tool/provider", content, re.IGNORECASE), file


def test_repository_setup_requires_evidence_for_its_mode() -> None:
    setup = read("legion-repository/references/setup.md")
    assert "legion repository setup --repo <repo> [--mode shared] [--gate" in setup
    layout = read("legion-repository/references/layout.md")
    for content in (layout, setup):
        assert re.search(r"\.legion/\.git` folder or file means Private", content, re.IGNORECASE)
        assert "git ls-files .legion" in content
        assert re.search(r"otherwise.*tracked.*Shared|otherwise.*git ls-files \.legion.*tracked.*Shared", content, re.IGNORECASE)
    for content in (read("legion-repository/SKILL.md"), layout, setup):
        assert re.search(r"If neither.*setup is not finished: ask the owner the setup choice again, with Private as the default, and complete it", content, re.IGNORECASE)
        assert "Otherwise the layout is Shared" not in content


def test_private_worktrees_copy_configuration_and_scripts_before_dispatch() -> None:
    assert "legion repository setup --repo <repo>" in read("legion-repository/references/setup.md")
    lanes = read("legion-overseer/references/lanes.md")
    assert "a new lane or review worktree has no `.legion/`" in lanes
    assert re.search(r"Before dispatch.*copies.*\.legion/configuration/.*\.legion/scripts/.*main tree.*same paths in the worktree", lanes, re.IGNORECASE)
    assert "read-only; script or rules changes go through the main tree" in lanes
    assert "Shared mode needs no copy" in lanes
    assert re.search(r"shares `info/exclude`.*copies and scratch ignored", lanes, re.IGNORECASE)
    for file in ("reviews.md", "task-loop.md"):
        assert re.search(r"Before dispatch.*configuration and scripts.*\[lanes.md\]\(lanes.md\).*Private copies", read(f"legion-overseer/references/{file}"), re.IGNORECASE)
    task = read("legion-member/references/task.md")
    assert re.search(r"Private worktree.*read-only copies.*\.legion/configuration/.*\.legion/scripts/", task, re.IGNORECASE)
    assert "Run indexed checks from those copies" in task
    assert re.search(r"script or rule needs changing, stop and report.*main tree", task, re.IGNORECASE)


def test_pending_result_rule_keeps_the_session_responsive() -> None:
    rule = read("legion-overseer/references/pending-results.md")
    assert "references/pending-results.md" in read("legion-overseer/SKILL.md")
    for file in ("task-loop.md", "takeover.md", "communication.md"):
        assert "pending-results.md" in read(f"legion-overseer/references/{file}"), file
    for phrase in (
        "background worker",
        "hosted CI",
        "external job",
        "Next action",
        "owner decision",
        "technical blocker",
        "connected channel",
        "investigat",
        "approval",
        "lease",
        "session itself is ending",
        "tool running the overseer",
        "without pushing",
    ):
        assert phrase.lower() in rule.lower()
    assert "report to the overseer" in rule
    for tool in ("claude", "codex", "copilot"):
        assert f"../../legion-{tool}/references/run.md#keep-the-session-responsive" in rule
    assert "legion-codex/references/run.md#keep-the-session-responsive" in read("legion-copilot/references/run.md")
    codex = read("legion-codex/references/run.md").lower()
    for phrase in ("within about 60 seconds", "repository inbox", "answer the owner", "Before waiting, tell the owner"):
        assert phrase.lower() in codex
    assert "unless a background command is running that will notify" in read("legion-claude/references/run.md").lower()
