# Install, update and remove Legion through the tool catalog.

import json
import os
import re
import shutil
import sys
import tempfile
from contextlib import nullcontext
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any
from urllib.request import urlopen

import tomlkit
from tomlkit.items import InlineTable

from . import _footprints, _refresh, _user_path
from ._generated import is_owned
from ._home import bin_folder, footprint_index, full_path, home_path, is_reparse, is_under, owner_path_safe, same_path, tree_has_reparse
from ._plugin import PLUGIN_ROOT
from ._run import run_command


DEFAULT_SOURCE = "BlackGad/ps-legion-marketplace"
# Owns the command and app that install published when no coding CLI exists, so a full uninstall can retire them.
STANDALONE_OWNER = "standalone"


class InstallerError(ValueError):
    pass


@dataclass
class Edit:
    path: Path
    before: bytes
    after: bytes
    names: list[str]


@dataclass
class PurgePlan:
    home: Path
    lines: list[str] = field(default_factory=list)
    paths: list[Path] = field(default_factory=list)
    empty_paths: list[Path] = field(default_factory=list)
    links: list[Path] = field(default_factory=list)
    edits: list[Edit] = field(default_factory=list)
    index_bytes: bytes = b""
    legion: Path | None = None
    manual: bool = False
    user_path_before: str | None = None
    user_path_after: str | None = None
    process_path_before: str | None = None
    process_path_after: str | None = None

    @property
    def has_work(self) -> bool:
        return bool(
            self.paths
            or self.empty_paths
            or self.links
            or self.edits
            or self.legion
            or (self.user_path_after is not None and self.user_path_after != self.user_path_before)
            or (self.process_path_after is not None and self.process_path_after != self.process_path_before)
        )


def _catalog(source: str | Path, ref: str, catalog: dict[str, Any] | None) -> dict[str, Any]:
    if catalog is None:
        if Path(source).is_dir():
            path = Path(source) / "plugins/legion/tools.json"
            catalog = json.loads(path.read_text(encoding="utf-8"))
        elif str(source) == DEFAULT_SOURCE and ref != "main":
            path = PLUGIN_ROOT / "tools.json"
            catalog = json.loads(path.read_text(encoding="utf-8"))
        elif re.fullmatch(r"[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+", str(source)):
            branch = "main" if ref == "main" else "stable"
            url = f"https://raw.githubusercontent.com/{source}/{branch}/plugins/legion/tools.json"
            with urlopen(url, timeout=30) as response:
                catalog = json.loads(response.read())
        else:
            raise InstallerError(f"unsupported marketplace source '{source}'")
    assert catalog is not None
    if catalog.get("schemaVersion") != 1 or not isinstance(catalog.get("tools"), list):
        raise InstallerError("unsupported tools catalog schemaVersion (expected 1)")
    return catalog


def _tool(catalog: dict[str, Any], tool_id: str) -> dict[str, Any]:
    for entry in catalog["tools"]:
        if entry["id"] == tool_id:
            return entry
    raise InstallerError(f"unknown tool '{tool_id}'")


def _config_path(home: Path, value: str) -> Path:
    if value == "~":
        return full_path(home)
    if value.startswith(("~/", "~\\")):
        return full_path(home / value[2:])
    return full_path(Path(value))


def _folders(home: Path, entry: dict[str, Any], selected: Path | None) -> list[Path]:
    if selected is not None:
        return [full_path(selected)]
    folders: list[Path] = []
    settings = home / ".legion/configuration/personalisation.json"
    if settings.is_file():
        for agent in json.loads(settings.read_text(encoding="utf-8-sig")).get("agents", []):
            if agent.get("tool") == entry["id"] and agent.get("configDir"):
                folder = _config_path(home, agent["configDir"])
                if not any(same_path(folder, previous) for previous in folders):
                    folders.append(folder)
    override = os.getenv(entry["configEnv"])
    if override and not same_path(home, Path.home()) and not is_under(_config_path(home, override), home, allow_equal=True):
        override = None
    value = override or entry["plugin"].get("defaultConfigDir")
    if value:
        default = _config_path(home, value)
        if not any(same_path(default, previous) for previous in folders):
            folders.insert(0, default)
    return folders


def _safe_path(root: Path, relative: str, home: Path, allow_file: bool = False, exceptions: tuple[Path, ...] = (), retained: tuple[Path, ...] = ()) -> Path | None:
    # Hand-built, reason: deletion must reject lexical traversal and links before Path.resolve can hide either.
    if not relative or relative.startswith(("/", "\\", "~")) or re.search(r"(^|[/\\])\.{1,2}([/\\]|$)|[:*?]|[/\\]$|[/\\]{2}", relative):
        raise InstallerError("Unsafe relative path: expected an exact path under the root")
    path = full_path(root / relative)
    if not is_under(path, root):
        raise InstallerError("Unsafe path outside the root")
    if not path.exists() and not path.is_symlink():
        return None
    if not allow_file and not path.is_dir():
        return None
    stop = home if is_under(path, home) else Path(path.anchor)
    if not owner_path_safe(path, stop):
        return None
    if path.is_dir():
        for current, dirs, files in os.walk(path, followlinks=False):
            for name in dirs + files:
                child = Path(current) / name
                if child not in exceptions and not any(is_under(child, keep, allow_equal=True) for keep in retained) and is_reparse(child):
                    return None
        if tree_has_reparse(path) and not exceptions and not retained:
            return None
    return path


def _strip_jsonc_comments(text: str) -> str:
    # Hand-built, reason: json in the standard library rejects JSONC; blanking comments keeps every token offset for a byte-preserving edit.
    result = list(text)
    index = 0
    quoted = False
    while index < len(text):
        char = text[index]
        if quoted:
            if char == "\\":
                index += 2
                continue
            if char == '"':
                quoted = False
        elif char == '"':
            quoted = True
        elif text[index : index + 2] == "//":
            end = text.find("\n", index)
            end = len(text) if end < 0 else end
            for place in range(index, end):
                result[place] = " "
            index = end
            continue
        elif text[index : index + 2] == "/*":
            end = text.find("*/", index + 2)
            if end < 0:
                raise ValueError("unclosed JSONC comment")
            end += 2
            for place in range(index, end):
                if result[place] not in "\r\n":
                    result[place] = " "
            index = end
            continue
        index += 1
    if quoted:
        raise ValueError("unclosed JSON string")
    return "".join(result)


