import json
import shutil
from pathlib import Path
from typing import Literal

from legion.core._atomic_write import atomic_write_bytes
from legion.core._home import (
    home_path,
    is_reparse,
    resolve_directory,
    same_path,
)
from legion.core._validate import read_text

HUB_PATH = "~/.legion/knowledge"
HUB_FILES = {
    "wikis.json": '{\n  "default": "<HUB>",\n  "wikis": {"hub": {"path": "<HUB>", "description": "Global knowledge base"}},\n  "local_wikis": []\n}\n',
    "_index.md": "# Knowledge hub\n\n| Wiki | Description |\n| --- | --- |\n",
    "log.md": "# Knowledge hub log\n",
}


def hub_status(home: Path) -> Literal["ready", "missing", "invalid"]:
    hub = home_path(HUB_PATH, home)
    if not hub.exists():
        return "missing"
    try:
        registry = json.loads(read_text(hub / "wikis.json"))
        if isinstance(registry, dict) and isinstance(registry.get("wikis"), dict) and (hub / "topics").is_dir() and all((hub / name).is_file() for name in HUB_FILES):
            return "ready"
    except (OSError, ValueError):
        pass
    return "invalid"


def _pointer(path: Path) -> dict[str, object]:
    try:
        data = json.loads(read_text(path))
    except FileNotFoundError:
        return {}
    if not isinstance(data, dict):
        raise TypeError("llm-wiki config must be a JSON object")
    return data


def _hub_value(data: dict[str, object]) -> object:
    return data.get("hub_path") or data.get("resolved_path")


def _matches(value: object, home: Path) -> bool:
    return isinstance(value, str) and same_path(resolve_directory(home_path(value, home)), resolve_directory(home_path(HUB_PATH, home)))


def _write_pointer(path: Path, data: dict[str, object], previous: dict[str, object]) -> None:
    atomic_write_bytes(path, (json.dumps(data, ensure_ascii=False, indent=2) + "\n").encode("utf-8"), verify=lambda: _pointer(path) == previous)


def initialize(home: Path, lines: list[str]) -> None:
    hub = home_path(HUB_PATH, home)
    (hub / "topics").mkdir(parents=True, exist_ok=True)
    for name, content in HUB_FILES.items():
        try:
            with (hub / name).open("x", encoding="utf-8") as stream:
                stream.write(content)
        except FileExistsError:
            pass

    path = home / ".config/llm-wiki/config.json"
    data = _pointer(path)
    value = _hub_value(data)
    if not value:
        _write_pointer(path, {**data, "hub_path": HUB_PATH}, data)
    elif not _matches(value, home):
        lines.append(f"knowledge: keeping the existing llm-wiki hub pointer to {value}")


def purge(home: Path, lines: list[str]) -> None:
    hub = home_path(HUB_PATH, home)
    if is_reparse(hub.parent):
        return  # The handover removes only the .legion link.
    if hub.is_symlink():
        hub.unlink()
    elif is_reparse(hub):
        hub.rmdir()
    elif hub.is_dir():
        shutil.rmtree(hub)
    else:
        hub.unlink(missing_ok=True)

    path = home / ".config/llm-wiki/config.json"
    try:
        data = _pointer(path)
        if _matches(_hub_value(data), home):
            remaining = {key: value for key, value in data.items() if key not in ("hub_path", "resolved_path") or not _matches(value, home)}
            if remaining:
                _write_pointer(path, remaining, data)
            elif _pointer(path) == data:
                path.unlink(missing_ok=True)
    except (OSError, ValueError, TypeError, RuntimeError) as error:
        lines.append(f"knowledge: could not clean up the llm-wiki pointer: {error}")
