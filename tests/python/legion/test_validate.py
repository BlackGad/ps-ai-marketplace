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
FILES = {
    "valid-owner": OWNER,
    "valid-foundry": FOUNDRY,
    "valid-project": FIXTURES / "project" / "valid.json",
    "invalid-tool": FIXTURES / "personalisation" / "invalid-tool.json",
    "invalid-version": FIXTURES / "personalisation" / "invalid-version.json",
    "invalid-duplicate": FIXTURES / "personalisation" / "invalid-duplicate.json",
    "invalid-id": FIXTURES / "personalisation" / "invalid-id.json",
    "invalid-foundry-default": FIXTURES / "personalisation" / "invalid-foundry-default.json",
    "invalid-foundry-alias": FIXTURES / "personalisation" / "invalid-foundry-alias.json",
    "invalid-channels": FIXTURES / "validate" / "invalid-channels.json",
    "invalid-schema-multi": FIXTURES / "validate" / "invalid-schema-multi.json",
    "invalid-provider-kind": FIXTURES / "validate" / "invalid-provider-kind.json",
    "invalid-project": FIXTURES / "validate" / "invalid-project.json",
    "malformed": FIXTURES / "validate" / "malformed.json",
}
RECORDED_FILE_CASES = [case for case in RECORDED["validate"] if case["name"] in FILES]


def write_bom_crlf(path: Path) -> Path:
    text = OWNER.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
    path.write_bytes(b"\xef\xbb\xbf" + text.encode("utf-8"))
    return path


@pytest.mark.parametrize("case", RECORDED_FILE_CASES, ids=lambda case: case["name"])
def test_verdict_and_semantic_messages_match_the_recorded_old_run(case: dict[str, Any]) -> None:
    issues = _validate.validate(case["kind"], FILES[case["name"]])
    assert (1 if issues else 0) == case["exit"]
    if not case["output"] or not case["output"][0].startswith("$:"):
        assert issues == case["output"]
        return
    assert issues
    for issue in issues:
        assert issue.startswith("$: ")
        assert issue.endswith(SUFFIX)


def test_schema_errors_stop_the_semantic_checks() -> None:
    issues = _validate.validate("personalisation", FILES["invalid-schema-multi"])
    assert all(issue.startswith("$: ") for issue in issues)
    assert not any(issue.startswith(("agents:", "channels:", "channel ")) for issue in issues)


def test_schema_message_is_normalised_to_one_line() -> None:
    (issue,) = _validate.validate("personalisation", FILES["invalid-version"])
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


def test_malformed_json_is_one_framed_line() -> None:
    (issue,) = _validate.validate("personalisation", FILES["malformed"])
    assert issue.startswith("$: ")
    assert issue.endswith(SUFFIX)


def test_project_schema_rejects_extra_properties() -> None:
    assert _validate.validate("project", FILES["invalid-project"])


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
    name = case["name"]
    path = FIXTURES / "validate" / "tool-cases" / f"{name}.json"
    if name.startswith("real-"):
        path = REPO / "plugins" / "legion" / "skills" / f"legion-{name.removeprefix('real-')}" / "tool.json"
    schema = json.loads((REPO / "plugins" / "legion" / "schemas" / "tool.schema.json").read_text(encoding="utf-8"))
    check = fastjsonschema.compile(schema)
    try:
        check(json.loads(path.read_text(encoding="utf-8")))
        valid = True
    except fastjsonschema.JsonSchemaValueException:
        valid = False
    assert valid == case["valid"]


def test_schemas_are_draft_7() -> None:
    for path in (REPO / "plugins" / "legion" / "schemas").glob("*.schema.json"):
        assert json.loads(path.read_text(encoding="utf-8"))["$schema"] == "http://json-schema.org/draft-07/schema#"


def test_cli_prints_nothing_and_exits_zero_for_a_valid_file(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["validate", "--kind", "personalisation", "--path", str(OWNER)]) == 0
    assert capsys.readouterr().out == ""
    assert run(["validate", "--kind", "project", "--path", str(FILES["valid-project"])]) == 0


def test_cli_prints_each_issue_and_exits_one(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["validate", "--kind", "personalisation", "--path", str(FILES["invalid-duplicate"])]) == 1
    assert "agents: duplicate id 'codex-a'" in capsys.readouterr().out.splitlines()


def test_cli_rejects_an_unknown_kind(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["validate", "--kind", "other", "--path", str(OWNER)]) == 2
    assert "other" in capsys.readouterr().err
