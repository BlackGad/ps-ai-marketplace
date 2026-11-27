import json
from pathlib import Path

from hatchling.metadata.plugin.interface import MetadataHookInterface


class PluginVersion(MetadataHookInterface):
    def update(self, metadata: dict[str, object]) -> None:
        manifest = Path(self.root) / "plugin.json"
        metadata["version"] = json.loads(manifest.read_text(encoding="utf-8"))["version"]