# Hand-built, reason: preserve the original BOM and encoding while removing only Legion-owned settings text.
def _decode_text(data: bytes) -> tuple[str, str, bytes]:
    if data.startswith(b"\xff\xfe"):
        encoding, bom = "utf-16-le", data[:2]
    elif data.startswith(b"\xfe\xff"):
        encoding, bom = "utf-16-be", data[:2]
    elif data.startswith(b"\xef\xbb\xbf"):
        encoding, bom = "utf-8", data[:3]
    else:
        encoding, bom = "utf-8", b""
    return data[len(bom) :].decode(encoding), encoding, bom


def _json_edit(path: Path, kind: str) -> Edit | None:
    before = path.read_bytes()
    try:
        text, encoding, bom = _decode_text(before)
        clean = _strip_jsonc_comments(text)
        document = json.loads(clean)
        if not isinstance(document, dict):
            return None
        targets: list[tuple[str | None, dict[str, Any] | None, str]] = (
            [(None, document, "ps-legion-marketplace")]
            if kind == "marketplaces"
            else [
                ("enabledPlugins", document.get("enabledPlugins"), "legion@ps-legion-marketplace"),
                ("extraKnownMarketplaces", document.get("extraKnownMarketplaces"), "ps-legion-marketplace"),
            ]
        )
        if kind == "claude":
            targets.append(("plugins", document.get("plugins"), "legion@ps-legion-marketplace"))
        names: list[str] = []
        changed = text
        for parent_name, parent, key in targets:
            if not isinstance(parent, dict) or key not in parent:
                continue
            # Hand-built, reason: remove only the owned JSONC member's token span, retaining other bytes.
            clean = _strip_jsonc_comments(changed)
            start_of_parent = 0
            end_of_parent = len(clean)
            if parent_name is not None:
                parents = list(re.finditer(re.escape(json.dumps(parent_name)) + r"\s*:\s*", clean))
                if len(parents) != 1:
                    return None
                start_of_parent = parents[0].end()
                _, length = json.JSONDecoder().raw_decode(clean[start_of_parent:])
                end_of_parent = start_of_parent + length
            matches = list(re.finditer(re.escape(json.dumps(key)) + r"\s*:\s*", clean[start_of_parent:end_of_parent]))
            if len(matches) != 1:
                return None
            start = start_of_parent + matches[0].start()
            value_start = start_of_parent + matches[0].end()
            _, length = json.JSONDecoder().raw_decode(clean[value_start:])
            end = value_start + length
            suffix = re.match(r"\s*,", clean[end:])
            if suffix:
                end += suffix.end()
            else:
                prefix = re.search(r",\s*$", clean[:start])
                if prefix:
                    start = prefix.start()
            changed = changed[:start] + changed[end:]
            json.loads(_strip_jsonc_comments(changed))
            names.append(key)
        installed_plugins = document.get("installedPlugins")
        if (
            kind == "copilot"
            and isinstance(installed_plugins, list)
            and any(isinstance(item, dict) and item.get("name") == "legion" and item.get("marketplace") == "ps-legion-marketplace" for item in installed_plugins)
        ):
            changed = _remove_copilot_item(changed, _strip_jsonc_comments(changed))
            names.append("installedPlugins: legion@ps-legion-marketplace")
        if not names:
            return None
        after = bom + changed.encode(encoding)
        return Edit(path, before, after, names)
    except (UnicodeError, ValueError, TypeError):
        return None


def _remove_copilot_item(text: str, clean: str) -> str:
    # Hand-built, reason: a JSONC array item needs its original token span so unrelated comments and formatting survive.
    markers = list(re.finditer(r'"installedPlugins"\s*:\s*\[', clean))
    if len(markers) != 1:
        raise ValueError("ambiguous installedPlugins")
    array_start = markers[0].end() - 1
    _, array_length = json.JSONDecoder().raw_decode(clean[array_start:])
    array_end = array_start + array_length
    matches: list[tuple[int, int]] = []
    for brace in re.finditer(r"\{", clean[array_start + 1 : array_end]):
        start = array_start + 1 + brace.start()
        try:
            item, length = json.JSONDecoder().raw_decode(clean[start:])
        except ValueError:
            continue
        if isinstance(item, dict) and item.get("name") == "legion" and item.get("marketplace") == "ps-legion-marketplace":
            matches.append((start, start + length))
    if len(matches) != 1:
        raise ValueError("ambiguous legion item")
    start, end = matches[0]
    suffix = re.match(r"\s*,", clean[end:array_end])
    if suffix:
        end += suffix.end()
    else:
        prefix = re.search(r",\s*$", clean[array_start:start])
        if prefix:
            start = array_start + prefix.start()
    changed = text[:start] + text[end:]
    json.loads(_strip_jsonc_comments(changed))
    return changed


def _skip_space(text: str, position: int) -> int:
    rest = text[position:]
    return position + len(rest) - len(rest.lstrip())


def _allow_item_spans(clean: str, value: str) -> list[tuple[int, int]]:
    # Other arrays and members can hold the same text, so only items of the one permissions.allow array count.
    decoder = json.JSONDecoder()
    permissions = list(re.finditer(r'"permissions"\s*:\s*', clean))
    if len(permissions) != 1:
        return []
    start_of_object = permissions[0].end()
    _, length = decoder.raw_decode(clean[start_of_object:])
    end_of_object = start_of_object + length
    arrays = list(re.finditer(r'"allow"\s*:\s*\[', clean[start_of_object:end_of_object]))
    if len(arrays) != 1:
        return []
    position = start_of_object + arrays[0].end()
    spans: list[tuple[int, int]] = []
    while True:
        position = _skip_space(clean, position)
        if clean[position] == "]":
            return spans
        item, length = decoder.raw_decode(clean[position:])
        if item == value:
            spans.append((position, position + length))
        position = _skip_space(clean, position + length)
        if clean[position] == ",":
            position += 1


