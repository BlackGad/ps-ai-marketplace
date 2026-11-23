import json
from pathlib import Path
from typing import Any

import fastjsonschema
import pytest
from cli_runner import run

from legion import _validate

REPO = Path(__file__).resolve().parents[3]
FIXTURES = REPO / "tests" / "fixtures"
RECORDED = json.loads((FIXTURES / "validate" / "old-behaviour.json").read_text(encoding="utf-8"))
OWNER = FIXTURES / "personalisation" / "valid-owner.json"
FOUNDRY = FIXTURES / "personalisation" / "valid-foundry.json"
SUFFIX = "; run legion setup to update your settings"


def write_bom_crlf(path: Path) -> Path:
    text = OWNER.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    path.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
    return path


# A tool case is the real descriptor with one edit: the value at a JSON pointer path, or no property there.
def edited_descriptor(case: dict[str, Any]) -> Any:
    data = json.loads((REPO / "plugins" / "legion" / "skills" / f"legion-{case['tool']}" / "tool.json").read_text(encoding="utf-8"))
    if "path" not in case:
        return data
    *parents, last = case["path"].split("/")[1:]
    target = data
    for key in parents:
        target = target[int(key)] if isinstance(target, list) else target[key]
    key = int(last) if isinstance(target, list) else last
    if "value" in case:
        target[key] = case["value"]
    else:
        del target[key]
    return data


@pytest.mark.parametrize("case", RECORDED["validate"], ids=lambda case: case["name"])
def test_verdict_and_semantic_messages_match_the_recorded_old_run(case: dict[str, Any]) -> None:
    issues = _validate.validate(case["kind"], REPO / case["path"])
    assert (1 if issues else 0) == case["exit"]
    if not case["output"] or not case["output"][0].startswith("$:"):
        assert issues == case["output"]
        return
    assert issues
    for issue in issues:
        assert issue.startswith("$: ")
        assert issue.endswith(SUFFIX)


def test_schema_message_is_normalised_to_one_line() -> None:
    (issue,) = _validate.validate("personalisation", FIXTURES / "personalisation" / "invalid-version.json")
    assert "schemaVersion" in issue
    assert "\n" not in issue
    assert "  " not in issue


def test_bom_with_crlf_is_accepted(tmp_path: Path) -> None:
    assert _validate.validate("personalisation", write_bom_crlf(tmp_path / "bom-crlf.json")) == []


def test_missing_file_is_one_framed_line(tmp_path: Path) -> None:
    (issue,) = _validate.validate("personalisation", tmp_path / "no-such-file.json")
    assert issue.startswith("$: ")
    assert "no-such-file.json" in issue
    assert issue.endswith(SUFFIX)


def test_duplicate_key_names_the_key() -> None:
    (issue,) = _validate.validate("project", FIXTURES / "validate" / "duplicate-key.json")
    assert "schemaVersion" in issue


@pytest.mark.parametrize(
    "change",
    [
        lambda provider: provider.update(kind="bedrock"),
        lambda provider: provider.update(endpoint=provider["endpoint"] + "/anthropic/"),
        lambda provider: provider.update(deployments=[]),
        lambda provider: provider.update(extra="no"),
        lambda provider: provider["deployments"][0].update(extra="no"),
        lambda provider: provider["deployments"][0].update(alias="other"),
    ],
    ids=["kind", "endpoint", "no-deployments", "extra", "deployment-extra", "alias"],
)
def test_invalid_provider_shape_is_rejected(tmp_path: Path, change: Any) -> None:
    data = json.loads(FOUNDRY.read_text(encoding="utf-8"))
    change(data["agents"][5]["provider"])
    path = tmp_path / "invalid-shape.json"
    path.write_text(json.dumps(data), encoding="utf-8")
    assert _validate.validate("personalisation", path)


@pytest.mark.parametrize("case", RECORDED["tool"], ids=lambda case: case["name"])
def test_tool_schema_verdicts_match_the_recorded_old_run(case: dict[str, Any]) -> None:
    schema = json.loads((REPO / "plugins" / "legion" / "schemas" / "tool.schema.json").read_text(encoding="utf-8"))
    check = fastjsonschema.compile(schema)
    try:
        check(edited_descriptor(case))
        valid = True
    except fastjsonschema.JsonSchemaValueException:
        valid = False
    assert valid == case["valid"]


def test_cli_prints_nothing_and_exits_zero_for_a_valid_file(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["validate", "--kind", "personalisation", "--path", str(OWNER)]) == 0
    assert capsys.readouterr().out == ""
    assert run(["validate", "--kind", "project", "--path", str(FIXTURES / "project" / "valid.json")]) == 0


def test_cli_prints_each_issue_and_exits_one(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["validate", "--kind", "personalisation", "--path", str(FIXTURES / "personalisation" / "invalid-duplicate.json")]) == 1
    assert "agents: duplicate id 'codex-a'" in capsys.readouterr().out.splitlines()


def test_cli_rejects_an_unknown_kind(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["validate", "--kind", "other", "--path", str(OWNER)]) == 2
    assert "other" in capsys.readouterr().err
