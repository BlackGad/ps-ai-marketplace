from pathlib import Path
from typing import Literal, Optional

from pydantic import BaseModel, ConfigDict
from pydantic.alias_generators import to_camel


class ProviderSpec(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    name: Literal["legion-foundry"]
    type: Literal["anthropic"]
    base_url: str
    bearer_token: str
    headers: dict[str, str]


class ProviderModel(BaseModel):
    model_config = ConfigDict(alias_generator=to_camel, populate_by_name=True)

    id: str
    provider: Literal["legion-foundry"]
    model_id: str
    wire_model: str


class ProviderFile(BaseModel):
    providers: list[ProviderSpec]
    models: list[ProviderModel]


class Launch(BaseModel):
    set: dict[str, str]
    clear: list[str]
    provider_file: Optional[tuple[Path, ProviderFile]] = None
    notice: Optional[str] = None
