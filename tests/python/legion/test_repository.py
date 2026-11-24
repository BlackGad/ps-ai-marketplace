import shutil
import stat
import sys
from pathlib import Path
from typing import Literal, Optional

import pytest
from click.testing import CliRunner

from legion._cli import main
from legion import _repository
from legion._run import RunResult, run_command

if sys.platform == "win32":
    import _winapi

FILES = ("configuration/project.json", "configuration/workflow.md", "scripts/index.md", "state/handoff.md", "state/history/.gitkeep")
MODES = ("private", "shared")


def git(repo: Path, *args: str) -> str:
    result = run_command("git", ["--literal-pathspecs", "-C", str(repo), *args])
    assert result.exit_code == 0, result.error
    return result.output.strip()


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    path = tmp_path / "code repo"
    path.mkdir()
    git(path, "init", "--quiet")
    git(path, "config", "user.name", "Fixture Owner")
    git(path, "config", "user.email", "fixture@example.invalid")
    (path / "AGENTS.md").write_text("owner rules\n", encoding="utf-8")
    (path / ".gitignore").write_text("existing/\n", encoding="utf-8")
    git(path, "add", ".")
    git(path, "commit", "--quiet", "-m", "Fixture")
    return path


def setup(repo: Path, mode: Literal["private", "shared"] = "private", gate: Optional[str] = None, rules_file: Optional[str] = None) -> list[str]:
    return _repository.setup(repo, mode, gate, rules_file)


def snapshot(repo: Path) -> dict[str, tuple[bytes, int]]:
    # Git status can refresh its own index; compare the owner's tree, not Git internals.
    return {str(p.relative_to(repo)): (p.read_bytes(), p.stat().st_mtime_ns) for p in repo.rglob("*") if p.is_file() and ".git" not in p.relative_to(repo).parts}


@pytest.mark.parametrize("mode", MODES)
def test_fresh_and_repeat(repo: Path, mode: Literal["private", "shared"]) -> None:
    before = git(repo, "rev-parse", "HEAD")
    original = snapshot(repo)
    lines = setup(repo, mode)
    legion = repo / ".legion"
    owner = legion if mode == "private" else repo
    assert lines[-1] == f"prepared: {mode.title()} orchestration"
    for name in FILES:
        assert f"created .legion/{name}" in lines
        assert (legion / name).is_file()
    for name in ("docs/specs", "docs/plans", "temp"):
        assert (legion / name).is_dir()
    workflow = (legion / "configuration/workflow.md").read_text(encoding="utf-8")
    assert "Rules file: `AGENTS.md`" in workflow
    assert "Delivery: `merge-request`" in workflow
    assert ".legion/docs/specs" in workflow
    assert ".legion/docs/plans" in workflow
    assert "Gate:" not in workflow
    assert ("## legion orchestration" in workflow) == (mode == "private")
    assert git(owner, "log", "-1", "--format=%s") == "Set up legion orchestration"
    assert git(owner, "log", "-1", "--format=%an|%ae|%cn|%ce") == "Fixture Owner|fixture@example.invalid|Fixture Owner|fixture@example.invalid"
    assert git(repo, "status", "--porcelain") == ""
    assert git(owner, "status", "--porcelain") == ""
    if mode == "private":
        assert git(repo, "rev-parse", "HEAD") == before
        assert snapshot(repo)["AGENTS.md"] == original["AGENTS.md"]
        assert snapshot(repo)[".gitignore"] == original[".gitignore"]
        assert (legion / ".gitignore").read_text(encoding="utf-8") == "temp/\ndocs/\n"
        assert ".legion/" in (repo / ".git/info/exclude").read_text(encoding="utf-8").splitlines()
        assert run_command("git", ["-C", str(owner), "config", "--local", "--get", "user.name"]).exit_code == 1
    else:
        assert not (legion / ".git").exists()
        assert (repo / "AGENTS.md").read_text(encoding="utf-8").count("## legion orchestration") == 1
        assert (repo / ".gitignore").read_text(encoding="utf-8") == "existing/\n.legion/temp/\n.legion/docs/\n"
    head = git(owner, "rev-parse", "HEAD")
    tree = snapshot(repo)
    assert setup(repo, mode) == [f"skip: {mode.title()} orchestration (already done)"]
    assert snapshot(repo) == tree
    assert git(owner, "rev-parse", "HEAD") == head
    (legion / "temp/report").write_text("scratch", encoding="utf-8")
    (legion / "docs/specs/local").write_text("spec", encoding="utf-8")
    assert git(owner, "status", "--porcelain") == ""


