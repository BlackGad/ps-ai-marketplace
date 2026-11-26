# From the repository root: uv run --project plugins/legion python tools/generate.py

import json
from pathlib import Path

import click
from pydantic_core import from_json

from legion.core import _schemas
from legion.core._atomic_write import atomic_write_bytes
from legion.core._settings_models import (
    CatalogTool,
    ChannelDescriptor,
    HelpersCatalog,
    ToolDescriptor,
    ToolsCatalog,
)
from legion.core._validate import read_text

PLUGIN_ROOT = Path(__file__).resolve().parents[1] / "plugins" / "legion"


def _check_skill(path: Path, kind: str, skill_id: str) -> None:
    if path.parent.name != f"legion-{skill_id}":
        raise ValueError(f"{kind} id '{skill_id}' does not match its skill directory: {path}")
    if not (path.parent / "SKILL.md").is_file():
        raise ValueError(f"{kind} '{skill_id}' requires SKILL.md: {path}")


def _check_channels(skills: Path, tool_ids: set[str]) -> None:
    for path in _descriptor_paths(skills, "channel.json"):
        try:
            channel = ChannelDescriptor.model_validate_json(read_text(path))
        except ValueError as error:
            raise ValueError(f"invalid channel descriptor '{path}': {error}") from error
        _check_skill(path, "channel", channel.id)
        for tool_id in channel.launch:
            if tool_id not in tool_ids:
                raise ValueError(f"unknown channel tool '{tool_id}': {path}")


def _check_helpers(path: Path, tools: dict[str, ToolDescriptor]) -> None:
    try:
        helpers = HelpersCatalog.model_validate_json(read_text(path)).root
    except ValueError as error:
        raise ValueError(f"invalid helper recipes '{path}': {error}") from error
    for helper_id in helpers:
        if helper_id in tools:
            raise ValueError(f"helper/tool id collision '{helper_id}': {path}")
    recipes = {**helpers, **{tool.id: tool.install for tool in tools.values()}}
    for recipe_id, recipe in recipes.items():
        for platform in (recipe.macos, recipe.linux):
            for need in platform.needs:
                if need not in helpers:
                    raise ValueError(f"unknown helper prerequisite '{need}' for '{recipe_id}'")
            if platform.needs and recipe_id in helpers:
                raise ValueError(f"helper '{recipe_id}' cannot have prerequisites")


def _source_order(value: object, source: object) -> object:
    # Hand-built, reason: Pydantic dumps in model field order. The shipped index
    # preserves descriptor key order inside projected plugin and hook objects.
    if isinstance(value, dict) and isinstance(source, dict):
        return {key: _source_order(value[key], child) for key, child in source.items() if key in value}
    if isinstance(value, list) and isinstance(source, list):
        return [_source_order(item, child) for item, child in zip(value, source, strict=True)]
    return value


def _descriptor_paths(skills: Path, file_name: str) -> list[Path]:
    return sorted((path for path in skills.glob(f"legion-*/{file_name}") if path.is_file()), key=lambda path: path.parent.name)


def render_tools_index(skills: Path) -> str:
    if not skills.is_dir():
        raise ValueError(f"missing skills directory: {skills}")
    tools: dict[str, ToolDescriptor] = {}
    inputs: dict[str, tuple[Path, dict[str, object]]] = {}
    for path in _descriptor_paths(skills, "tool.json"):
        try:
            source = from_json(read_text(path))
            tool = ToolDescriptor.model_validate(source)
        except ValueError as error:
            raise ValueError(f"invalid tool descriptor '{path}': {error}") from error
        if tool.id in tools:
            raise ValueError(f"duplicate tool id '{tool.id}': {path}")
        tools[tool.id] = tool
        inputs[tool.id] = path, source

    for tool_id, (path, _) in inputs.items():
        _check_skill(path, "tool", tool_id)
    _check_channels(skills, set(tools))
    _check_helpers(skills.parent / "helpers.json", tools)

    entries = [
        CatalogTool.model_validate(
            {
                "id": tool.id,
                "command": tool.command,
                "configEnv": tool.config_env,
                "plugin": tool.plugin,
                "hooks": tool.hooks,
                "installHint": tool.install.hint,
            }
        )
        for tool in sorted(tools.values(), key=lambda tool: tool.id)
    ]
    catalog = ToolsCatalog.model_validate({"schemaVersion": 1, "tools": entries})
    data = catalog.model_dump(mode="json", by_alias=True, exclude_unset=True)
    for entry in data["tools"]:
        _, source = inputs[entry["id"]]
        for key in ("plugin", "hooks"):
            entry[key] = _source_order(entry[key], source[key])
    return json.dumps(data, ensure_ascii=False, indent=2) + "\n"


@click.command()
@click.option("--check", is_flag=True, help="Check the tools index without writing files.")
def main(check: bool) -> None:
    try:
        content = render_tools_index(PLUGIN_ROOT / "skills").encode("utf-8")
        index = PLUGIN_ROOT / "tools.json"
        current = index.is_file() and index.read_bytes() == content
        if check and not current:
            raise click.ClickException("tools index is missing or out of date. Run tools/generate.py.")
        if not check:
            _schemas.main(PLUGIN_ROOT / "schemas")
            if not current:
                atomic_write_bytes(index, content, keep_mode=False, add_mode=0o644)
        click.echo("skip: tools index (already done)" if current else "updated: tools index")
    except (OSError, ValueError) as error:
        raise click.ClickException(str(error)) from error


if __name__ == "__main__":
    main()