def _allow_edit(path: Path, value: str, data: bytes | None = None) -> Edit | None:
    before = data if data is not None else path.read_bytes()
    try:
        text, encoding, bom = _decode_text(before)
        clean = _strip_jsonc_comments(text)
        document = json.loads(clean)
        allowed = document.get("permissions", {}).get("allow", [])
        if not isinstance(allowed, list) or value not in allowed:
            return None
        # Hand-built, reason: remove the recorded array item by its token span inside permissions.allow only.
        matches = _allow_item_spans(clean, value)
        if len(matches) != 1:
            return None
        start, end = matches[0]
        suffix = re.match(r"\s*,", clean[end:])
        if suffix:
            end += suffix.end()
        else:
            prefix = re.search(r",\s*$", clean[:start])
            if prefix:
                start = prefix.start()
        changed = text[:start] + text[end:]
        # Only the recorded item may differ; anything else means the match was wrong, so leave the file alone.
        expected = json.loads(clean)
        expected["permissions"]["allow"].remove(value)
        if json.loads(_strip_jsonc_comments(changed)) != expected:
            return None
        after = bom + changed.encode(encoding)
        return Edit(path, before, after, [f"permissions.allow: {value}"])
    except (UnicodeError, ValueError, TypeError, AttributeError):
        return None


def remove_owned_edits(home: Path, owners: list[str], lines: list[str]) -> None:
    for entry in _footprints.read(home).entries:
        if entry.kind != "edit" or not entry.owners or not all(any(_footprints.same_owner(owner, selected) for selected in owners) for owner in entry.owners):
            continue
        path = home_path(entry.path, home)
        if not path.is_file():
            continue
        stop = home if is_under(path, home) else Path(path.anchor)
        if not owner_path_safe(path, stop):
            lines.append(f"skip: {path} (linked or could not match safely)")
            continue
        edit = _allow_edit(path, entry.value) if entry.key == "permissions.allow" else None
        if edit is None:
            lines.append(f"skip: {path} (linked or could not match safely)")
            continue
        path.write_bytes(edit.after)
        _footprints.remove_exact(home, "edit", path, entry.key, entry.value)
        lines.extend(f"Remove entry: {path}: {name}" for name in edit.names)


def _toml_edit(path: Path) -> Edit | None:
    before = path.read_bytes()
    try:
        text, encoding, bom = _decode_text(before)
        document = tomlkit.parse(text)
        names: list[str] = []
        for section in ("plugins", "marketplaces", "hooks"):
            if section in document and isinstance(document[section], InlineTable) and "legion" in text:
                return None
        for section, key in (("plugins", "legion@ps-legion-marketplace"), ("marketplaces", "ps-legion-marketplace")):
            if section in document and key in document[section]:
                del document[section][key]
                names.append(f"{section}.{key}")
        if "hooks" in document and "state" in document["hooks"]:
            for key in list(document["hooks"]["state"]):
                if key.startswith("legion@ps-legion-marketplace:"):
                    del document["hooks"]["state"][key]
                    names.append(f"hooks.state.{key}")
        if not names:
            return None
        newline = "\r\n" if b"\r\n" in before else "\n"
        after_text = tomlkit.dumps(document).replace("\r\n", "\n").replace("\n", newline)
        after = bom + after_text.encode(encoding)
        return Edit(path, before, after, names)
    except (UnicodeError, ValueError, TypeError, KeyError):
        return None


def _profile_path(home: Path) -> Path:
    shell = Path(os.getenv("SHELL", "")).name
    return home / (".zshrc" if shell == "zsh" else ".bashrc" if shell == "bash" else ".profile")


def _path_equal(left: str, right: str) -> bool:
    first = os.path.expandvars(left).rstrip("/\\")
    second = os.path.expandvars(right).rstrip("/\\")
    return first.lower() == second.lower() if sys.platform == "win32" else first == second


def ensure_path(home: Path, dry_run: bool, lines: list[str]) -> None:
    bin_path = bin_folder(home)
    if sys.platform == "win32":
        if not dry_run and not any(_path_equal(part, str(bin_path)) for part in os.environ.get("PATH", "").split(os.pathsep)):
            os.environ["PATH"] = str(bin_path) + os.pathsep + os.environ.get("PATH", "")
        saved = _user_path.user_path()
        if _user_path.has_entry(saved, str(bin_path)):
            lines.append("skip: path (already done)")
            return
        lines.append(f"add {bin_path} to your user PATH")
        if not dry_run:
            _footprints.add(home, "path-entry", "user PATH", "legion", value=str(bin_path))
            _user_path.set_user_path((saved.rstrip(";") + ";" if saved else "") + str(bin_path))
        return
    profile = _profile_path(home)
    line = 'export PATH="$HOME/.legion/bin:$PATH"'
    text, encoding, bom = _decode_text(profile.read_bytes()) if profile.is_file() else ("", "utf-8", b"")
    if line in text.splitlines():
        lines.append("skip: shell profile PATH (already done)")
        return
    if not owner_path_safe(profile, home):
        raise InstallerError("Shell profile contains a link; resolve it before writing")
    lines.append(f"add # Added by legion and {line} to {profile}")
    if dry_run:
        return
    separator = "\n" if text and not text.endswith("\n") else ""
    _footprints.add(home, "path-entry", profile, "legion", key=separator, value=line)
    profile.write_bytes(bom + (text + separator + "# Added by legion\n" + line + "\n").encode(encoding))


# Hand-built, reason: only recorded PATH entries may be removed while retaining the order and separators of other entries.
def _path_removal(value: str, separator: str, owned: list[str]) -> tuple[str, list[str]]:
    kept: list[str] = []
    removed: list[str] = []
    for part in value.split(separator):
        (removed if any(_path_equal(part, target) for target in owned) else kept).append(part)
    return separator.join(kept), removed


# Hand-built, reason: the recorded marker and line must be removed without changing the rest of the owner's profile.
def _profile_edit(path: Path, key: str, value: str) -> Edit | None:
    before = path.read_bytes()
    text, encoding, bom = _decode_text(before)
    match = re.search(r"(?m)^# Added by legion\r?\n" + re.escape(value) + r"(?:\r?\n|$)", text)
    if not match:
        return None
    start = match.start()
    if key and match.end() == len(text) and text[:start].endswith(key):
        start -= len(key)
    after = bom + (text[:start] + text[match.end() :]).encode(encoding)
    return Edit(path, before, after, [value])