@pytest.mark.parametrize(
    ("agents", "claude", "requested", "expected"),
    [
        ("rules", None, None, "AGENTS.md"),
        (None, "rules", None, "CLAUDE.md"),
        ("rules", "@AGENTS.md", None, "AGENTS.md"),
        ("@CLAUDE.md", "rules", None, "CLAUDE.md"),
        ("rules", "rules", "AGENTS.md", "AGENTS.md"),
        (None, None, "my rules ü.md", "my rules ü.md"),
    ],
)
def test_rules_choice(repo: Path, agents: Optional[str], claude: Optional[str], requested: Optional[str], expected: str) -> None:
    for name, text in (("AGENTS.md", agents), ("CLAUDE.md", claude)):
        path = repo / name
        path.unlink(missing_ok=True)
        if text is not None:
            path.write_text(text, encoding="utf-8")
    git(repo, "add", ".")
    git(repo, "commit", "--quiet", "--allow-empty", "-m", "Rules choice")
    setup(repo, "shared", rules_file=requested)
    assert "## legion orchestration" in (repo / expected).read_text(encoding="utf-8")


@pytest.mark.parametrize(("case", "message"), [("ambiguous", "choose --rules-file"), ("none", "Shared needs a rules file"), ("outside", "inside the repository")])
def test_rules_refusal(repo: Path, case: str, message: str) -> None:
    if case == "ambiguous":
        (repo / "CLAUDE.md").write_text("other rules", encoding="utf-8")
    if case == "none":
        (repo / "AGENTS.md").unlink()
    tree = snapshot(repo)
    with pytest.raises(RuntimeError, match=message):
        setup(repo, "shared", rules_file="../outside.md" if case == "outside" else None)
    assert snapshot(repo) == tree


def test_private_without_rules(repo: Path) -> None:
    (repo / "AGENTS.md").unlink()
    setup(repo)
    assert "Rules file: none" in (repo / ".legion/configuration/workflow.md").read_text(encoding="utf-8")


@pytest.mark.parametrize("mode", MODES)
def test_preserves_existing_and_owner_edits(repo: Path, mode: Literal["private", "shared"]) -> None:
    legion = repo / ".legion"
    for name in FILES:
        (legion / name).parent.mkdir(parents=True, exist_ok=True)
        (legion / name).write_text('{"schemaVersion":1}' if name.endswith(".json") else "existing", encoding="utf-8")
    tree = snapshot(legion)
    setup(repo, mode)
    for name, value in tree.items():
        assert snapshot(legion)[name] == value
    owner = legion if mode == "private" else repo
    assert "state/handoff.md" in git(owner, "ls-files")
    edited = [legion / "state/handoff.md"]
    if mode == "shared":
        edited += [repo / "AGENTS.md", repo / ".gitignore"]
    for path in edited:
        with path.open("a", encoding="utf-8") as stream:
            stream.write("\nowner edit\n")
    tree = snapshot(repo)
    assert setup(repo, mode) == [f"skip: {mode.title()} orchestration (already done)"]
    assert snapshot(repo) == tree
    assert git(owner, "diff", "--name-only")


