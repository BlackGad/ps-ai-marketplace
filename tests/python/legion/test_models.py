import json
from pathlib import Path

import pytest
from pydantic import (
    BaseModel,
    JsonValue,
    ValidationError,
)

from legion._settings_models import (
    ChannelDescriptor,
    PersonalisationSettings,
    ProjectSettings,
    ToolDescriptor,
)

REPO = Path(__file__).resolve().parents[3]
FIXTURES = REPO / "tests" / "fixtures"
SKILLS = REPO / "plugins" / "legion" / "skills"
COPILOT = SKILLS / "legion-copilot" / "tool.json"
LTS_ZIP: dict[str, JsonValue] = {
    "kind": "zip",
    "resolver": "lts-index",
    "metadataUrl": "https://example.test/index.json",
    "assetName": "tool.zip",
    "url": "https://example.test/tool.zip",
    "checksumUrl": "https://example.test/sums.txt",
    "verification": "checksum-file",
    "arguments": [],
    "pathFolder": "tool",
}


def problems(error: pytest.ExceptionInfo[ValidationError]) -> list[str]:
    found: list[str] = []
    for problem in error.value.errors():
        where = ".".join(str(part) for part in problem["loc"])
        found.append(f"{where}: {problem['msg']}" if where else problem["msg"])
    return found


def with_download(download: dict[str, JsonValue]) -> str:
    data = json.loads(COPILOT.read_text(encoding="utf-8"))
    data["install"]["windows"]["download"]["zip"] = download
    return json.dumps(data)


@pytest.mark.parametrize("path", [*sorted(SKILLS.glob("legion-*/tool.json")), FIXTURES / "tools" / "legion-fourth" / "tool.json"], ids=lambda path: path.parent.name)
def test_every_tool_descriptor_is_accepted(path: Path) -> None:
    assert ToolDescriptor.model_validate_json(path.read_text(encoding="utf-8")).schema_version == 1


@pytest.mark.parametrize("path", [*sorted(SKILLS.glob("legion-*/channel.json")), *sorted((FIXTURES / "channels").glob("*/channel.json"))], ids=lambda path: path.parent.name)
def test_every_channel_descriptor_is_accepted(path: Path) -> None:
    assert ChannelDescriptor.model_validate_json(path.read_text(encoding="utf-8")).launch


@pytest.mark.parametrize("name", ["valid-owner", "valid-foundry", "invalid-tool", "invalid-duplicate", "invalid-foundry-default", "invalid-foundry-alias"])
def test_settings_with_the_right_shape_are_accepted(name: str) -> None:
    # Unknown tools and duplicate ids are reference problems; validate reports them after the shape passes.
    PersonalisationSettings.model_validate_json((FIXTURES / "personalisation" / f"{name}.json").read_text(encoding="utf-8"))


def test_project_file_is_accepted() -> None:
    ProjectSettings.model_validate_json((FIXTURES / "project" / "valid.json").read_text(encoding="utf-8"))


@pytest.mark.parametrize(
    ("path", "expected"),
    [
        ("personalisation/invalid-version.json", ["schemaVersion: Field required"]),
        ("personalisation/invalid-id.json", ["agents.0.id: String should match pattern '^[a-z][a-z0-9-]*$'"]),
        (
            "validate/invalid-schema-multi.json",
            [
                "schemaVersion: Input should be less than or equal to 1",
                "agents.0.id: String should match pattern '^[a-z][a-z0-9-]*$'",
                "agents.0.configDir: Field required",
                "extra: Extra inputs are not permitted",
            ],
        ),
    ],
)
def test_wrong_settings_shape_names_every_problem(path: str, expected: list[str]) -> None:
    with pytest.raises(ValidationError) as error:
        PersonalisationSettings.model_validate_json((FIXTURES / path).read_text(encoding="utf-8"))
    assert problems(error) == expected


def test_wrong_project_shape_names_every_problem() -> None:
    with pytest.raises(ValidationError) as error:
        ProjectSettings.model_validate_json((FIXTURES / "validate" / "invalid-project.json").read_text(encoding="utf-8"))
    assert problems(error) == ["schemaVersion: Input should be less than or equal to 1", "extra: Extra inputs are not permitted"]


