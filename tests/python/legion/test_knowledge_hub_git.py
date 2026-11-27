import shutil
import subprocess
from pathlib import Path

import pytest

from legion.services.installation import _knowledge_hub

GIT = shutil.which("git") or "git"
needs_git = pytest.mark.skipif(GIT == "git" and shutil.which("git") is None, reason="git is not installed")


def commits(hub: Path) -> list[str]:
    result = subprocess.run([GIT, "-C", str(hub), "log", "--format=%s"], capture_output=True, text=True, check=True)
    return result.stdout.splitlines()


@pytest.fixture(autouse=True)
def isolated_git(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", str(tmp_path / "no-global-config"))
    monkeypatch.setenv("GIT_CONFIG_SYSTEM", str(tmp_path / "no-system-config"))
    for name in ("NAME", "EMAIL"):
        for role in ("AUTHOR", "COMMITTER"):
            monkeypatch.delenv(f"GIT_{role}_{name}", raising=False)
    monkeypatch.delenv("EMAIL", raising=False)


@needs_git
def test_a_new_hub_becomes_a_repository_with_one_commit(tmp_path: Path) -> None:
    lines: list[str] = []
    _knowledge_hub.initialize(tmp_path, lines)
    hub = tmp_path / ".legion/knowledge"
    assert "done: knowledge hub git repository" in lines
    assert len(commits(hub)) == 1
    assert (hub / ".gitignore").read_text(encoding="utf-8") == ".sessions/\n"
    author = subprocess.run([GIT, "-C", str(hub), "log", "--format=%an <%ae>"], capture_output=True, text=True, check=True).stdout.strip()
    assert author == "legion <legion@localhost>"
    assert subprocess.run([GIT, "-C", str(hub), "config", "--global", "user.name"], capture_output=True, text=True, check=False).stdout == ""


@needs_git
def test_a_configured_identity_is_used(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    config = tmp_path / "global-config"
    config.write_text("[user]\n\tname = Owner\n\temail = owner@example.com\n", encoding="utf-8")
    monkeypatch.setenv("GIT_CONFIG_GLOBAL", str(config))
    _knowledge_hub.initialize(tmp_path, [])
    author = subprocess.run([GIT, "-C", str(tmp_path / ".legion/knowledge"), "log", "--format=%an <%ae>"], capture_output=True, text=True, check=True).stdout.strip()
    assert author == "Owner <owner@example.com>"


@needs_git
def test_an_existing_hub_that_is_not_a_repository_is_adopted_once(tmp_path: Path) -> None:
    hub = tmp_path / ".legion/knowledge/topics"
    hub.mkdir(parents=True)
    (hub / "note.md").write_text("kept\n", encoding="utf-8")
    _knowledge_hub.initialize(tmp_path, [])
    again: list[str] = []
    _knowledge_hub.initialize(tmp_path, again)
    assert len(commits(tmp_path / ".legion/knowledge")) == 1
    assert "skip: knowledge hub git repository (already done)" in again


@needs_git
def test_an_existing_repository_with_a_commit_is_left_alone(tmp_path: Path) -> None:
    _knowledge_hub.initialize(tmp_path, [])
    hub = tmp_path / ".legion/knowledge"
    (hub / "later.md").write_text("new\n", encoding="utf-8")
    lines: list[str] = []
    _knowledge_hub.initialize(tmp_path, lines)
    assert "skip: knowledge hub git repository (already done)" in lines
    assert len(commits(hub)) == 1


@needs_git
def test_a_repository_without_a_commit_gets_its_first_commit(tmp_path: Path) -> None:
    hub = tmp_path / ".legion/knowledge"
    hub.mkdir(parents=True)
    subprocess.run([GIT, "init", str(hub)], capture_output=True, check=True)
    _knowledge_hub.initialize(tmp_path, [])
    assert len(commits(hub)) == 1


@needs_git
def test_adopting_keeps_an_existing_gitignore(tmp_path: Path) -> None:
    hub = tmp_path / ".legion/knowledge"
    hub.mkdir(parents=True)
    (hub / ".gitignore").write_text("*.tmp", encoding="utf-8")
    _knowledge_hub.initialize(tmp_path, [])
    assert (hub / ".gitignore").read_text(encoding="utf-8") == "*.tmp\n.sessions/\n"


@needs_git
def test_a_hub_inside_a_parent_repository_gets_its_own_repository(tmp_path: Path) -> None:
    subprocess.run([GIT, "init", str(tmp_path)], capture_output=True, check=True)
    subprocess.run([GIT, "-C", str(tmp_path), "config", "user.name", "Parent"], capture_output=True, check=True)
    subprocess.run([GIT, "-C", str(tmp_path), "config", "user.email", "parent@example.com"], capture_output=True, check=True)
    _knowledge_hub.initialize(tmp_path, [])
    hub = tmp_path / ".legion/knowledge"
    assert (hub / ".git").exists()
    assert len(commits(hub)) == 1
    local = subprocess.run([GIT, "-C", str(hub), "config", "--local", "user.name"], capture_output=True, text=True, check=True).stdout.strip()
    assert local == "legion"


def test_missing_git_prints_one_line_and_continues(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(shutil, "which", lambda *_args, **_kwargs: None)
    lines: list[str] = []
    _knowledge_hub.initialize(tmp_path, lines)
    assert [line for line in lines if "git" in line] == ["knowledge: git is not installed, so the hub has no history yet (knowledge still works)"]
    assert _knowledge_hub.hub_status(tmp_path) == "ready"
