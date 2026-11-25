import json
import re
from typing import Literal, Optional
from urllib.parse import urlsplit

from legion.core._settings_models import Deployment, Provider, SettingsModel, ToolDescriptor
from legion.services.foundry._az import AzCognitiveAccount, AzDeployment, call, check_token


class DiscoveredDeployment(SettingsModel):
    name: str
    model: str


class FoundryDiscovery(SettingsModel):
    source: Literal["management", "none"]
    error: str
    deployments: list[DiscoveredDeployment]


class ListedDeployment(DiscoveredDeployment):
    state: Literal["new", "kept", "gone"]


class FoundryList(SettingsModel):
    source: Literal["management", "none"]
    error: str
    deployments: list[ListedDeployment]


def endpoint_url(value: str) -> str:
    parsed = urlsplit(value)
    if parsed.scheme != "https" or not parsed.hostname or parsed.username or parsed.password:
        raise ValueError("endpoint must start with https://")
    host = parsed.hostname
    try:
        port = parsed.port
    except ValueError:
        raise ValueError("endpoint must start with https://") from None
    authority = f"[{host}]" if ":" in host else host
    if port not in (None, 443):
        authority += f":{port}"
    return f"https://{authority}"


def discover(endpoint: str, descriptor: ToolDescriptor) -> FoundryDiscovery:
    check_token()
    host = urlsplit(endpoint).hostname
    if host is None:
        raise ValueError("endpoint must start with https://")
    resource_name = host.split(".")[0]
    errors: list[str] = []
    subscriptions = [""]
    for index, subscription in enumerate(subscriptions):
        suffix = ["--subscription", subscription] if subscription else []
        try:
            accounts = [AzCognitiveAccount.model_validate(item) for item in json.loads(call(["cognitiveservices", "account", "list", "-o", "json", *suffix]))]
            matched = next((item for item in accounts if item.name.lower() == resource_name.lower()), None)
            if matched:
                rows = [
                    AzDeployment.model_validate(item)
                    for item in json.loads(call(["cognitiveservices", "account", "deployment", "list", "--name", matched.name, "--resource-group", matched.resource_group, "-o", "json", *suffix]))
                ]
                prefix = descriptor.foundry.deployment_prefix if descriptor.foundry else ""
                deployments = [DiscoveredDeployment(name=row.name, model=row.model_name) for row in rows if row.model_name.lower().startswith(prefix.lower())]
                return FoundryDiscovery(source="management", error="", deployments=deployments)
        except (ValueError, OSError) as error:
            errors.append(str(error))
        if index == 0:
            try:
                subscriptions.extend(item.strip() for item in call(["account", "list", "--query", "[].id", "-o", "tsv"]).splitlines() if item.strip())
            except (ValueError, OSError) as error:
                errors.append(str(error))
    return FoundryDiscovery(source="none", error="\n".join(errors) if errors else "No deployments found; https://ai.azure.com → your project → Models + endpoints", deployments=[])


def listing(discovery: FoundryDiscovery, existing: list[Deployment]) -> FoundryList:
    names = {item.name for item in discovery.deployments}
    previous = {item.name for item in existing}
    rows = [ListedDeployment(name=item.name, model=item.model, state="kept" if item.name in previous else "new") for item in discovery.deployments]
    rows.extend(ListedDeployment(name=item.name, model=item.model or "", state="gone" if discovery.source == "management" else "kept") for item in existing if item.name not in names)
    return FoundryList(source=discovery.source, error=discovery.error, deployments=rows)


def standard(deployments: list[DiscoveredDeployment], descriptor: ToolDescriptor) -> tuple[str, list[str]]:
    # This is the Foundry alias rule from the tool descriptors; no library ranks its tokens and numeric versions.
    aliases = [alias for alias in descriptor.foundry.aliases if alias != "fable"] if descriptor.foundry else []
    available = []
    for item in deployments:
        tokens = re.split(r"[-_.\s]+", f"{item.name} {item.model}".lower())
        if "fable" in tokens:
            continue
        version = [int(word) for word in re.split(r"[-_.\s]+", item.name) if word.isdigit()]
        if not version:
            version = [int(word) for word in re.split(r"[-_.\s]+", item.model) if word.isdigit()]
        available.append((item.name, tokens, version))
    default = ""
    result: list[str] = []
    for alias in aliases or ["default"]:
        word = "sol" if alias == "default" else alias
        candidates = [item for item in available if word in item[1]]
        if alias == "default" and not candidates:
            candidates = available
        width = max((len(item[2]) for item in candidates), default=0)
        best = max((tuple(item[2] + [0] * (width - len(item[2]))) for item in candidates), default=None)
        newest = [item[0] for item in candidates if tuple(item[2] + [0] * (width - len(item[2]))) == best]
        if len(newest) != 1:
            choices = newest or [item.name for item in deployments]
            raise ValueError(
                f"standard mapping unresolved for '{alias}'; candidates: {', '.join(choices) if choices else '(none discovered)'}. "
                "Ask the owner about this choice, then use explicit --alias/--default."
            )
        name = newest[0]
        if alias == "default":
            default = name
        else:
            result.append(f"{name}={alias}")
            if not default or alias == "sonnet":
                default = name
    return default, result


def provider_block(
    endpoint: str,
    descriptor: ToolDescriptor,
    names: list[str],
    default: Optional[str],
    aliases: Optional[list[str]],
    discovery: FoundryDiscovery,
    existing: Optional[Provider] = None,
    use_standard: bool = False,
) -> Provider:
    known = {item.name: item.model for item in discovery.deployments}
    if existing:
        known.update({item.name: item.model for item in existing.deployments if item.name not in known and item.model is not None})
    if use_standard:
        if names and any(name not in {item.name for item in discovery.deployments} for name in names):
            missing = next(name for name in names if name not in {item.name for item in discovery.deployments})
            raise ValueError(f"standard mapping requires discovery of deployment '{missing}'")
        names = names or [item.name for item in discovery.deployments]
        selected = [item for item in discovery.deployments if item.name in names]
        default, aliases = standard(selected, descriptor)
    if not names or not default:
        raise ValueError("Foundry requires --deployment and --default")
    if default not in names:
        raise ValueError(f"default '{default}' is not one of --deployment")
    mapping = {item.name: item.alias for item in existing.deployments if item.alias} if existing and aliases is None else {}
    for pair in aliases or []:
        parts = pair.split("=", 1)
        if len(parts) != 2 or parts[0] not in names or not descriptor.foundry or parts[1] not in descriptor.foundry.aliases:
            raise ValueError(f"invalid alias '{pair}'; use name=alias for a selected deployment")
        if parts[0] in mapping:
            raise ValueError(f"duplicate alias mapping for '{parts[0]}'")
        mapping[parts[0]] = parts[1]
    rows = [Deployment.model_validate({"name": name, **({"model": known[name]} if known.get(name) else {}), **({"alias": mapping[name]} if mapping.get(name) else {})}) for name in names]
    return Provider(kind="foundry", endpoint=endpoint, default=default, deployments=rows)
