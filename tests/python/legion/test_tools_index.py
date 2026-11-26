import json
import re
import shutil
from importlib.util import module_from_spec, spec_from_file_location
from pathlib import Path
from types import ModuleType
from typing import Any

import pytest
from click.testing import CliRunner

from legion.core._settings_models import ToolsCatalog

REPO = Path(__file__).resolve().parents[3]
PLUGIN = REPO / "plugins" / "legion"
FOURTH = REPO / "tests" / "fixtures" / "tools" / "legion-fourth"
PLUGIN_ARGUMENTS = ("marketplaceAdd", "marketplaceRemove", "install", "marketplaceList", "list", "marketplaceUpdate", "update")


@pytest.fixture(scope="module")
def generator() -> ModuleType:
    spec = spec_from_file_location("generate", REPO / "tools" / "generate.py")
    assert spec is not None
    assert spec.loader is not None
    module = module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


@pytest.fixture
def plugin(tmp_path: Path) -> Path:
    for descriptor in (PLUGIN / "skills").glob("legion-*/*.json"):
        if descriptor.name not in ("tool.json", "channel.json"):
            continue
        skill = tmp_path / "skills" / descriptor.parent.name
        skill.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(descriptor, skill / descriptor.name)
        shutil.copyfile(descriptor.parent / "SKILL.md", skill / "SKILL.md")
    shutil.copytree(PLUGIN / "schemas", tmp_path / "schemas")
    shutil.copyfile(PLUGIN / "helpers.json", tmp_path / "helpers.json")
    return tmp_path


def edit_json(path: Path, keys: str, value: Any) -> None:
    data = json.loads(path.read_bytes())
    *parents, key = keys.split(".")
    target = data
    for parent in parents:
        target = target[parent]
    target[key] = value
    path.write_text(json.dumps(data), encoding="utf-8")


def test_tools_index_is_current(generator: ModuleType) -> None:
    content = generator.render_tools_index(PLUGIN / "skills").encode("utf-8")
    assert content == (PLUGIN / "tools.json").read_bytes()
    assert not content.startswith(b"\xef\xbb\xbf")
    assert b"\r" not in content
    assert content.endswith(b"\n")
    assert not content.endswith(b"\n\n")


def test_command_checks_writes_and_skips(generator: ModuleType, plugin: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    runner = CliRunner()
    monkeypatch.setattr(generator, "PLUGIN_ROOT", plugin)
    index = plugin / "tools.json"
    check = runner.invoke(generator.main, ["--check"])
    assert check.exit_code == 1
    assert "missing or out of date" in check.output
    assert not index.exists()

    schema = plugin / "schemas" / "tool.schema.json"
    schema.unlink()
    generation = runner.invoke(generator.main)
    assert generation.exit_code == 0
    assert "updated: tool.schema.json" in generation.output
    assert schema.read_text(encoding="utf-8") == (PLUGIN / "schemas" / schema.name).read_text(encoding="utf-8")
    expected = (PLUGIN / "tools.json").read_bytes()
    assert index.read_bytes() == expected
    original = index.stat().st_mtime_ns
    assert "skip: tools index (already done)" in runner.invoke(generator.main).output
    assert runner.invoke(generator.main, ["--check"]).exit_code == 0
    assert index.stat().st_mtime_ns == original

    index.write_bytes(expected + b"\n")
    assert runner.invoke(generator.main, ["--check"]).exit_code == 1
    assert index.read_bytes() == expected + b"\n"
    assert runner.invoke(generator.main).exit_code == 0
    assert index.read_bytes() == expected


@pytest.mark.parametrize(
    ("file_name", "field", "value"),
    [
        ("helpers.json", "node.check", 42),
        ("skills/legion-codex/tool.json", "plugin.cacheDir", "../outside"),
        ("skills/legion-telegram/channel.json", "launch", {"unknown": []}),
    ],
)
def test_command_keeps_index_when_validation_fails(generator: ModuleType, plugin: Path, monkeypatch: pytest.MonkeyPatch, file_name: str, field: str, value: Any) -> None:
    runner = CliRunner()
    monkeypatch.setattr(generator, "PLUGIN_ROOT", plugin)
    index = plugin / "tools.json"
    original = b"index contents to preserve"
    index.write_bytes(original)
    edit_json(plugin / file_name, field, value)
    for args in ([], ["--check"]):
        result = runner.invoke(generator.main, args)
        assert result.exit_code == 1
        assert Path(file_name).name in result.output
        assert index.read_bytes() == original


@pytest.mark.parametrize("arguments", [[], ["--namespace", "", " ", "2026-11-19", "café <tag>"]])
def test_fourth_tool_projects_literal_arguments(generator: ModuleType, plugin: Path, arguments: list[str]) -> None:
    skills = plugin / "skills"
    skill = shutil.copytree(FOURTH, skills / FOURTH.name)
    for field in PLUGIN_ARGUMENTS:
        edit_json(skill / "tool.json", f"plugin.{field}", arguments)
    edit_json(skill / "tool.json", "hooks.status", "")
    edit_json(skill / "tool.json", "id", "aaa")
    skill.rename(skills / "legion-aaa")
    channel = REPO / "tests" / "fixtures" / "channels" / "legion-fixture-channel"
    shutil.copytree(channel, skills / channel.name)
    content = generator.render_tools_index(skills)
    catalog = ToolsCatalog.model_validate_json(content)
    assert [tool.id for tool in catalog.tools] == ["aaa", "claude", "codex", "copilot"]
    tool = catalog.tools[0]
    assert tool.command == "fourth-cli"
    assert tool.hooks.status == ""
    projected = tool.plugin.model_dump(by_alias=True)
    assert all(projected[field] == arguments for field in PLUGIN_ARGUMENTS)
    assert all(key not in content for key in ("foundry", "overseerArgs", "SkillRoot", "legacyHookTrust"))


@pytest.mark.parametrize("field", PLUGIN_ARGUMENTS)
@pytest.mark.parametrize("value", [None, "", 42, {}, ["valid", None], ["valid", 42]])
def test_rejects_tool_argument_type(generator: ModuleType, plugin: Path, field: str, value: Any) -> None:
    descriptor = plugin / "skills" / "legion-codex" / "tool.json"
    edit_json(descriptor, f"plugin.{field}", value)
    with pytest.raises(ValueError, match=field):
        generator.render_tools_index(plugin / "skills")


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("schemaVersion", 2, "schemaVersion"),
        ("id", "../outside", "id"),
        ("id", "mismatch", "does not match"),
        ("id", "claude", "duplicate tool id 'claude'"),
        ("command", 12, "command"),
        ("unexpected", "value", "unexpected"),
        ("plugin", [], "plugin"),
        ("plugin.listing", [], "listing"),
        ("plugin.listing.format", ["json"], "listing"),
        ("plugin.listing.rejectPattern", "[", "regular expression"),
        ("install.windows.portableCommand", "../outside.exe", "portableCommand"),
        ("overseerArgs", ["--flag", 42], "overseerArgs"),
        *[("hooks.status", value, "hooks.status") for value in (None, 42, ["status"])],
        *[("plugin.cacheDir", path, "cacheDir") for path in ("../outside", "cache/../../outside", "/outside", "C:/outside", "plugins/*", "plugins/?")],
    ],
)
def test_rejects_invalid_tool(generator: ModuleType, plugin: Path, field: str, value: Any, message: str) -> None:
    edit_json(plugin / "skills" / "legion-codex" / "tool.json", field, value)
    with pytest.raises(ValueError, match=re.escape(message)):
        generator.render_tools_index(plugin / "skills")


