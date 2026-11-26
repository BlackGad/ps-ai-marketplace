import os
from pathlib import Path
from typing import Literal, Optional

from legion.core import _validate
from legion.core._atomic_write import atomic_write_bytes
from legion.core._plugin import PLUGIN_ROOT
from legion.core._run import run_command
from legion.core._text import decode_text, encode_text

GENERATED_FILES = (
    "configuration/project.json",
    "configuration/workflow.md",
    "scripts/index.md",
    "scripts/check-task.ps1",
    "state/handoff.md",
    "state/history/.gitkeep",
)
SCAFFOLD_FOLDERS = ("docs/specs", "docs/plans", "temp")
RULES_HEADING = "## legion orchestration"


class RepositoryError(RuntimeError):
    pass


def _git(repo: Path, *arguments: str, failure: str) -> str:
    result = run_command("git", ["--literal-pathspecs", "-C", str(repo), *arguments])
    if result.exit_code:
        raise RepositoryError(failure)
    return result.output


def _read(path: Path) -> str:
    return _validate.read_text(path) if path.exists() else ""


def _reference(name: str) -> str:
    path = PLUGIN_ROOT / "skills/legion-repository/references" / name
    if not path.is_file():
        raise RepositoryError(f"Required repository template is missing: {name}")
    text = _validate.read_text(path)
    if not text.strip():
        raise RepositoryError(f"Required repository template is empty: {name}")
    return text


# An existing owner file keeps its BOM, encoding and newlines and is replaced whole; a new file is created with the umask's permissions.
def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        atomic_write_bytes(path, encode_text(text, decode_text(path.read_bytes())[1], normalize_newlines=True))
    else:
        path.write_bytes(text.encode("utf-8"))


def _no_links(root: Path, path: Path) -> None:
    # A lexical walk is needed: resolve() would hide the link that redirects a write.
    # Path's stdlib predicates cover both symlinks and Windows junctions.
    for current in (path, *path.parents):
        if current == root:
            break
        if current.is_symlink() or current.is_junction():
            name = os.path.relpath(current, root)
            raise RepositoryError(f"{name} is a link; setup does not write through links")


def _check_links(repo: Path, destinations: list[Path], exclude: Optional[Path]) -> None:
    for destination in destinations:
        _no_links(repo, destination)
    # In a linked worktree the exclude file lives outside the code tree.
    if exclude:
        _no_links(exclude.parent.parent, exclude)


def _rules_name(repo: Path, requested: Optional[str]) -> Optional[str]:
    if requested:
        path = Path(os.path.normpath(repo / requested))
        if not path.is_relative_to(repo):
            raise RepositoryError("--rules-file must be inside the repository")
        return requested
    present = [name for name in ("AGENTS.md", "CLAUDE.md") if (repo / name).exists()]
    if len(present) < 2:
        return present[0] if present else None
    if "@AGENTS.md" in _read(repo / "CLAUDE.md"):
        return "AGENTS.md"
    if "@CLAUDE.md" in _read(repo / "AGENTS.md"):
        return "CLAUDE.md"
    raise RepositoryError("choose --rules-file: AGENTS.md, CLAUDE.md")


def _status(repo: Path, path: Path) -> str:
    return _git(repo, "status", "--porcelain", "-z", "--untracked-files=all", "--", str(path), failure=f"Cannot read the Git status of {path}")[:2]


def _missing_ignore(path: Path, lines: tuple[str, ...]) -> list[str]:
    return [line for line in lines if line not in _read(path).splitlines()]


def _add_ignore(path: Path, lines: tuple[str, ...]) -> bool:
    missing = _missing_ignore(path, lines)
    if not missing:
        return False
    content = _read(path)
    if content and not content.endswith("\n"):
        content += "\n"
    _write(path, content + "\n".join(missing) + "\n")
    return True


def _has_rules(path: Path) -> bool:
    return RULES_HEADING in _read(path).splitlines()


def _update_rules(path: Path) -> bool:
    if _has_rules(path):
        return False
    content = _read(path)
    if content and not content.endswith("\n"):
        content += "\n"
    _write(path, content + ("\n" if content else "") + _reference("rules-file-lines.md").rstrip() + "\n")
    return True


def _no_edits(repo: Path, path: Path) -> None:
    if _status(repo, path):
        raise RepositoryError(f"{path.relative_to(repo)} has uncommitted edits; commit or stash them before setup")


def _no_deleted(repo: Path, paths: list[Path]) -> None:
    for path in paths:
        status = _status(repo, path)
        if status and (status[0] in "DR" or status[1] == "D"):
            raise RepositoryError(f"{path.relative_to(repo)} was deleted and the deletion is not committed; commit or restore it before setup")