@pytest.mark.parametrize("mode", MODES)
@pytest.mark.parametrize("kind", ["deleted", "staged-deleted", "renamed", "partial-stage"])
def test_pending_setup_refusal(repo: Path, mode: Literal["private", "shared"], kind: str) -> None:
    setup(repo, mode)
    owner = repo / ".legion" if mode == "private" else repo
    relative = "state/handoff.md" if mode == "private" else ".legion/state/handoff.md"
    path = owner / relative
    if kind == "partial-stage":
        path.write_text("staged", encoding="utf-8")
        git(owner, "add", relative)
        path.write_text("unstaged", encoding="utf-8")
    elif kind == "renamed":
        git(owner, "mv", relative, relative + ".moved")
    else:
        path.unlink()
        if kind == "staged-deleted":
            git(owner, "add", relative)
    before = snapshot(repo)
    head = git(owner, "rev-parse", "HEAD")
    with pytest.raises(RuntimeError, match="staged and unstaged" if kind == "partial-stage" else "deletion is not committed"):
        setup(repo, mode)
    assert snapshot(repo) == before
    assert git(owner, "rev-parse", "HEAD") == head


@pytest.mark.parametrize("name", ["AGENTS.md", ".gitignore"])
def test_uncommitted_write_destination(repo: Path, name: str) -> None:
    (repo / name).write_text("owner edits", encoding="utf-8")
    tree = snapshot(repo)
    with pytest.raises(RuntimeError, match="uncommitted edits"):
        setup(repo, "shared")
    assert snapshot(repo) == tree


