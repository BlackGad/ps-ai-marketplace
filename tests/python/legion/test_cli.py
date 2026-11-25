import json
import subprocess
import sys
from pathlib import Path

import pytest
from cli_runner import run

from legion.services import installer as _installer
from legion.core import _plugin
from legion.services import status as status_service
from legion.services.status import StatusReport, status

pytest_plugins = ["status_parity"]


def test_cli_status_json_is_model_dump(parity_home: tuple[Path, Path], capsys: pytest.CaptureFixture[str]) -> None:
    repo, home = parity_home
    expected = status(repo, home).model_dump(mode="json")
    assert run(["--home", str(home), "status", "--json"]) == 0
    assert json.loads(capsys.readouterr().out) == expected


@pytest.fixture
def plugin_manifest(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setattr(_plugin, "PLUGIN_ROOT", tmp_path)
    manifest = tmp_path / "plugin.json"
    manifest.write_text(json.dumps({"name": "legion", "version": "9.8.7"}), encoding="utf-8")
    return manifest


def test_version_reads_plugin_manifest(plugin_manifest: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--version"]) == 0
    assert capsys.readouterr().out == "legion 9.8.7\n"
    plugin_manifest.write_text(json.dumps({"name": "legion", "version": "9.8.8"}), encoding="utf-8")
    assert run(["--version"]) == 0
    assert capsys.readouterr().out == "legion 9.8.8\n"


def test_help_lists_inbox_and_telegram(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--help"]) == 0
    output = capsys.readouterr().out
    assert "inbox" in output
    assert "telegram" in output
    assert "--home" in output


def test_unknown_command_exit_2(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["unknown"]) == 2
    assert "unknown" in capsys.readouterr().err


def test_inbox_send_read_roundtrip_via_click(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    home = tmp_path / "alternate home"
    repo = tmp_path / "repo"
    repo.mkdir()
    assert run(["--home", str(home), "inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    name = capsys.readouterr().out.strip()
    assert list((home / ".legion" / "inbox").glob(f"*/new/{name}"))
    assert run(["--home", str(home), "inbox", "read", "--repo", str(repo)]) == 0
    output = capsys.readouterr().out
    assert "from: repo-a" in output
    assert "    hello" in output


def test_home_changes_the_telegram_bot_folder(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--home", str(tmp_path), "telegram", "react", "--channel", "main", "--chat", "1", "--message", "2", "--emoji", "x"]) == 1
    assert "no bot token for channel 'main'" in capsys.readouterr().err


def test_relative_home_is_absolute_before_a_verb_receives_it(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.chdir(tmp_path)
    received: list[Path | None] = []
    report = status(tmp_path, tmp_path / "owner")

    def status_report(_repo: Path, home: Path | None) -> StatusReport:
        received.append(home)
        return report

    monkeypatch.setattr(status_service, "status", status_report)
    assert run(["--home", "owner", "status"]) == 0
    assert received == [tmp_path / "owner"]


def test_help_does_not_import_command_modules() -> None:
    script = (
        "import sys\n"
        "from legion import cli as _cli\n"
        "try:\n"
        "    _cli.main(['--help'])\n"
        "except SystemExit:\n"
        "    pass\n"
        "loaded = [name for name in ('legion.services._bridge', 'legion.services._telegram', 'legion.services._inbox', "
        "'legion.core._validate', 'legion.core._settings_models', 'pydantic', 'asyncio') if name in sys.modules]\n"
        "assert not loaded, loaded\n"
    )
    result = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr


def test_help_verb_lists_every_verb_and_exits_zero(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["help"]) == 0
    output = capsys.readouterr().out
    for verb in ("inbox", "telegram", "validate", "setup", "add", "remove", "status", "limits", "update", "uninstall", "pick", "help"):
        assert f"  {verb} " in output


def test_help_verb_runs_no_other_program(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    assert run(["help"]) == 0


@pytest.mark.parametrize("words", [["--check", "--yes"], ["--force"], ["--check", "extra"], ["--check", "--unknown"], ["--unknown"]])
def test_invalid_update_combinations_exit_2(words: list[str]) -> None:
    assert run(["update", *words]) == 2


@pytest.mark.parametrize(
    ("words", "message"),
    [
        (["--force"], "--force requires --check"),
        (["--check", "--yes"], "--yes cannot be used with --check"),
        (["-Yes"], "No such option '-Y'."),
        (["extra"], "Got unexpected extra argument (extra)"),
    ],
)
def test_update_usage_errors_are_plain(words: list[str], message: str, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["update", *words]) == 2
    assert f"Error: {message}\n" in capsys.readouterr().err


@pytest.mark.parametrize("words", [[], ["--yes"]])
def test_update_routes_to_python_installer(tmp_path: Path, words: list[str], monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    home = tmp_path / "update home"
    calls: list[tuple[Path, bool, bool]] = []

    def fake_install(selected: Path, **options: object) -> list[str]:
        calls.append((selected, bool(options["update"]), bool(options["yes"])))
        return ["updated"]

    monkeypatch.setattr(_installer, "install", fake_install)
    assert run(["--home", str(home), "update", *words]) == 0
    assert calls == [(home, True, bool(words))]
    assert capsys.readouterr().out == "updated\n"


def test_update_help_lists_its_options(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["update", "--help"]) == 0
    output = capsys.readouterr().out
    assert "Usage: legion update [OPTIONS]" in output
    for option in ("--check", "--force", "--yes", "--help"):
        assert option in output