def _check_pending(repo: Path, generated: list[Path], ignore: Path, ignore_lines: tuple[str, ...], rules: Optional[Path]) -> None:
    if _missing_ignore(ignore, ignore_lines):
        _no_edits(repo, ignore)
    if rules and not _has_rules(rules):
        _no_edits(repo, rules)
    _no_deleted(repo, generated)


def _gate_text(command: str) -> str:
    return f"# Gate for this repository: one command, run after each task.\n$ErrorActionPreference = 'Stop'\n{command}\nexit $LASTEXITCODE\n"


def _workflow(rules: Optional[str], has_gate: bool, private: bool) -> str:
    choices = [
        f"- Rules file: `{rules}`" if rules else "- Rules file: none",
        "- Specs: `.legion/docs/specs`; plans: `.legion/docs/plans`",
        "- Delivery: `merge-request`",
    ]
    if has_gate:
        choices.append("- Gate: `check-task.ps1`")
    text = _reference("workflow-template.md").rstrip() + "\n\n" + "\n".join(choices) + "\n"
    if private:
        text += "\n" + _reference("rules-file-lines.md").rstrip() + "\n"
    return text


def _index(has_gate: bool, command: Optional[str]) -> str:
    text = _reference("scripts-index-template.md")
    example = next((line for line in text.splitlines() if line.startswith("| `check-task.ps1` |")), None)
    if example is None:
        raise RepositoryError("Required repository template is malformed: scripts-index-template.md")
    if not has_gate:
        return "\n".join(line for line in text.split("\n") if line.rstrip("\r") != example)
    runs = f"Runs `{command}`" if command else "Runs the gate script"
    return text.replace(example, f"| `check-task.ps1` | after each task | {runs} | none | exit code of the command |")


def _scaffold(legion: Path, mode: str, rules: Optional[str], gate: Optional[str], changed: list[Path]) -> list[str]:
    lines: list[str] = []
    kept: list[str] = []

    def create(name: str, text: str, note: str = "") -> None:
        path = legion / name
        if path.exists():
            kept.append(name)
        else:
            _write(path, text)
            changed.append(path)
            lines.append(f"created .legion/{name}{note}")

    gate_path = legion / "scripts/check-task.ps1"
    matches_gate = bool(gate and (not gate_path.exists() or _read(gate_path) == _gate_text(gate)))
    if gate and not matches_gate:
        lines.append("skip: .legion/scripts/check-task.ps1 (exists; --gate not applied, edit the script to change the gate)")
    elif gate:
        create("scripts/check-task.ps1", _gate_text(gate), f" (gate: {gate})")
    elif gate_path.exists():
        kept.append("scripts/check-task.ps1")
    # Only the supplied command can describe the gate; never recover it by parsing a script.
    has_gate = gate_path.exists()
    create("configuration/project.json", _reference("project-template.json"))
    create("configuration/workflow.md", _workflow(rules, has_gate, mode == "private"))
    create("scripts/index.md", _index(has_gate, gate if matches_gate else None))
    create("state/handoff.md", _reference("handoff-template.md"))
    create("state/history/.gitkeep", "")
    for folder in SCAFFOLD_FOLDERS:
        (legion / folder).mkdir(parents=True, exist_ok=True)
    if changed:
        lines += [f"skip: .legion/{name} (already done)" for name in kept]
    return lines


def _pending(repo: Path, paths: list[Path], written: list[Path]) -> list[Path]:
    pending = []
    for path in paths:
        status = _status(repo, path)
        if not status:
            continue
        untracked = status == "??"
        staged = not untracked and status[0] != " "
        modified = not untracked and status[1] != " "
        if staged and modified:
            raise RepositoryError(f"{path.relative_to(repo)} has staged and unstaged changes; stage all of it or none before setup")
        if untracked or staged or path in written:
            pending.append(path)
    return pending


def _commit(repo: Path, identity_repo: Path, paths: list[Path]) -> None:
    names = [str(path) for path in paths]
    _git(repo, "add", "--", *names, failure="Cannot stage setup files")
    identity = []
    for key in ("user.name", "user.email"):
        value = run_command("git", ["-C", str(identity_repo), "config", key])
        if not value.exit_code and value.output.strip():
            identity += ["-c", f"{key}={value.output.strip()}"]
    _git(repo, *identity, "commit", "--quiet", "-m", "Set up legion orchestration", "--", *names, failure="Cannot commit setup files")


