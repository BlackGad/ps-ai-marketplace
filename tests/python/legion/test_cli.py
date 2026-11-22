import json
from pathlib import Path

import pytest

from legion import _cli


@pytest.fixture
def plugin_manifest(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    module_path = tmp_path / "src" / "legion" / "_cli.py"
    monkeypatch.setattr(_cli, "__file__", str(module_path))
    manifest = tmp_path / "plugin.json"
    manifest.write_text(json.dumps({"version": "9.8.7"}), encoding="utf-8")
    return manifest


def test_version_reads_plugin_manifest(plugin_manifest: Path, capsys: pytest.CaptureFixture[str]) -> None:
    with pytest.raises(SystemExit) as result:
        _cli.main(["--version"])
    assert result.value.code == 0
    assert capsys.readouterr().out == "legion-py 9.8.7\n"
    plugin_manifest.write_text(json.dumps({"version": "9.8.8"}), encoding="utf-8")
    with pytest.raises(SystemExit):
        _cli.main(["--version"])
    assert capsys.readouterr().out == "legion-py 9.8.8\n"


def test_no_arguments_shows_help(plugin_manifest: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert plugin_manifest.is_file()
    assert _cli.main([]) == 0
    assert "usage: legion-py" in capsys.readouterr().out


def test_unknown_subcommand_is_rejected(plugin_manifest: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert plugin_manifest.is_file()
    with pytest.raises(SystemExit) as result:
        _cli.main(["inbox"])
    assert result.value.code == 2
    assert "unrecognized arguments: inbox" in capsys.readouterr().err