@pytest.mark.parametrize(
    ("text", "expected"),
    [
        ('{"schemaVersion": true}', "schemaVersion: Input should be a valid integer"),
        ('{"schemaVersion": 1, "$schema": null}', "Value error, '$schema' must not be null"),
        ('{"schemaVersion": "1"}', "schemaVersion: Input should be a valid integer"),
    ],
)
def test_project_rejects_json_types_the_schema_rejects(text: str, expected: str) -> None:
    with pytest.raises(ValidationError) as error:
        ProjectSettings.model_validate_json(text)
    assert problems(error) == [expected]


def test_channel_accounts_must_be_unique() -> None:
    text = json.dumps({"schemaVersion": 1, "agents": [], "channels": [{"id": "tg", "kind": "telegram", "target": "1", "accounts": ["a", "a"]}]})
    with pytest.raises(ValidationError) as error:
        PersonalisationSettings.model_validate_json(text)
    assert problems(error) == ["channels.0.accounts: Value error, items must be unique"]


def test_lts_index_zip_download_is_accepted() -> None:
    ToolDescriptor.model_validate_json(with_download(LTS_ZIP))


@pytest.mark.parametrize(
    ("change", "message"),
    [
        ({"pathFolder": None}, "a zip download needs pathFolder"),
        ({"kind": "msi"}, "only a zip download has pathFolder"),
        ({"assetPattern": "x"}, "resolver 'lts-index' does not allow assetPattern"),
        ({"checksumUrl": None}, "resolver 'lts-index' needs checksumUrl"),
        ({"verification": "asset-digest"}, "resolver 'lts-index' needs verification 'checksum-file'"),
        ({"resolver": "release-assets", "assetName": None, "url": None, "checksumUrl": None}, "resolver 'release-assets' needs assetPattern"),
    ],
)
def test_download_rules_follow_kind_and_resolver(change: dict[str, JsonValue], message: str) -> None:
    download: dict[str, JsonValue] = {key: value for key, value in (LTS_ZIP | change).items() if value is not None}
    with pytest.raises(ValidationError) as error:
        ToolDescriptor.model_validate_json(with_download(download))
    assert [problem.split("Value error, ")[-1] for problem in problems(error)] == [message]


@pytest.mark.parametrize(
    ("pointer", "value"),
    [
        (("install", "windows", "download", "zip", "assetPattern"), "("),
        (("plugin", "listing", "rejectPattern"), "["),
        (("allowRules",), ["x", "x"]),
        (("plugin", "cacheDir"), "../x"),
        (("plugin", "defaultConfigDir"), "/abs"),
        (("plugin", "listingEnv"), {"lower": "1"}),
        (("foundry", "aliases"), ["a", "a"]),
        (("hooks", "extra"), ""),
        (("install", "windows", "portableCommand"), "C:/x.exe"),
        (("plugin", "installedRoot"), "~/x"),
    ],
)
def test_tool_descriptor_rejects_broken_values(pointer: tuple[str, ...], value: JsonValue) -> None:
    data = json.loads(COPILOT.read_text(encoding="utf-8"))
    target = data
    for key in pointer[:-1]:
        target = target[key]
    target[pointer[-1]] = value
    with pytest.raises(ValidationError) as error:
        ToolDescriptor.model_validate_json(json.dumps(data))
    (problem,) = problems(error)
    assert problem.startswith(pointer[0])
    assert pointer[-1] in problem


def test_tool_foundry_and_windows_may_be_null() -> None:
    data = json.loads(COPILOT.read_text(encoding="utf-8"))
    data["foundry"] = None
    data["install"]["windows"] = None
    tool = ToolDescriptor.model_validate_json(json.dumps(data))
    assert tool.foundry is None
    assert tool.install.windows is None


def patterns(node: JsonValue) -> set[str]:
    if isinstance(node, list):
        return set().union(*(patterns(item) for item in node))
    if not isinstance(node, dict):
        return set()
    found = {value for key, value in node.items() if key == "pattern" and isinstance(value, str)}
    return found.union(*(patterns(value) for value in node.values()))


# Until the schema files are generated from the models, both must hold the same patterns.
@pytest.mark.parametrize(("name", "model"), [("personalisation", PersonalisationSettings), ("tool", ToolDescriptor)])
def test_model_patterns_match_the_schema_file(name: str, model: type[BaseModel]) -> None:
    schema = json.loads((REPO / "plugins" / "legion" / "schemas" / f"{name}.schema.json").read_text(encoding="utf-8"))
    assert patterns(model.model_json_schema()) == patterns(schema)
