# Regenerate the published editor schemas with python -m legion.core._schemas.

import json
from pathlib import Path

from pydantic.json_schema import GenerateJsonSchema, JsonSchemaValue
from pydantic_core import core_schema

from ._settings_models import (
    InstallRecipe,
    PersonalisationSettings,
    ProjectSettings,
    ToolDescriptor,
)


class _Draft7Schema(GenerateJsonSchema):
    def tagged_union_schema(self, schema: core_schema.TaggedUnionSchema) -> JsonSchemaValue:
        generated = super().tagged_union_schema(schema)
        # Draft-07 uses oneOf alone to validate tagged unions.
        generated.pop("discriminator", None)
        return generated


def _share_install_schema(schema: JsonSchemaValue) -> None:
    # The tools index reads #/$defs/install for helpers, where the descriptor's hint is optional.
    definitions = schema["$defs"]
    install = definitions.pop("Install")
    recipe_fields = {field.alias or name for name, field in InstallRecipe.model_fields.items()}
    definitions["install"] = {**install, "required": [name for name in install["required"] if name in recipe_fields]}
    schema["properties"]["install"] = {
        "allOf": [{"$ref": "#/$defs/install"}],
        "required": [name for name in install["required"] if name not in recipe_fields],
    }


def generated_schemas() -> dict[str, str]:
    files: dict[str, str] = {}
    for name, model, title in (
        ("personalisation", PersonalisationSettings, None),
        ("project", ProjectSettings, None),
        ("tool", ToolDescriptor, "legion tool descriptor"),
    ):
        ref_template = "#/$defs/{model}" if model is ToolDescriptor else "#/definitions/{model}"
        schema = model.model_json_schema(schema_generator=_Draft7Schema, ref_template=ref_template)
        if model is ToolDescriptor:
            _share_install_schema(schema)
        elif "$defs" in schema:
            schema["definitions"] = schema.pop("$defs")
        if title is None:
            schema.pop("title")
        else:
            schema["title"] = title
        published = {"$schema": "http://json-schema.org/draft-07/schema#", **schema}
        files[f"{name}.schema.json"] = json.dumps(published, indent=2) + "\n"
    return files


def main() -> None:
    schema_dir = Path(__file__).resolve().parents[3] / "schemas"
    for name, content in generated_schemas().items():
        path = schema_dir / name
        if path.exists() and path.read_text(encoding="utf-8") == content:
            print(f"skip: {name} (already done)")
        else:
            path.write_text(content, encoding="utf-8", newline="\n")


if __name__ == "__main__":
    main()