def test_rejects_invalid_tool_download_pattern(generator: ModuleType, plugin: Path) -> None:
    edit_json(plugin / "skills" / "legion-copilot" / "tool.json", "install.windows.download.zip.assetPattern", "[")
    with pytest.raises(ValueError, match="regular expression"):
        generator.render_tools_index(plugin / "skills")


@pytest.mark.parametrize("skill", ["codex", "telegram"])
def test_requires_skill_markdown(generator: ModuleType, plugin: Path, skill: str) -> None:
    (plugin / "skills" / f"legion-{skill}" / "SKILL.md").unlink()
    with pytest.raises(ValueError, match=r"SKILL\.md"):
        generator.render_tools_index(plugin / "skills")


@pytest.mark.parametrize("text", ["{invalid", '{"schemaVersion":1}'])
def test_rejects_malformed_or_incomplete_tool_descriptor(generator: ModuleType, plugin: Path, text: str) -> None:
    (plugin / "skills" / "legion-codex" / "tool.json").write_text(text, encoding="utf-8")
    with pytest.raises(ValueError, match=r"tool\.json"):
        generator.render_tools_index(plugin / "skills")


def test_reports_invalid_neighbors_in_folder_order(generator: ModuleType, plugin: Path) -> None:
    edit_json(plugin / "skills" / "legion-codex" / "tool.json", "id", "aaa")
    edit_json(plugin / "skills" / "legion-claude" / "tool.json", "id", "zzz")
    with pytest.raises(ValueError, match="tool id 'zzz' does not match"):
        generator.render_tools_index(plugin / "skills")


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("schemaVersion", 2, "schemaVersion"),
        ("id", "wrong", "does not match"),
        ("launch", {"unknown": []}, "unknown channel tool 'unknown'"),
        ("launch", {"claude": [1]}, "launch"),
        ("launch", {"claude": "not an array"}, "launch"),
        ("extra", 1, "extra"),
    ],
)
def test_rejects_invalid_channel(generator: ModuleType, plugin: Path, field: str, value: Any, message: str) -> None:
    edit_json(plugin / "skills" / "legion-telegram" / "channel.json", field, value)
    with pytest.raises(ValueError, match=re.escape(message)):
        generator.render_tools_index(plugin / "skills")


@pytest.mark.parametrize(
    ("field", "value", "message"),
    [
        ("node.check", 42, "node.check"),
        ("git.windows.download.msi.assetPattern", "[", "regular expression"),
        ("node.windows.download.zip.checksumUrl", None, "checksumUrl"),
        ("node.macos.needs", ["git"], "helper 'node' cannot have prerequisites"),
        ("node.linux.needs", ["missing"], "unknown helper prerequisite 'missing'"),
    ],
)
def test_rejects_invalid_helper(generator: ModuleType, plugin: Path, field: str, value: Any, message: str) -> None:
    edit_json(plugin / "helpers.json", field, value)
    with pytest.raises(ValueError, match=re.escape(message)):
        generator.render_tools_index(plugin / "skills")


def test_rejects_helper_tool_collision(generator: ModuleType, plugin: Path) -> None:
    helpers = plugin / "helpers.json"
    recipe = json.loads(helpers.read_bytes())["node"]
    edit_json(helpers, "codex", recipe)
    with pytest.raises(ValueError, match="helper/tool id collision 'codex'"):
        generator.render_tools_index(plugin / "skills")


@pytest.mark.parametrize("need", ["codex", "missing-helper"])
def test_tool_prerequisites_must_be_helpers(generator: ModuleType, plugin: Path, need: str) -> None:
    edit_json(plugin / "skills" / "legion-codex" / "tool.json", "install.macos.needs", [need])
    with pytest.raises(ValueError, match=f"unknown helper prerequisite '{need}'"):
        generator.render_tools_index(plugin / "skills")