# Hand-built, reason: only uv's known interpreter link names inside its hashed environments are eligible for unlinking.
def _python_links(home: Path) -> list[Path]:
    python = home / ".legion/python"
    if not python.is_dir() or not owner_path_safe(python, home):
        return []
    links: list[Path] = []
    for environment in python.iterdir():
        if not re.fullmatch(r"env-[0-9a-f]{12}", environment.name) or not environment.is_dir() or not owner_path_safe(environment, home):
            continue
        candidates = [environment / "lib64"]
        bin_dir = environment / "bin"
        if bin_dir.is_dir() and owner_path_safe(bin_dir, home):
            candidates.extend(path for path in bin_dir.iterdir() if re.fullmatch(r"python(?:3(?:\.\d+)?)?", path.name))
        links.extend(path for path in candidates if is_reparse(path))
    return links


def purge_plan(home: Path, catalog: dict[str, Any], config_dir: Path | None = None) -> PurgePlan:
    home = full_path(home)
    plan = PurgePlan(home=home)
    index = footprint_index(home)
    if not owner_path_safe(index, home):
        plan.lines.append("Manual step: legion home contains linked paths; left in place.")
        plan.manual = True
        return plan
    plan.index_bytes = index.read_bytes() if index.is_file() else b""
    records = _footprints.read(home).entries
    app_in_use = any(entry.kind == "app-version" for entry in records)
    path_entries = [entry for entry in records if entry.kind == "path-entry"]
    user_owned = [entry.value for entry in path_entries if entry.path == "user PATH"]
    if user_owned and sys.platform == "win32":
        plan.user_path_before = _user_path.user_path()
        plan.user_path_after, removed = _path_removal(plan.user_path_before, ";", user_owned)
        plan.lines.extend(f"Remove user PATH entry: {part}" for part in removed)
        plan.process_path_before = os.environ.get("PATH", "")
        plan.process_path_after, removed = _path_removal(plan.process_path_before, os.pathsep, user_owned)
        plan.lines.extend(f"Remove process PATH entry: {part}" for part in removed)
    for entry in path_entries:
        if entry.path == "user PATH":
            continue
        path = home_path(entry.path, home)
        if path.is_file() and owner_path_safe(path, home):
            edit = _profile_edit(path, entry.key, entry.value)
            if edit:
                plan.edits.append(edit)
            else:
                plan.lines.append(f"Manual step: {path} (linked or could not match safely)")
                plan.manual = True
    seen: set[Path] = set()
    for entry in catalog["tools"]:
        folders = _folders(home, entry, None)
        if config_dir is not None:
            folders.append(full_path(config_dir))
        default = entry["plugin"].get("defaultConfigDir")
        if default:
            folders.append(_config_path(home, default))
        for folder in folders:
            for relative in [entry["plugin"].get("cacheDir"), *((entry["plugin"].get("purge") or {}).get("paths") or [])]:
                if not relative:
                    continue
                path = _safe_path(folder, relative, home, allow_file=True)
                if path and path not in seen:
                    plan.paths.append(path)
                    seen.add(path)
                elif (folder / relative).exists() and not path:
                    plan.lines.append(f"Manual step: {folder / relative} (linked path; left in place)")
                    plan.manual = True
            for setting in (entry["plugin"].get("purge") or {}).get("settings", []):
                path = _safe_path(folder, setting["path"], home, allow_file=True)
                if path is None or not path.is_file() or path in seen:
                    continue
                edit = _toml_edit(path) if setting["kind"] == "toml" else _json_edit(path, setting["kind"])
                if edit:
                    plan.edits.append(edit)
                    seen.add(path)
                elif b"legion" in path.read_bytes():
                    plan.lines.append(f"Manual step: {path} (remove its legion entries; could not match them safely)")
                    plan.manual = True
            for relative in (entry["plugin"].get("purge") or {}).get("emptyDirs") or []:
                path = _safe_path(folder, relative, home)
                if path and path not in seen and all(child in plan.paths for child in path.iterdir()):
                    plan.empty_paths.append(path)
                    seen.add(path)
    for record in records:
        if record.kind != "edit" or record.key != "permissions.allow":
            continue
        path = home_path(record.path, home)
        if not path.is_file():
            continue
        stop = home if is_under(path, home) else Path(path.anchor)
        if not owner_path_safe(path, stop):
            plan.lines.append(f"Manual step: {path} (linked or could not match safely)")
            plan.manual = True
            continue
        existing = next((edit for edit in plan.edits if edit.path == path), None)
        data = existing.after if existing else path.read_bytes()
        if record.value.encode("utf-8") not in data and record.value.encode("utf-16-le") not in data:
            continue
        edit = _allow_edit(path, record.value, data)
        if edit:
            if existing:
                existing.after = edit.after
                existing.names.extend(edit.names)
            else:
                plan.edits.append(edit)
        else:
            plan.lines.append(f"Manual step: {path} (remove its legion entries; could not match them safely)")
            plan.manual = True
    plan.links = [] if app_in_use else _python_links(home)
    for record in records:
        if record.kind == "link" and _footprints.is_safe(record, home):
            path = home_path(record.path, home)
            if is_reparse(path):
                plan.links.append(path)
    retained = (home / ".legion/app", home / ".legion/python") if app_in_use else ()
    legion = _safe_path(home, ".legion", home, exceptions=tuple(plan.links), retained=retained)
    kept = (*retained, index, Path(str(index) + ".lock"))
    has_home_work = False
    if legion:
        has_home_work = not app_in_use or any(item not in kept for item in legion.iterdir()) or any(entry.kind not in ("app", "app-version") for entry in records)
    if legion and has_home_work:
        plan.legion = legion
    elif legion is None and (home / ".legion").exists():
        plan.lines.append("Manual step: legion home contains linked paths; left in place.")
        plan.manual = True
    for edit in plan.edits:
        for name in edit.names:
            plan.lines.append(f"Remove entry: {edit.path}: {name}")
    plan.lines.extend(f"Remove link: {path}" for path in plan.links)
    for path in [*plan.paths, *plan.empty_paths, *([plan.legion] if plan.legion else [])]:
        if path.is_dir():
            count = sum(1 for child in path.rglob("*") if child.is_file())
            last = " (last: all settings, notes, account folders, logins and launchers)" if path == plan.legion and not app_in_use else ""
            keeping = ", keeping app and python" if path == plan.legion and app_in_use else ""
            empty = " (if empty)" if path in plan.empty_paths else ""
            plan.lines.append(f"Remove folder: {path} ({count} files){empty}{last}{keeping}")
        else:
            plan.lines.append(f"Remove file: {path}")
    if not plan.lines:
        plan.lines.append("skip: purge (already done)")
    return plan