@pytest.mark.parametrize("mode", MODES)
def test_partial_setup_and_unrelated_files(repo: Path, mode: Literal["private", "shared"]) -> None:
    setup(repo, mode)
    owner = repo / ".legion" if mode == "private" else repo
    prefix = "" if mode == "private" else ".legion/"
    git(owner, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "rm", prefix + "state/history/.gitkeep")
    git(owner, "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "--quiet", "-m", "Drop gitkeep")
    (repo / ".legion/scripts/mine.ps1").write_text("owner", encoding="utf-8")
    (owner / "other.txt").write_text("unrelated", encoding="utf-8")
    git(owner, "add", "other.txt")
    lines = setup(repo, mode)
    assert "skip: .legion/state/handoff.md (already done)" in lines
    assert "created .legion/state/history/.gitkeep" in lines
    assert git(owner, "diff", "--cached", "--name-only") == "other.txt"
    assert "other.txt" not in git(owner, "show", "--name-only", "--format=", "HEAD")
    assert "scripts/mine.ps1" not in git(owner, "ls-files")


@pytest.mark.parametrize("gate", [None, "echo first"])
def test_gate_index_and_workflow(repo: Path, gate: Optional[str]) -> None:
    lines = setup(repo, gate=gate)
    legion = repo / ".legion"
    index = (legion / "scripts/index.md").read_text(encoding="utf-8")
    workflow = (legion / "configuration/workflow.md").read_text(encoding="utf-8")
    assert ("check-task.ps1" in index) == bool(gate)
    assert ("Gate: `check-task.ps1`" in workflow) == bool(gate)
    if gate:
        assert f"Runs `{gate}`" in index
        assert f"created .legion/scripts/check-task.ps1 (gate: {gate})" in lines
        script = (legion / "scripts/check-task.ps1").read_text(encoding="utf-8")
        assert script == "# Gate for this repository: one command, run after each task.\n$ErrorActionPreference = 'Stop'\necho first\nexit $LASTEXITCODE\n"


@pytest.mark.parametrize(("edited", "requested", "quoted"), [(False, None, False), (False, "echo first", True), (True, "echo second", False), (True, None, False)])
def test_rebuilt_index_does_not_parse_gate(repo: Path, edited: bool, requested: Optional[str], quoted: bool) -> None:
    setup(repo, "shared", "echo first")
    gate_path = repo / ".legion/scripts/check-task.ps1"
    if edited:
        gate_path.write_text("custom gate\n", encoding="utf-8")
        git(repo, "commit", "--quiet", "-am", "Custom gate")
    before = gate_path.read_bytes()
    git(repo, "rm", ".legion/scripts/index.md")
    git(repo, "commit", "--quiet", "-m", "Drop index")
    lines = setup(repo, "shared", requested)
    index = (repo / ".legion/scripts/index.md").read_text(encoding="utf-8")
    assert ("Runs `echo first`" in index) == quoted
    assert ("Runs the gate script" in index) != quoted
    assert gate_path.read_bytes() == before
    if edited and requested:
        assert any("--gate not applied" in line for line in lines)
    else:
        assert "skip: .legion/scripts/check-task.ps1 (already done)" in lines


def test_changed_gate_repeat(repo: Path) -> None:
    setup(repo, gate="echo first")
    tree = snapshot(repo)
    lines = setup(repo, gate="echo second")
    assert len(lines) == 2
    assert "--gate not applied" in lines[0]
    assert lines[-1] == "skip: Private orchestration (already done)"
    assert snapshot(repo) == tree


def test_gate_failing_cmdlet(repo: Path) -> None:
    pwsh = shutil.which("pwsh")
    if not pwsh:
        pytest.skip("pwsh unavailable")
    setup(repo, gate="Get-Item -LiteralPath ./missing-for-gate")
    assert run_command(pwsh, ["-NoProfile", "-File", str(repo / ".legion/scripts/check-task.ps1")], cwd=repo).exit_code != 0


@pytest.mark.parametrize("pointer", [False, True])
def test_private_history_and_nested_start(repo: Path, tmp_path: Path, pointer: bool) -> None:
    legion = repo / ".legion"
    legion.mkdir()
    args = ["init", "--quiet"]
    if pointer:
        args += ["--separate-git-dir", str(tmp_path / "history")]
    git(repo, *args, str(legion))
    pointer_text = (legion / ".git").read_bytes() if pointer else None
    setup(repo)
    head = git(legion, "rev-parse", "HEAD")
    for start in (legion, legion / "configuration"):
        assert setup(start) == ["skip: Private orchestration (already done)"]
        assert git(legion, "rev-parse", "HEAD") == head
    if pointer:
        assert (legion / ".git").read_bytes() == pointer_text
    with pytest.raises(RuntimeError, match="already has Private Git history"):
        setup(repo, "shared")


def test_private_refuses_shared(repo: Path) -> None:
    setup(repo, "shared")
    tree = snapshot(repo)
    with pytest.raises(RuntimeError, match=r"already shares .legion \(Shared\)"):
        setup(repo)
    assert snapshot(repo) == tree


def test_nested_private_root_finds_code_toplevel(repo: Path) -> None:
    nested = repo / "subfolder/.legion"
    nested.mkdir(parents=True)
    git(nested, "init", "--quiet")
    setup(nested)
    assert (repo / ".legion/configuration/project.json").is_file()
    assert not (nested.parent / ".git").exists()
    assert not (nested / ".legion").exists()


def test_private_root_without_code_git_refuses(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GIT_CEILING_DIRECTORIES", str(tmp_path))
    nested = tmp_path / "plain/.legion"
    nested.mkdir(parents=True)
    git(nested, "init", "--quiet")
    tree = snapshot(tmp_path)
    with pytest.raises(RuntimeError, match="Repository setup needs a Git working tree"):
        setup(nested)
    assert snapshot(tmp_path) == tree


def test_linked_worktree_exclude(repo: Path, tmp_path: Path) -> None:
    lane = tmp_path / "lane"
    git(repo, "worktree", "add", "--quiet", "--detach", str(lane), "HEAD")
    setup(repo)
    setup(lane)
    exclude = (repo / ".git/info/exclude").read_text(encoding="utf-8")
    assert exclude.splitlines().count(".legion/") == 1
    assert git(lane, "status", "--porcelain") == ""


@pytest.mark.parametrize("name", [".legion", ".legion/docs", ".legion/state", ".legion/configuration", "rules", ".git/info"])
def test_directory_link_refused_before_writes(repo: Path, tmp_path: Path, name: str) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    (outside / "sentinel").write_text("keep", encoding="utf-8")
    link = repo / name
    if link.exists():
        shutil.rmtree(link)
    link.parent.mkdir(parents=True, exist_ok=True)
    if sys.platform == "win32":
        _winapi.CreateJunction(str(outside), str(link))
    else:
        link.symlink_to(outside, target_is_directory=True)
    try:
        tree = snapshot(repo)
        with pytest.raises(RuntimeError, match="is a link; setup does not write through links"):
            setup(repo, rules_file="rules/RULES.md" if name == "rules" else None)
        assert snapshot(repo) == tree
        assert list(outside.iterdir()) == [outside / "sentinel"]
    finally:
        if sys.platform == "win32":
            link.rmdir()
        else:
            link.unlink()


@pytest.mark.parametrize(("name", "mode"), [(".gitignore", "shared"), (".legion/.gitignore", "private"), ("RULES.md", "shared"), (".git/info/exclude", "private")])
def test_file_link_refused(repo: Path, tmp_path: Path, name: str, mode: Literal["private", "shared"]) -> None:
    target = tmp_path / "target"
    target.write_text("keep", encoding="utf-8")
    path = repo / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.unlink(missing_ok=True)
    try:
        path.symlink_to(target)
    except OSError:
        pytest.skip("file symlinks unavailable")
    tree = snapshot(repo)
    with pytest.raises(RuntimeError, match="is a link"):
        setup(repo, mode, rules_file="RULES.md" if name == "RULES.md" else None)
    assert snapshot(repo) == tree
    assert target.read_text(encoding="utf-8") == "keep"


def test_failed_commit_recovery_and_literal_name(repo: Path) -> None:
    hook = repo / ".git/hooks/pre-commit"
    hook.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
    hook.chmod(hook.stat().st_mode | stat.S_IXUSR)
    with pytest.raises(RuntimeError, match="Cannot commit setup files"):
        setup(repo, "shared", rules_file="my [rules] ü.md")
    hook.unlink()
    assert setup(repo, "shared", rules_file="my [rules] ü.md")[-1] == "prepared: Shared orchestration"
    assert git(repo, "status", "--porcelain") == ""


def test_hidden_untracked_files(repo: Path) -> None:
    git(repo, "config", "status.showUntrackedFiles", "no")
    setup(repo, "shared")
    assert ".legion/state/handoff.md" in git(repo, "ls-files")


def test_invalid_project(repo: Path) -> None:
    project = repo / ".legion/configuration/project.json"
    project.parent.mkdir(parents=True)
    project.write_text('{"schemaVersion":99}', encoding="utf-8")
    with pytest.raises(RuntimeError, match=r"project\.json is not valid"):
        setup(repo)


def test_cli_usage_and_refusal(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GIT_CEILING_DIRECTORIES", str(tmp_path.parent))
    runner = CliRunner()
    refused = runner.invoke(main, ["repository", "setup", "--repo", str(tmp_path)])
    assert refused.exit_code == 1
    assert refused.stdout == ""
    assert refused.stderr == "Repository setup needs a Git working tree\n"
    invalid = runner.invoke(main, ["repository", "setup", "--mode", "other"])
    assert invalid.exit_code == 2


def test_cli_default_cwd_and_case_insensitive_mode(repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(repo)
    result = CliRunner().invoke(main, ["repository", "setup", "--mode", "SHARED", "--gate", "echo gate", "--rules-file", "AGENTS.md"])
    assert result.exit_code == 0, result.output
    assert result.stdout.endswith("prepared: Shared orchestration\n")


def test_git_calls_use_literal_status(repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    def record(command: str, arguments: list[str]) -> RunResult:
        calls.append(arguments)
        return run_command(command, arguments)

    monkeypatch.setattr(_repository, "run_command", record)
    setup(repo)
    statuses = [args for args in calls if "status" in args]
    assert statuses
    assert all("--literal-pathspecs" in args and "-z" in args and "--untracked-files=all" in args for args in statuses)
    assert not any("--path-format" in arg for args in calls for arg in args)