def _check_file_destinations(repo: Path, paths: list[Path]) -> None:
    for path in paths:
        if path.exists() and not path.is_file():
            raise RepositoryError(f"{path.relative_to(repo)} is not a regular file")


def _check_templates() -> None:
    for name in ("project-template.json", "workflow-template.md", "scripts-index-template.md", "handoff-template.md", "rules-file-lines.md"):
        _reference(name)
    _index(False, None)


def _check_shared_ignore(repo: Path, paths: list[Path]) -> None:
    for path in paths:
        tracked = _git(repo, "ls-files", "--", str(path), failure="Cannot check tracked orchestration files")
        if tracked:
            continue
        ignored = run_command("git", ["-C", str(repo), "check-ignore", "-v", "--", str(path)])
        if ignored.exit_code == 0:
            raise RepositoryError(f"{path.relative_to(repo)} is ignored by {ignored.output.strip()}; remove the conflicting ignore rule before setup")


def _code_root(repo: Path) -> Path:
    root = _git(repo, "rev-parse", "--show-toplevel", failure="Repository setup needs a Git working tree").removesuffix("\n").removesuffix("\r")
    repo = Path(root).resolve()
    if os.path.normcase(repo.name) == os.path.normcase(".legion"):
        root = _git(repo.parent, "rev-parse", "--show-toplevel", failure="Repository setup needs a Git working tree").removesuffix("\n").removesuffix("\r")
        repo = Path(root).resolve()
    return repo


def _setup(repo: Path, mode: Literal["private", "shared"], gate: Optional[str], rules_file: Optional[str]) -> list[str]:
    repo = _code_root(repo)
    legion = repo / ".legion"
    inner = legion / ".git"
    shared = mode == "shared"
    if shared and inner.exists():
        raise RepositoryError("This layout already has Private Git history")
    if not shared and _git(repo, "ls-files", "--", ".legion", failure="Cannot check tracked orchestration files").strip():
        raise RepositoryError("The code repo already shares .legion (Shared)")
    rules = _rules_name(repo, rules_file)
    if shared and not rules:
        raise RepositoryError("Shared needs a rules file: choose --rules-file <file>")
    rules_path = repo / rules if rules else None
    ignore = (repo if shared else legion) / ".gitignore"
    ignore_lines = (".legion/temp/", ".legion/docs/") if shared else ("temp/", "docs/")
    generated = [legion / name for name in GENERATED_FILES]
    exclude = None
    if not shared:
        name = _git(repo, "rev-parse", "--git-path", "info/exclude", failure="Cannot find the repository exclude file").strip()
        exclude = Path(os.path.normpath(repo / name))
    destinations = [legion, inner, ignore, *generated, *(legion / folder for folder in SCAFFOLD_FOLDERS)]
    if rules_path:
        destinations.append(rules_path)
    _check_links(repo, destinations, exclude)
    _check_file_destinations(repo, [ignore, *generated, *([rules_path] if rules_path else [])])
    _check_templates()
    if shared:
        _check_shared_ignore(repo, [*generated, ignore])
    owner = repo if shared else legion
    if shared or inner.exists():
        _check_pending(owner, generated, ignore, ignore_lines, rules_path if shared else None)
    changed: list[Path] = []
    lines = _scaffold(legion, mode, rules, gate, changed)
    issues = _validate.validate("project", legion / "configuration/project.json")
    if issues:
        raise RepositoryError("project.json is not valid: " + "; ".join(issues))
    prepared = False
    if exclude and _add_ignore(exclude, (".legion/",)):
        prepared = True
    if _add_ignore(ignore, ignore_lines):
        changed.append(ignore)
    paths = [*generated, ignore]
    if shared and rules_path:
        if _update_rules(rules_path):
            changed.append(rules_path)
            lines.append(f"updated {rules_path.name}")
        paths.append(rules_path)
    if not shared and not inner.exists():
        _git(repo, "init", "--quiet", str(legion), failure="Cannot initialize Private history")
        prepared = True
    pending = _pending(owner, paths, changed)
    if pending:
        _commit(owner, repo, pending)
        prepared = True
    label = mode.title()
    lines.append(f"prepared: {label} orchestration" if prepared else f"skip: {label} orchestration (already done)")
    return lines


def setup(repo: Path, mode: Literal["private", "shared"], gate: Optional[str], rules_file: Optional[str]) -> list[str]:
    try:
        return _setup(repo, mode, gate, rules_file)
    except (OSError, ValueError) as error:
        raise RepositoryError(" ".join(str(error).split())) from error