def apply_purge(plan: PurgePlan) -> None:
    # The lock lives under .legion; keep its file until every protected deletion has finished.
    if plan.legion is None and not plan.edits and not plan.paths and not plan.empty_paths and not plan.links and plan.user_path_before is None:
        return
    with _footprints.lock(plan.home) if plan.legion else nullcontext():
        index = footprint_index(plan.home)
        if (index.read_bytes() if index.is_file() else b"") != plan.index_bytes:
            raise InstallerError("Legion records changed after preview; run purge again.")
        if plan.user_path_after is not None and _user_path.user_path() != plan.user_path_before:
            raise InstallerError("User PATH changed after preview; run purge again.")
        if plan.process_path_after is not None and os.environ.get("PATH", "") != plan.process_path_before:
            raise InstallerError("Process PATH changed after preview; run purge again.")
        for edit in plan.edits:
            stop = plan.home if is_under(edit.path, plan.home) else Path(edit.path.anchor)
            if not owner_path_safe(edit.path, stop) or edit.path.read_bytes() != edit.before:
                raise InstallerError("Settings changed after preview; run again.")
        for edit in plan.edits:
            edit.path.write_bytes(edit.after)
        if plan.user_path_after is not None and plan.user_path_after != plan.user_path_before:
            _user_path.set_user_path(plan.user_path_after)
        if plan.process_path_after is not None and plan.process_path_after != plan.process_path_before:
            os.environ["PATH"] = plan.process_path_after
        for path in plan.paths:
            if not path.exists():
                continue
            root = next((parent for parent in path.parents if parent == plan.home), path.parent)
            if _safe_path(root, str(path.relative_to(root)), plan.home, allow_file=True) == path:
                shutil.rmtree(path) if path.is_dir() else path.unlink()
        for path in plan.empty_paths:
            if path.is_dir() and not any(path.iterdir()):
                path.rmdir()
        for path in plan.links:
            record = next((entry for entry in _footprints.read(plan.home).entries if entry.kind == "link" and same_path(home_path(entry.path, plan.home), path)), None)
            if (record and _footprints.is_safe(record, plan.home)) or path in _python_links(plan.home):
                path.unlink()
        if plan.legion:
            app_records = [entry for entry in _footprints.read(plan.home).entries if entry.kind in ("app", "app-version")]
            app_in_use = any(entry.kind == "app-version" for entry in app_records)
            retained = (plan.home / ".legion/app", plan.home / ".legion/python") if app_in_use else ()
            if _safe_path(plan.home, ".legion", plan.home, retained=retained) != plan.legion:
                raise InstallerError("Legion home changed after preview; run purge again.")
            lock_file = Path(str(index) + ".lock")
            windows = sys.platform == "win32"
            for item in plan.legion.iterdir():
                if item == lock_file or (app_in_use and item in retained) or (app_in_use and item == index):
                    continue
                shutil.rmtree(item) if item.is_dir() else item.unlink()
            if app_in_use:
                _footprints._write(plan.home, _footprints.FootprintIndex.model_validate({"schemaVersion": 1, "entries": app_records}))
            elif not windows and [item.name for item in plan.legion.iterdir()] == [lock_file.name]:
                # Unix keeps the lock file on release. Unlinking it while we hold it is safe: a waiter that
                # already opened it sees no link left and retries. Windows removes it itself on release.
                lock_file.unlink()
    if plan.legion and plan.legion.is_dir():
        try:
            plan.legion.rmdir()
        except OSError:
            # A waiting writer can recreate its lock or records now; keep them. Anything else is a real error.
            if plan.legion.is_dir() and not any(plan.legion.iterdir()):
                raise


def _execute(entry: dict[str, Any], arguments: list[str], folder: Path, listing: bool = False) -> str:
    env = dict(os.environ)
    env[entry["configEnv"]] = str(folder)
    if listing:
        env.update(entry["plugin"].get("listingEnv") or {})
    command = shutil.which(entry["command"]) or entry["command"]
    result = run_command(command, arguments, env=env, cwd=Path(tempfile.gettempdir()))
    if result.exit_code:
        detail = result.error.strip() or result.output.strip()
        raise InstallerError(f"{entry['command']} {'listing ' if listing else ''}exited {result.exit_code}" + (f"\n{detail}" if detail else ""))
    return result.output


def _listing(entry: dict[str, Any], folder: Path, kind: str) -> str:
    if not folder.is_dir():
        return ""
    name = "marketplaceList" if kind == "marketplace" else "list"
    return _execute(entry, entry["plugin"][name], folder, listing=True)


def _marketplace(entry: dict[str, Any], folder: Path, require_root: bool = False) -> bool:
    output = _listing(entry, folder, "marketplace")
    if not output:
        return False
    try:
        data = json.loads(output)
        listing = entry["plugin"]["marketplaceListing"]
        if "collectionField" in listing:
            data = data[listing["collectionField"]]
        for item in data:
            if item.get(listing["nameField"]) == "ps-legion-marketplace":
                if require_root and "rootField" in listing:
                    root = item.get(listing["rootField"])
                    return isinstance(root, str) and bool(root) and Path(root).is_dir()
                return True
        return False
    except (ValueError, TypeError, KeyError) as error:
        raise InstallerError(f"{entry['id']} marketplace listing returned invalid JSON") from error


