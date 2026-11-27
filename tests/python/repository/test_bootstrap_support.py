import os
import subprocess
from pathlib import Path

import pytest
from conftest import Fence, REPO

TESTS = REPO / "tests"
GUARD_HINT = "Run tests through tests/run.ps1"


@pytest.mark.parametrize("guard", [None, "other", "hom"], ids=["missing", "outside", "shared-prefix"])
def test_bootstrap_assertions_require_the_runner_guard(pwsh_path: Path, fence: Fence, guard: str | None) -> None:
    env = {**os.environ, "LEGION_TEST_ASSERT": str(TESTS / "Assert.ps1")}
    env.pop("LEGION_TEST_GUARD", None)
    if guard is not None:
        env["LEGION_TEST_GUARD"] = str(fence.home.with_name(guard))
    result = subprocess.run(
        [str(pwsh_path), "-NoProfile", "-NonInteractive", "-Command", "$ErrorActionPreference = 'Stop'; . $env:LEGION_TEST_ASSERT"],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode != 0
    assert GUARD_HINT in result.stderr


def test_bootstrap_refuses_direct_invocation_before_creating_fixtures(pwsh_path: Path, fence: Fence) -> None:
    env = {**os.environ, "PATH": str(pwsh_path.parent)}
    env.pop("LEGION_TEST_GUARD", None)
    result = subprocess.run(
        [str(pwsh_path), "-NoProfile", "-NonInteractive", "-File", str(TESTS / "repository/Bootstrap.Tests.ps1")],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode != 0
    assert GUARD_HINT in result.stderr
    assert not list(fence.home.glob("*account"))


def test_bootstrap_runner_rejects_a_nonmatching_name(pwsh_path: Path) -> None:
    pattern = "NoSuchFile*"
    result = subprocess.run(
        [str(pwsh_path), "-NoProfile", "-NonInteractive", "-File", str(TESTS / "run.ps1"), "-Name", pattern],
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode != 0
    assert pattern in result.stderr


def test_bootstrap_fixture_cleanup_only_removes_children_of_its_parent(pwsh_path: Path, fence: Fence) -> None:
    allowed = fence.temp / "allowed"
    sibling = fence.temp / "allowed-sibling"
    child = allowed / "child"
    child.mkdir(parents=True)
    sibling.mkdir()
    script = """
$ErrorActionPreference = 'Stop'
. $env:LEGION_TEST_ASSERT
. $env:LEGION_TEST_INSTALLER
$allowed = $env:LEGION_TEST_ALLOWED
$sibling = $env:LEGION_TEST_SIBLING
$child = Join-Path $allowed 'child'
$link = Join-Path $allowed 'escape'
$linkType = if ($IsWindows) { 'Junction' } else { 'SymbolicLink' }
New-Item -ItemType $linkType -Path $link -Target (Resolve-LegionDirectoryPath $sibling) | Out-Null
try {
    Assert-Throws { Remove-TestFolder -Path $allowed -AllowedParent $allowed } 'Cleanup refuses the parent itself'
    Assert-Throws { Remove-TestFolder -Path $sibling -AllowedParent $allowed } 'Cleanup refuses a sibling sharing the prefix'
    Assert-Throws { Remove-TestFolder -Path $link -AllowedParent $allowed } 'Cleanup refuses links outside the parent'
} finally { Remove-Item -LiteralPath $link -Force }
Remove-TestFolder -Path $child -AllowedParent $allowed
Remove-TestFolder -Path $child -AllowedParent $allowed
$fixture = New-InstallTestFolder 'fixture-home'
try {
    Assert-True (Test-LegionPathUnder -Path $fixture -Root (Get-TestTempPath)) 'Installer fixture homes stay under the runner temp'
} finally { Remove-InstallTestFolder $fixture }
Assert-True (-not (Test-Path -LiteralPath $fixture)) 'Installer fixture home is removed'
"""
    env = {
        **os.environ,
        "LEGION_TEST_GUARD": str(fence.home),
        "LEGION_TEST_ASSERT": str(TESTS / "Assert.ps1"),
        "LEGION_TEST_INSTALLER": str(TESTS / "lib/installer.ps1"),
        "LEGION_TEST_ALLOWED": str(allowed),
        "LEGION_TEST_SIBLING": str(sibling),
    }
    result = subprocess.run(
        [str(pwsh_path), "-NoProfile", "-NonInteractive", "-Command", script],
        env=env,
        capture_output=True,
        text=True,
        timeout=30,
        check=False,
    )
    assert result.returncode == 0, result.stdout + result.stderr
    assert allowed.is_dir()
    assert sibling.is_dir()
    assert not child.exists()
