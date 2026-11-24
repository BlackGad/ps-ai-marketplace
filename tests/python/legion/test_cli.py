import json
import subprocess
import sys
from pathlib import Path

import pytest
from cli_runner import run

from legion import _plugin, _status


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

    def status_lines(_repo: Path, home: Path | None) -> list[str]:
        received.append(home)
        return []

    monkeypatch.setattr(_status, "status_lines", status_lines)
    assert run(["--home", "owner", "status"]) == 0
    assert received == [tmp_path / "owner"]


def test_help_does_not_import_command_modules() -> None:
    script = (
        "import sys\n"
        "from legion import _cli\n"
        "try:\n"
        "    _cli.main(['--help'])\n"
        "except SystemExit:\n"
        "    pass\n"
        "loaded = [name for name in ('legion._bridge', 'legion._telegram', 'legion._inbox', 'legion._validate', 'legion._settings_models', 'pydantic', 'asyncio') if name in sys.modules]\n"
        "assert not loaded, loaded\n"
    )
    result = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr
