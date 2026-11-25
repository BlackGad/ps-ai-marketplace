import re
from pathlib import Path

from conftest import REPO

# Legion work runs in Python. A skill, reference or doc may name a PowerShell file only for these reasons:
# the root bootstrap, a vendor's installer, the repository check scripts a project names, or this repository's own test runner.
ALLOWED_SCRIPTS = re.compile(r"(?:^|[/\\])(?:install|run|check-task|check)\.ps1$|[/\\]scripts[/\\]|^scripts[/\\]")
SCRIPT = re.compile(r"[\w<>./\\-]+\.ps1\b")
FOLDERS = [REPO / "plugins" / "legion" / "skills", REPO / "plugins" / "legion" / "hooks"]
FILES = [REPO / "README.md", REPO / "docs" / "reference.md"]


def documents() -> list[Path]:
    found = [path for folder in FOLDERS for path in folder.rglob("*") if path.is_file() and path.suffix in (".md", ".json", ".py")]
    return found + FILES


def test_no_skill_reference_or_doc_runs_pwsh_for_legion_work() -> None:
    offenders: list[str] = []
    for path in documents():
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            # The repository's own test command is the one place pwsh stays.
            if "pwsh" in line and "tests/run.ps1" not in line:
                offenders.append(f"{path.relative_to(REPO)}:{number}: {line.strip()[:80]}")
    assert offenders == []


def test_no_skill_reference_or_doc_calls_a_legion_ps1_file() -> None:
    offenders: list[str] = []
    for path in documents():
        for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
            for script in SCRIPT.findall(line):
                if not ALLOWED_SCRIPTS.search(script) and "<" not in script:
                    offenders.append(f"{path.relative_to(REPO)}:{number}: {script}")
    assert offenders == []


def test_the_plugin_ships_no_powershell_scripts() -> None:
    assert not (REPO / "plugins" / "legion" / "bin").exists()
    assert not (REPO / "plugins" / "legion" / "install.ps1").exists()
    assert list((REPO / "plugins" / "legion").rglob("*.ps1")) == []