# Hand-built, reason: the three CLIs expose different listing formats described by tools.json.
def _plugin_state(entry: dict[str, Any], folder: Path) -> tuple[bool, bool, list[Path], str]:
    output = _listing(entry, folder, "plugin")
    if not output:
        return False, False, [], ""
    listing = entry["plugin"]["listing"]
    paths: list[Path] = []
    version = ""
    if listing["format"] == "json":
        try:
            items = json.loads(output)
        except ValueError as error:
            raise InstallerError(f"{entry['id']} plugin listing returned invalid JSON") from error
        matches = [item for item in items if item.get(listing["idField"]) == "legion@ps-legion-marketplace" and isinstance(item.get(listing["enabledField"]), bool)]
        for item in matches:
            if item.get("installPath"):
                paths.append(Path(item["installPath"]))
            version = item.get("version") or version
        return bool(matches), any(item[listing["enabledField"]] for item in matches), paths, version
    lines = [line for line in output.splitlines() if re.search(r"legion@ps-legion-marketplace(?![\w-])", line) and "not installed" not in line]
    for line in lines:
        match = re.search(r"\b(v?\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?)\b", line)
        if match:
            version = match[1].removeprefix("v")
        match = re.search(r"\s((?:[A-Za-z]:[/\\]|/).+?)\s*$", line)
        if match:
            paths.append(Path(match[1]))
    return bool(lines), any(not re.search(listing["rejectPattern"], line) for line in lines), paths, version


def _plugin_root(entry: dict[str, Any], folder: Path) -> Path | None:
    listed, _, paths, version = _plugin_state(entry, folder)
    if not listed:
        return None
    if entry["id"] == "copilot":
        is_legion = False
        for line in _listing(entry, folder, "plugin").splitlines():
            if not line[:1].isspace():
                is_legion = bool(re.search(r"legion@ps-legion-marketplace(?![\w-])", line))
            marketplace = re.match(r"^\s+from (.+?)\s*$", line) if is_legion else None
            if marketplace is None:
                continue
            try:
                root = Path(marketplace[1])
                data = json.loads((root / ".claude-plugin/marketplace.json").read_text(encoding="utf-8-sig"))
                for plugin in data["plugins"]:
                    if plugin.get("name") == "legion" and isinstance(plugin.get("source"), str):
                        paths.append(root / plugin["source"])
            except (OSError, ValueError, KeyError):
                continue
    if not paths and entry["plugin"].get("installedRoot"):
        root = folder / entry["plugin"]["installedRoot"]
        if root.is_dir():
            paths = [path.parent for path in root.rglob("plugin.json") if path.parent.name not in (".claude-plugin", ".codex-plugin")]
    roots = []
    for path in set(paths):
        try:
            manifest = json.loads((path / "plugin.json").read_text(encoding="utf-8-sig"))
            if manifest.get("name") == "legion" and (not version or manifest.get("version") == version):
                roots.append(path)
        except (OSError, ValueError):
            continue
    if len(roots) != 1:
        raise InstallerError(f"{entry['id']} installed legion folder could not be identified uniquely.")
    return roots[0]


def _owner(entry: dict[str, Any], folder: Path) -> str:
    return _footprints.target_owner(entry["id"], folder)


def _command_names() -> list[str]:
    return ["legion", "legion.cmd"] if sys.platform == "win32" else ["legion"]


def _record_commands(home: Path, owner: str) -> None:
    for name in _command_names():
        _footprints.add(home, "file", bin_folder(home) / name, owner)
    _footprints.add(home, "app", home / ".legion/app", owner)


# Older releases published the command without an owner. Returns its generated files so a full uninstall can retire them.
def _unrecorded_commands(home: Path) -> list[Path]:
    records = _footprints.read(home).entries
    if not any(entry.kind == "app-version" for entry in records) or any(entry.kind == "app" for entry in records):
        return []
    recorded = [home_path(entry.path, home) for entry in records if entry.kind == "file"]
    commands = [bin_folder(home) / name for name in _command_names()]
    return [path for path in commands if path.is_file() and is_owned(path, "owner command") and not any(same_path(path, item) for item in recorded)]


def _refresh_target(entry: dict[str, Any], folder: Path, home: Path, root: Path) -> list[str]:
    _record_commands(home, _owner(entry, folder))
    return _refresh.refresh(home, source=root)


def _command_line(entry: dict[str, Any], arguments: list[str], folder: Path) -> str:
    return f"{entry['configEnv']}={folder} {entry['command']} {' '.join(arguments)}"


def _step(entry: dict[str, Any], arguments: list[str], folder: Path, dry_run: bool, lines: list[str]) -> None:
    line = _command_line(entry, arguments, folder)
    if dry_run:
        lines.append(line)
    else:
        output = _execute(entry, arguments, folder)
        lines.extend(output.splitlines())


def _install_steps(entry: dict[str, Any], folder: Path, source: str | Path, ref: str, dry_run: bool, lines: list[str]) -> None:
    plugin = entry["plugin"]
    branch = "main" if ref == "main" else "stable"
    local = Path(source).is_dir()
    if local:
        source = Path(source).resolve().as_posix()
    template = plugin["marketplaceAdd"] if local else plugin["marketplaceAddRef"]
    marketplace_add = [word.replace("{source}", str(source)).replace("{ref}", branch) for word in template]
    installed = _marketplace(entry, folder)
    listed, enabled, _, _ = _plugin_state(entry, folder)
    if installed and enabled and _marketplace(entry, folder, require_root=True):
        lines.extend([f"skip: {entry['command']} {' '.join(marketplace_add)} (already done)", f"skip: {entry['command']} {' '.join(plugin['install'])} (already done)"])
        return
    if not installed:
        _step(entry, marketplace_add, folder, dry_run, lines)
    if plugin["marketplaceUpdate"]:
        _step(entry, plugin["marketplaceUpdate"], folder, dry_run, lines)
    if not installed or not listed or not enabled:
        _step(entry, plugin["install"], folder, dry_run, lines)


# One row per tool and folder, so a long install ends with what happened where.
# Hand-built, reason: a three-column text table is plain str.ljust; no table library is pinned.
def _results_table(rows: list[tuple[str, str, str]]) -> list[str]:
    table = [("Tool", "Folder", "Result"), *rows]
    widths = [max(len(row[column]) for row in table) for column in (0, 1)]
    return ["Results:", *(f"{tool.ljust(widths[0])}  {folder.ljust(widths[1])}  {result}".rstrip() for tool, folder, result in table)]


