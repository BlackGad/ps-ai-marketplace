import re
from typing import (
    Annotated,
    Literal,
    Optional,
    Self,
    Union,
)

from pydantic import (
    AfterValidator,
    BaseModel,
    ConfigDict,
    Field,
    model_validator,
)
from pydantic.alias_generators import to_camel

# The models follow the hand-written schemas in plugins/legion/schemas; PowerShell still checks files with those.


def _unique(items: list[str]) -> list[str]:
    if len(set(items)) < len(items):
        raise ValueError("items must be unique")
    return items


def _regex(pattern: str) -> str:
    try:
        re.compile(pattern)
    except re.error as error:
        raise ValueError(f"not a regular expression: {error}") from None
    return pattern


def _named_command(words: list[str]) -> list[str]:
    if not words[0]:
        raise ValueError("the first word must not be empty")
    return words


# Account, tool and channel ids; an id names files under the legion home, so it cannot hold a path.
NAME_PATTERN = r"[a-z][a-z0-9-]*"
Name = Annotated[str, Field(pattern=f"^{NAME_PATTERN}$")]
Text = Annotated[str, Field(min_length=1)]
# A Literal[1] would accept true; JSON Schema's const 1 does not.
SchemaVersion = Annotated[int, Field(ge=1, le=1)]


class SettingsModel(BaseModel):
    # A legion JSON file: camelCase property names, no unknown properties, exact JSON types.
    model_config = ConfigDict(alias_generator=to_camel, extra="forbid", strict=True)

    # JSON Schema has no null for an optional property: it is either absent or has its type.
    @model_validator(mode="before")
    @classmethod
    def _optional_is_not_null(cls, data: object) -> object:
        if isinstance(data, dict):
            for name, field in cls.model_fields.items():
                key = field.alias or name
                if not field.is_required() and key in data and data[key] is None:
                    raise ValueError(f"'{key}' must not be null")
        return data


class Deployment(SettingsModel):
    name: str
    model: Optional[str] = None
    alias: Optional[Text] = None


class Provider(SettingsModel):
    kind: Text
    endpoint: Annotated[str, Field(pattern=r"^https://[^/]+$")]
    default: str
    deployments: Annotated[list[Deployment], Field(min_length=1)]


class Agent(SettingsModel):
    id: Name
    tool: Name
    config_dir: Text
    command: Optional[Text] = None
    provider: Optional[Provider] = None


class Channel(SettingsModel):
    id: Name
    kind: Name
    target: Text
    accounts: Annotated[list[Name], Field(min_length=1), AfterValidator(_unique)]


class PersonalisationSettings(SettingsModel):
    schema_uri: Optional[str] = Field(None, alias="$schema")
    schema_version: SchemaVersion
    agents: list[Agent]
    channels: list[Channel]


class ProjectSettings(SettingsModel):
    schema_uri: Optional[str] = Field(None, alias="$schema")
    schema_version: SchemaVersion


class ChannelState(SettingsModel):
    variable: str
    folder: str
    remove: list[str]
    token_file: str
    setup: str


class ChannelReady(SettingsModel):
    command: str
    plugin_folder: dict[str, str]


class ChannelDescriptor(SettingsModel):
    schema_version: SchemaVersion
    id: Name
    launch: dict[str, list[str]]
    state: Optional[dict[str, ChannelState]] = None
    ready: Optional[ChannelReady] = None


# Tool descriptor patterns use look-ahead, which needs Python's regular expressions.
class ToolModel(SettingsModel):
    model_config = ConfigDict(regex_engine="python-re")


NO_PARENT = r"(?!.*(?:^|[/\\])\.\.(?:[/\\]|$))"
RelativeFolder = Annotated[str, Field(pattern=rf"^(?![/\\]|[A-Za-z]:){NO_PARENT}.*$")]
ExactRelativePath = Annotated[str, Field(pattern=r"^(?![/\\]|~)(?!.*[:*?])(?!.*(?:^|[/\\])\.{1,2}(?:[/\\]|$))(?!.*[/\\]{2})(?!.*[/\\]$).+$")]
EnvironmentName = Annotated[str, Field(pattern=r"^[A-Z_][A-Z0-9_]*$")]
Regex = Annotated[str, AfterValidator(_regex)]
Command = Annotated[list[str], Field(min_length=1), AfterValidator(_named_command)]


class Foundry(ToolModel):
    deployment_prefix: Text
    aliases: Annotated[list[Text], AfterValidator(_unique)]


class PurgeSetting(ToolModel):
    path: ExactRelativePath
    kind: Literal["settings", "marketplaces", "claude", "copilot", "toml"]


