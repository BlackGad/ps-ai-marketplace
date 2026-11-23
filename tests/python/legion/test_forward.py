import json
from pathlib import Path

import pytest
from cli_runner import run

from legion import _forward

# A stand-in for the PowerShell entry point: it records how it was called and exits with a chosen code.
FAKE_ENTRY = """param([Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Words, [string]$HomeRoot)
@{ words = @($Words | Where-Object { $null -ne $_ }); home = $HomeRoot; cwd = (Get-Location).Path } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'call.json') -Encoding utf8
exit 7
"""


@pytest.fixture
def app_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    root = tmp_path / "app 1.0.0"
    (root / "bin").mkdir(parents=True)
    (root / "bin" / "legion.ps1").write_text(FAKE_ENTRY, encoding="utf-8")
    monkeypatch.setattr(_forward, "__file__", str(root / "src" / "legion" / "_forward.py"))
    return root


def read_call(app_root: Path) -> dict[str, object]:
    return json.loads((app_root / "bin" / "call.json").read_text(encoding="utf-8-sig"))


def test_forwarded_verb_keeps_arguments_and_exit_code(app_root: Path) -> None:
    assert run(["setup", "two words", 'say "hi"', "--yes"]) == 7
    call = read_call(app_root)
    assert call["words"] == ["setup", "two words", 'say "hi"', "--yes"]
    assert not call["home"]


def test_home_is_passed_as_one_home_root(app_root: Path, tmp_path: Path) -> None:
    home = tmp_path / "alternate home"
    assert run(["--home", str(home), "status"]) == 7
    call = read_call(app_root)
    assert call["words"] == ["status"]
    assert call["home"] == str(home)


@pytest.mark.parametrize("arguments", [[], ["--no-channel"], ["pick"], ["help"]])
def test_entry_points_without_a_python_verb_forward_unchanged(app_root: Path, arguments: list[str]) -> None:
    assert run(arguments) == 7
    assert read_call(app_root)["words"] == arguments


def test_working_directory_is_the_callers(app_root: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    repo = tmp_path / "unrelated repo"
    repo.mkdir()
    monkeypatch.chdir(repo)
    assert run(["--home", str(tmp_path / "home"), "status"]) == 7
    assert Path(str(read_call(app_root)["cwd"])).resolve() == repo.resolve()


def test_missing_pwsh_is_one_line_and_exit_127(app_root: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    assert run(["status"]) == 127
    assert capsys.readouterr().err == "pwsh is missing. Ask the owner before installing PowerShell 7, then run the legion installer again.\n"
    assert not (app_root / "bin" / "call.json").exists()


def test_help_lists_python_and_forwarded_verbs(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--help"]) == 0
    output = capsys.readouterr().out
    for verb in ("inbox", "telegram", "validate", "setup", "add", "remove", "status", "limits", "update", "uninstall", "pick", "help"):
        assert f"  {verb} " in output