def install(
    home: Path,
    tools: list[str] | None = None,
    source: str | Path = DEFAULT_SOURCE,
    ref: str = "release",
    config_dir: Path | None = None,
    dry_run: bool = False,
    yes: bool = False,
    update: bool = False,
    uninstall: bool = False,
    purge: bool = False,
    catalog: dict[str, Any] | None = None,
) -> list[str]:
    if update and uninstall:
        raise InstallerError("Choose either --update or --uninstall.")
    if purge and not uninstall:
        raise InstallerError("--purge requires --uninstall.")
    home = full_path(home)
    catalog = _catalog(source, ref, catalog)
    selected = list(dict.fromkeys(part for word in (tools or []) for part in word.split(",") if part))
    if not selected:
        selected = [entry["id"] for entry in catalog["tools"] if uninstall or shutil.which(entry["command"])]
    for tool_id in selected:
        _tool(catalog, tool_id)
    lines: list[str] = []
    if uninstall:
        _uninstall(home, catalog, selected, config_dir, dry_run, yes, lines)
        lines.extend(_kept_lines(home, catalog, config_dir))
        if purge and (dry_run or yes or not any(line == "Uninstall cancelled." for line in lines)):
            plan = purge_plan(home, catalog, config_dir)
            lines.extend(plan.lines)
            if not dry_run and plan.has_work:
                if yes or _confirm("Purge legion settings, notes, account folders and logins listed above? [y/N]", lines):
                    apply_purge(plan)
                    lines.append("Purge needs the manual steps above." if plan.manual else "done: purge")
                else:
                    lines.append("Purge cancelled.")
            elif plan.manual:
                lines.append("Purge needs the manual steps above.")
        return lines
    if not selected:
        lines.extend(["No coding CLI is installed. Run legion setup to install one.", *(entry.get("installHint", "") for entry in catalog["tools"])])
        if not dry_run and not (yes or _confirm("Install the legion command and add ~/.legion/bin to your PATH? [y/N]", lines)):
            return [*lines, "Nothing changed. Run again with --yes to apply."]
        ensure_path(home, dry_run, lines)
        if not dry_run:
            _record_commands(home, STANDALONE_OWNER)
            lines.extend(_refresh.refresh(home, source=PLUGIN_ROOT))
        return lines
    if update:
        targets = [(entry, folder) for tool_id in selected for entry in [_tool(catalog, tool_id)] for folder in _folders(home, entry, config_dir) if shutil.which(entry["command"])]
        for entry, folder in targets:
            root = _plugin_root(entry, folder)
            version = json.loads((root / "plugin.json").read_text(encoding="utf-8"))["version"] if root else "not installed"
            lines.append(f"Update legion for {entry['id']} in {folder} ({version})")
        if targets and not dry_run and not (yes or _confirm("Update legion? [y/N]", lines)):
            return [*lines, "Nothing changed. Run again with --yes to apply."]
        rows: list[tuple[str, str, str]] = []
        for entry, folder in targets:
            before = _plugin_root(entry, folder)
            before_version = json.loads((before / "plugin.json").read_text(encoding="utf-8"))["version"] if before else "not installed"
            if before:
                for arguments in (entry["plugin"]["marketplaceUpdate"], entry["plugin"]["update"]):
                    if arguments:
                        _step(entry, arguments, folder, dry_run, lines)
            else:
                _install_steps(entry, folder, source, ref, dry_run, lines)
            if not dry_run:
                after = _plugin_root(entry, folder)
                if after is None:
                    raise InstallerError(f"{entry['id']} legion is absent from the post-update listing; generated artifacts were not refreshed.")
                try:
                    lines.extend(_refresh_target(entry, folder, home, after))
                except Exception as error:
                    lines.append(f"commands not refreshed for {entry['id']} in {folder}: {error}; run legion setup")
                    rows.append((entry["id"], str(folder), f"commands not refreshed: {error}"))
                    continue
                after_version = json.loads((after / "plugin.json").read_text(encoding="utf-8"))["version"]
                lines.append(f"legion {before_version} -> {after_version}" if before_version != after_version else f"skip: legion {after_version} (already up to date)")
                rows.append((entry["id"], str(folder), f"{before_version} -> {after_version}" if before_version != after_version else f"already up to date ({after_version})"))
        if targets and not dry_run:
            lines.extend(_results_table(rows))
            lines.append("done: restart your sessions; run legion in the repository")
        return lines
    lines.append(f"Install legion for {', '.join(selected)}")
    path_description = "user PATH" if sys.platform == "win32" else "shell profile PATH"
    if not dry_run and not (yes or _confirm(f"Install legion for {', '.join(selected)} now, and add ~/.legion/bin to your {path_description}? [y/N]", lines)):
        return [*lines, "Nothing changed. Run again with --yes to apply."]
    ensure_path(home, dry_run, lines)
    installed_version = ""
    rows = []
    for tool_id in selected:
        entry = _tool(catalog, tool_id)
        if not shutil.which(entry["command"]):
            lines.append(f"skip: {tool_id} (not installed)")
            rows.append((tool_id, "-", "skipped (not installed)"))
            continue
        for folder in _folders(home, entry, config_dir):
            if not dry_run:
                folder.mkdir(parents=True, exist_ok=True)
            _install_steps(entry, folder, source, ref, dry_run, lines)
            if not dry_run:
                try:
                    root = _plugin_root(entry, folder)
                except Exception:
                    root = None
                if root:
                    try:
                        lines.extend(_refresh_target(entry, folder, home, root))
                        installed_version = json.loads((root / "plugin.json").read_text(encoding="utf-8"))["version"]
                        rows.append((tool_id, str(folder), f"installed legion {installed_version}"))
                    except Exception as error:
                        lines.append(f"commands not refreshed for {tool_id} in {folder}: {error}; run legion setup")
                        rows.append((tool_id, str(folder), f"commands not refreshed: {error}"))
                else:
                    lines.append(f"commands not refreshed for {tool_id} in {folder}; run legion setup")
                    rows.append((tool_id, str(folder), "commands not refreshed"))
        if entry["hooks"].get("hint"):
            lines.append(entry["hooks"]["hint"])
    if not dry_run:
        lines.extend(_results_table(rows))
    if installed_version and not dry_run:
        lines.append(f"installed: legion {installed_version} ({ref})")
        lines.append("next: legion add claude (or legion in a repository)")
    return lines