class Purge(ToolModel):
    paths: Annotated[list[ExactRelativePath], AfterValidator(_unique)]
    empty_dirs: Optional[Annotated[list[ExactRelativePath], AfterValidator(_unique)]] = None
    settings: list[PurgeSetting]


class MarketplaceListing(ToolModel):
    format: Literal["json"]
    collection_field: Optional[Text] = None
    root_field: Optional[Text] = None
    name_field: Text


class LinesListing(ToolModel):
    format: Literal["lines"]
    reject_pattern: Regex


class JsonListing(ToolModel):
    format: Literal["json"]
    id_field: Text
    enabled_field: Text


class Plugin(ToolModel):
    default_config_dir: Optional[Annotated[str, Field(pattern=rf"^{NO_PARENT}~/[^:]+$")]] = None
    installed_root: Optional[Annotated[str, Field(pattern=rf"^(?![/\\]|[A-Za-z]:|~[/\\]){NO_PARENT}.+$")]] = None
    cache_dir: Optional[ExactRelativePath] = None
    purge: Optional[Purge] = None
    marketplace_add: list[str]
    marketplace_add_ref: list[str]
    marketplace_remove: list[str]
    install: list[str]
    uninstall: list[str]
    marketplace_update: list[str]
    update: list[str]
    marketplace_listing: MarketplaceListing
    listing_env: Optional[dict[EnvironmentName, str]] = None
    marketplace_list: list[str]
    list_command: list[str] = Field(alias="list")
    listing: Annotated[Union[LinesListing, JsonListing], Field(discriminator="format")]


class Hooks(ToolModel):
    status: str
    hint: str


class Platform(ToolModel):
    needs: Annotated[list[Name], AfterValidator(_unique)]
    commands: list[Command]
    docs: str


class ScriptDownload(ToolModel):
    kind: Literal["script"]
    url: Text
    verification: Literal["vendor"]


# Per resolver: the properties it needs, the ones it does not allow, and its verification.
RESOLVER_RULES = {
    "release-assets": (["metadata_url", "asset_pattern"], ["asset_name", "url", "checksum_url"], "asset-digest"),
    "lts-index": (["metadata_url", "asset_name", "url", "checksum_url"], ["asset_pattern"], "checksum-file"),
}


class BinaryDownload(ToolModel):
    kind: Literal["msi", "exe", "zip"]
    resolver: Literal["release-assets", "lts-index"]
    metadata_url: Optional[Text] = None
    asset_pattern: Optional[Annotated[Regex, Field(min_length=1)]] = None
    asset_name: Optional[Text] = None
    url: Optional[Text] = None
    checksum_url: Optional[Text] = None
    verification: Literal["asset-digest", "checksum-file"]
    arguments: list[str]
    path_folder: Optional[RelativeFolder] = None

    @model_validator(mode="after")
    def _kind_and_resolver_rules(self) -> Self:
        given = self.model_fields_set
        if self.kind == "zip" and "path_folder" not in given:
            raise ValueError("a zip download needs pathFolder")
        if self.kind != "zip" and "path_folder" in given:
            raise ValueError("only a zip download has pathFolder")
        needed, refused, verification = RESOLVER_RULES[self.resolver]
        missing = [to_camel(name) for name in needed if name not in given]
        if missing:
            raise ValueError(f"resolver '{self.resolver}' needs {', '.join(missing)}")
        extra = [to_camel(name) for name in refused if name in given]
        if extra:
            raise ValueError(f"resolver '{self.resolver}' does not allow {', '.join(extra)}")
        if self.verification != verification:
            raise ValueError(f"resolver '{self.resolver}' needs verification '{verification}'")
        return self


Download = Annotated[Union[ScriptDownload, BinaryDownload], Field(discriminator="kind")]


class WindowsDownload(ToolModel):
    msi: Download
    zip: Download


class NpmInstall(ToolModel):
    check: Text
    command: Command


class Windows(ToolModel):
    winget_id: Text
    portable_command: Annotated[RelativeFolder, Field(min_length=1)]
    npm_when_available: Optional[NpmInstall] = None
    download: WindowsDownload


class Install(ToolModel):
    check: Command
    hint: str
    windows: Optional[Windows]
    macos: Platform
    linux: Platform


class ToolDescriptor(ToolModel):
    schema_version: SchemaVersion
    id: Name
    command: Text
    config_env: EnvironmentName
    foundry: Optional[Foundry]
    overseer_args: list[str]
    allow_rules: Optional[Annotated[list[Text], AfterValidator(_unique)]] = None
    plugin: Plugin
    hooks: Hooks
    install: Install


class PluginManifest(BaseModel):
    name: str
    version: str
