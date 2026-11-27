import re
import shutil
import subprocess

from conftest import REPO


def test_tracked_files_have_no_legacy_names() -> None:
    git = shutil.which("git")
    assert git is not None
    result = subprocess.run([git, "ls-files", "-z"], cwd=REPO, capture_output=True, timeout=30, check=True)
    assert result.stdout, "Could not list tracked files"
    files = result.stdout.decode("utf-8").rstrip("\0").split("\0")
    pattern = re.compile(r"ps[-_]?a[i]", re.IGNORECASE)
    violations = []
    for name in files:
        path = REPO / name
        if name == "CHANGELOG.md" or not path.is_file():
            continue
        if pattern.search(name) or pattern.search(path.read_text(encoding="utf-8-sig", errors="replace")):
            violations.append(name)
    assert violations == []