def _kept_lines(home: Path, catalog: dict[str, Any], config_dir: Path | None) -> list[str]:
    lines: list[str] = []
    for name, label in (("configuration", "settings and notes"), ("agents", "account folders and logins"), ("bin", "account launchers")):
        path = home / ".legion" / name
        if path.exists():
            lines.append(f"Kept {label}: {path}")
    seen: set[Path] = set()
    for entry in catalog["tools"]:
        for folder in _folders(home, entry, config_dir):
            if folder.is_dir() and folder not in seen:
                lines.append(f"Kept config folder and login: {folder}")
                seen.add(folder)
    lines.append("Kept repositories at their existing paths and CLIs at their existing install locations.")
    lines.append("You can delete kept data by hand if you no longer need it.")
    return lines


def _confirm(question: str, lines: list[str]) -> bool:
    for line in lines:
        print(line)
    lines.clear()
    try:
        return input(question + " ").strip().lower() in ("y", "yes")
    except EOFError:
        return False


def preview_owned(home: Path, owners: list[str]) -> list[str]:
    records = _footprints.read(home).entries
    lines: list[str] = []
    for entry in records:
        if entry.kind not in ("file", "folder", "edit") or not entry.owners or not all(any(_footprints.same_owner(owner, selected) for selected in owners) for owner in entry.owners):
            continue
        path = home_path(entry.path, home)
        if entry.kind == "edit":
            stop = home if is_under(path, home) else Path(path.anchor)
            edit = _allow_edit(path, entry.value) if owner_path_safe(path, stop) and path.is_file() and entry.key == "permissions.allow" else None
            if edit:
                lines.extend(f"Remove entry: {path}: {name}" for name in edit.names)
        elif path.exists() and _footprints.is_safe(entry, home):
            lines.append(f"Remove {entry.kind}: {path}")
    return lines


def _uninstall(home: Path, catalog: dict[str, Any], selected: list[str], config_dir: Path | None, dry_run: bool, yes: bool, lines: list[str]) -> None:
    targets: list[tuple[dict[str, Any], Path, list[tuple[str, list[str]]], Path | None]] = []
    owners: list[str] = []
    for tool_id in selected:
        entry = _tool(catalog, tool_id)
        if not shutil.which(entry["command"]):
            lines.append(f"skip: {tool_id} (not installed)")
            continue
        folders = _folders(home, entry, config_dir)
        if config_dir is None:
            for record in _footprints.read(home).entries:
                for owner in record.owners:
                    if owner.startswith(f"{tool_id}:"):
                        folder = Path(owner[len(tool_id) + 1 :])
                        if not folder.is_absolute() or ".." in folder.parts:
                            raise InstallerError("Invalid target owner in footprint record")
                        if folder not in folders:
                            folders.append(folder)
        for folder in folders:
            owner = _owner(entry, folder)
            if any(_footprints.same_owner(owner, selected_owner) for selected_owner in owners):
                continue
            owners.append(owner)
            if not folder.is_dir():
                lines.append(f"skip: {tool_id} plugin in {folder} (not installed)")
                continue
            steps = []
            listed, _, _, _ = _plugin_state(entry, folder)
            if listed:
                steps.append(("plugin", entry["plugin"]["uninstall"]))
            else:
                lines.append(f"skip: {tool_id} plugin in {folder} (not installed)")
            if _marketplace(entry, folder):
                steps.append(("marketplace", entry["plugin"]["marketplaceRemove"]))
            else:
                lines.append(f"skip: {tool_id} marketplace in {folder} (not installed)")
            cache = None
            if entry["plugin"].get("cacheDir"):
                cache = _safe_path(folder, entry["plugin"]["cacheDir"], home)
            if not steps and cache is None:
                continue
            targets.append((entry, folder, steps, cache))
            lines.append(f"Target: {tool_id} in {folder}")
            lines.extend(_command_line(entry, arguments, folder) for _, arguments in steps)
            if cache:
                lines.append(f"Remove cache folder: {cache}")
    adopted: list[Path] = []
    if {entry["id"] for entry in catalog["tools"]} <= set(selected):
        # A full uninstall also retires the command that install published without a coding CLI.
        owners.append(STANDALONE_OWNER)
        adopted = _unrecorded_commands(home)
        if adopted and not dry_run:
            for path in adopted:
                _footprints.add(home, "file", path, STANDALONE_OWNER)
            _footprints.add(home, "app", home / ".legion/app", STANDALONE_OWNER)
        elif adopted:
            lines.extend(f"Remove file: {path}" for path in adopted)
    recorded = [record for record in _footprints.read(home).entries if not record.owners or any(_footprints.same_owner(owner, selected_owner) for owner in record.owners for selected_owner in owners)]
    lines.extend(preview_owned(home, owners))
    lines.append("Channel plugins and their state remain in place.")
    if not targets and not recorded and not adopted:
        lines.append("Nothing to uninstall.")
        return
    if dry_run:
        return
    if not (yes or _confirm("Uninstall legion from these targets? [y/N]", lines)):
        lines.append("Uninstall cancelled.")
        return
    for entry, folder, steps, cache in targets:
        for kind, arguments in steps:
            listed = _plugin_state(entry, folder)[0] if kind == "plugin" else _marketplace(entry, folder)
            if listed:
                _step(entry, arguments, folder, False, lines)
        if cache:
            if _plugin_state(entry, folder)[0]:
                raise InstallerError(f"{entry['id']} plugin is still listed; cache kept.")
            if _safe_path(folder, entry["plugin"]["cacheDir"], home) == cache:
                shutil.rmtree(cache)
    remove_owned_edits(home, owners, lines)
    lines.extend(_footprints.remove_owner(home, owners))
    if recorded:
        refresh_remaining(home, catalog, lines)


def refresh_remaining(home: Path, catalog: dict[str, Any], lines: list[str]) -> None:
    commands = [entry for entry in _footprints.read(home).entries if entry.kind == "file" and entry.path == "~/.legion/bin/legion"]
    target_owners = [owner for entry in commands for owner in entry.owners if owner != STANDALONE_OWNER]
    if not target_owners:
        return
    owner = target_owners[0]
    if ":" not in owner:
        raise InstallerError("Invalid target owner in footprint record")
    tool_id, folder = owner.split(":", 1)
    entry = _tool(catalog, tool_id)
    try:
        root = _plugin_root(entry, Path(folder))
        if root is not None:
            lines.extend(_refresh_target(entry, Path(folder), home, root))
    except Exception:
        lines.append("Kept command: ~/.legion/bin/legion (run legion setup)")
