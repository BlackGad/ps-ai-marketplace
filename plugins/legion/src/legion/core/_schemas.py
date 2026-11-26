# Regenerate the published editor schemas with python -m legion.core._schemas.

import json
from pathlib import Path

from pydantic.json_schema import GenerateJsonSchema, JsonSchemaValue
from pydantic_core import core_schema

from ._settings_models import PersonalisationSettings, ProjectSettings, ToolDescriptor


class _Draft7Schema(GenerateJsonSchema):
    def field_title_should_be_set(self, schema: object) -> bool:
        return False

    def model_schema(self, schema: core_schema.ModelSchema) -> JsonSchemaValue:
        generated = super().model_schema(schema)
        generated.pop("title", None)
        return generated

    def tagged_union_schema(self, schema: core_schema.TaggedUnionSchema) -> JsonSchemaValue:
        generated = super().tagged_union_schema(schema)
        # Draft-07 uses oneOf alone to validate tagged unions.
        generated.pop("discriminator", None)
        return generated


def generated_schemas() -> dict[str, str]:
    files: dict[str, str] = {}
    for name, model, title in (
        ("personalisation", PersonalisationSettings, None),
        ("project", ProjectSettings, None),
        ("tool", ToolDescriptor, "legion tool descriptor"),
    ):
        schema = model.model_json_schema(schema_generator=_Draft7Schema, ref_template="#/$defs/{model}")
        if title is not None:
            schema["title"] = title
        published = {"$schema": "http://json-schema.org/draft-07/schema#", **schema}
        files[f"{name}.schema.json"] = json.dumps(published, indent=2) + "\n"
    return files


def main(schema_dir: Path = Path(__file__).resolve().parents[3] / "schemas") -> None:
    for name, content in generated_schemas().items():
        path = schema_dir / name
        if path.exists() and path.read_text(encoding="utf-8") == content:
            print(f"skip: {name} (already done)")
        else:
            path.write_text(content, encoding="utf-8", newline="\n")
            print(f"updated: {name}")


if __name__ == "__main__":
    main()
