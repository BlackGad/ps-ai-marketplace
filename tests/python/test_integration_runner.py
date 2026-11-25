import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest


RUNNER = Path(__file__).resolve().parents[1] / "integration" / "run.py"
SPEC = importlib.util.spec_from_file_location("integration_runner", RUNNER)
assert SPEC
assert SPEC.loader
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


def test_listing_parses_json_and_text_with_disabled_entries() -> None:
    json_entry = {"plugin": {"listing": {"format": "json", "idField": "id", "enabledField": "enabled"}}}
    text_entry = {"plugin": {"listing": {"format": "lines", "rejectPattern": "disabled"}}}
    assert runner.listed(json_entry, '[{"id":"legion@ps-legion-marketplace","enabled":false}]', include_disabled=True)
    assert not runner.listed(json_entry, '[{"id":"legion@ps-legion-marketplace","enabled":false}]')
    assert runner.listed(text_entry, "legion@ps-legion-marketplace 0.16.0")
    assert not runner.listed(text_entry, "legion@ps-legion-marketplace disabled")


def test_report_writes_all_evidence_and_omits_failed_benchmark(tmp_path: Path) -> None:
    cases = [runner.Case("install", False, "passed", 1.25, "", "ok"), runner.Case("install", True, "failed", 0.5, "repeat failed", "failure")]
    runner.write_report(tmp_path, "linux", cases, ["git: 2.0"], "claude 1.0")
    assert (tmp_path / "integration-linux.xml").exists()
    assert 'name="install (repeat)"' in (tmp_path / "integration-linux.xml").read_text(encoding="utf-8")
    assert [entry["name"] for entry in json.loads((tmp_path / "integration-bench-linux.json").read_text(encoding="utf-8"))] == ["linux / install"]
    assert "| install | 1.250 | 0.500 | failed |" in (tmp_path / "summary.md").read_text(encoding="utf-8")


def test_pwsh_trap_records_an_attempt(tmp_path: Path) -> None:
    checkout = Path(__file__).resolve().parents[2]
    instance = runner.Runner(checkout, tmp_path / "home", tmp_path / "results", False)
    command = instance.work / "pwsh-trap" / ("pwsh.cmd" if os.name == "nt" else "pwsh")
    with pytest.raises(AssertionError, match="a command called pwsh"), instance.without_pwsh():
        subprocess.run([str(command)], env=instance.env, capture_output=True, check=False)
    assert (instance.work / "pwsh-trap/called").exists()


@pytest.mark.skipif(sys.platform != "win32", reason="winget changes the Windows saved PATH")
def test_command_finds_winget_alias_on_saved_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    checkout = Path(__file__).resolve().parents[2]
    instance = runner.Runner(checkout, tmp_path / "home", tmp_path / "results", False)
    folder = tmp_path / "winget-links"
    folder.mkdir()
    (folder / "claude.cmd").write_text("@echo off\r\necho fixture-version\r\n", encoding="utf-8")
    instance.env["PATH"] = str(tmp_path / "empty")
    monkeypatch.setattr(runner, "windows_saved_path_folders", lambda: [folder])
    assert Path(instance.command("claude")).parent == folder
