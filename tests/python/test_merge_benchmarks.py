import importlib.util
import json
from pathlib import Path

import pytest


MERGER = Path(__file__).resolve().parents[1] / "integration" / "merge_benchmarks.py"
SPEC = importlib.util.spec_from_file_location("merge_benchmarks", MERGER)
assert SPEC
assert SPEC.loader
merger = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(merger)


@pytest.fixture
def github(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setenv("GITHUB_OUTPUT", str(tmp_path / "output.txt"))
    monkeypatch.setenv("GITHUB_STEP_SUMMARY", str(tmp_path / "summary.md"))
    return tmp_path


def write_system(results: Path, system: str, entries: list[dict[str, object]], folder: str = "") -> None:
    target = results / (folder or f"integration-{system}")
    target.mkdir(parents=True, exist_ok=True)
    (target / f"integration-bench-{system}.json").write_text(json.dumps(entries), encoding="utf-8")


def read_merged(github: Path) -> list[dict[str, object]]:
    return json.loads((github / "merged.json").read_text(encoding="utf-8"))


def test_complete_merges_in_system_order_and_marks_complete(github: Path) -> None:
    results = github / "results"
    for system in ("linux", "windows", "macos"):
        write_system(results, system, [{"name": f"{system} / install", "unit": "s", "value": 1.5}])
    merger.merge(results, github / "merged.json")
    assert [entry["name"] for entry in read_merged(github)] == ["windows / install", "macos / install", "linux / install"]
    assert (github / "output.txt").read_text(encoding="utf-8") == "complete=true\n"


def test_single_entry_stays_a_json_array(github: Path) -> None:
    results = github / "results"
    write_system(results, "linux", [{"name": "linux / install", "unit": "s", "value": 0.62}])
    merger.merge(results, github / "merged.json")
    assert (github / "merged.json").read_text(encoding="utf-8").lstrip().startswith("[")
    assert len(read_merged(github)) == 1


def test_empty_arrays_write_an_empty_array(github: Path) -> None:
    results = github / "results"
    write_system(results, "windows", [])
    merger.merge(results, github / "merged.json")
    assert read_merged(github) == []


def test_partial_results_keep_entries_and_warn_without_complete(github: Path, capsys: pytest.CaptureFixture[str]) -> None:
    results = github / "results"
    write_system(results, "windows", [{"name": "windows / install"}])
    write_system(results, "linux", [{"name": "linux / install"}])
    merger.merge(results, github / "merged.json")
    assert [entry["name"] for entry in read_merged(github)] == ["windows / install", "linux / install"]
    assert "missing integration timing file or duplicate for macos" in capsys.readouterr().out
    assert not (github / "output.txt").exists()


def test_duplicate_system_file_warns_and_is_not_complete(github: Path, capsys: pytest.CaptureFixture[str]) -> None:
    results = github / "results"
    for system in ("windows", "macos", "linux"):
        write_system(results, system, [{"name": f"{system} / install"}])
    write_system(results, "macos", [{"name": "macos / again"}], folder="other")
    merger.merge(results, github / "merged.json")
    assert len(read_merged(github)) == 4
    assert "duplicate for macos" in capsys.readouterr().out
    assert not (github / "output.txt").exists()


def test_no_files_write_a_summary_and_no_merged_file(github: Path) -> None:
    results = github / "results"
    results.mkdir()
    merger.merge(results, github / "merged.json")
    assert not (github / "merged.json").exists()
    assert not (github / "output.txt").exists()
    assert (github / "summary.md").read_text(encoding="utf-8") == "No integration timings were produced.\n"
