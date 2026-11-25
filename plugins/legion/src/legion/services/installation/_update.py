# Shared by the command and session-start hook; cached checks use only the standard library.
import contextlib
import json
import re
import threading
import time
import uuid
from dataclasses import dataclass
from datetime import UTC, datetime
from pathlib import Path
from typing import Optional

from legion.core._home import legion_home, update_cache_path

SOURCE = "BlackGad/ps-legion-marketplace"
MANIFEST_URL = f"https://raw.githubusercontent.com/{SOURCE}/stable/plugins/legion/plugin.json"
CHECK_SECONDS = 3
FAILURE = "legion: update check failed; could not read the installed or GitHub plugin manifest."
UPDATE_COMMAND = "legion update"
_VERSION = re.compile(r"([0-9]+)(?:\.([0-9]+))?(?:\.([0-9]+))?(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?")


def _version_key(text: str) -> tuple[tuple[int, ...], bool, tuple[tuple[bool, int, str], ...]]:
    match = _VERSION.fullmatch(text)
    if match is None:
        raise ValueError("Invalid semantic version")
    numbers = tuple(int(part or 0) for part in match.groups()[:3])
    if any(number > 2147483647 for number in numbers):
        raise ValueError("Version component exceeds Int32")
    prerelease = match[4]
    labels = []
    for part in prerelease.split(".") if prerelease else []:
        digits = part.isascii() and part.isdigit()
        if digits and len(part) > 1 and part.startswith("0"):
            raise ValueError("Numeric prerelease label has a leading zero")
        # SemanticVersion compares a label numerically only when Int32.TryParse succeeds.
        numeric = digits and int(part) <= 2147483647
        labels.append((not numeric, int(part) if numeric else 0, "" if numeric else part))
    return numbers, prerelease is None, tuple(labels)


# Match PowerShell SemanticVersion ordering; ignore build metadata.
def compare_versions(left: str, right: str) -> int:
    a, b = _version_key(left), _version_key(right)
    return (a > b) - (a < b)


@dataclass(frozen=True)
class UpdateCache:
    source: str
    checked_at: datetime
    available: Optional[str]
    failed: bool

    @classmethod
    def from_json(cls, text: str) -> "UpdateCache":
        data = json.loads(text)
        if not isinstance(data, dict) or not isinstance(data.get("Source"), str) or not isinstance(data.get("CheckedAt"), str):
            raise TypeError("Invalid update cache")
        checked_at = datetime.fromisoformat(data["CheckedAt"])
        if checked_at.tzinfo is None:
            raise ValueError("Cache timestamp needs a time zone")
        failed = data.get("Failed", False)
        available = data.get("Available")
        if not isinstance(failed, bool) or (available is not None and not isinstance(available, str)):
            raise ValueError("Invalid update cache result")
        if not failed:
            if available is None:
                raise ValueError("Cache has no available version")
            _version_key(available)
        return cls(data["Source"], checked_at, available, failed)

    def to_json(self) -> str:
        return json.dumps({"Source": self.source, "CheckedAt": self.checked_at.isoformat(), "Available": self.available, "Failed": self.failed}) + "\n"


@dataclass(frozen=True)
class Update:
    installed: str
    available: str
    newer: bool


def _manifest_version(text: str) -> str:
    manifest = json.loads(text)
    if not isinstance(manifest, dict) or manifest.get("name") != "legion" or not isinstance(manifest.get("version"), str):
        raise ValueError("Invalid legion manifest")
    version = manifest["version"]
    _version_key(version)
    return version


def _download(deadline: float) -> str:
    # A socket timeout does not bound DNS, redirects or a trickling body. A daemon worker also
    # lets the process exit at the deadline; neither interpreter shutdown nor a hook waits for it.
    downloaded: list[str] = []

    def fetch() -> None:
        try:
            from urllib.request import urlopen

            with urlopen(MANIFEST_URL, timeout=max(0.001, deadline - time.monotonic())) as response:
                downloaded.append(response.read().decode("utf-8-sig"))
        except Exception:
            pass  # Network failures have the same best-effort result as the total deadline.

    worker = threading.Thread(target=fetch, daemon=True)
    worker.start()
    worker.join(max(0, deadline - time.monotonic()))
    if worker.is_alive() or not downloaded:
        raise OSError("Marketplace check failed")
    return downloaded[0]


def get_update(plugin_root: Path, home: Optional[Path] = None, *, force: bool = False) -> Optional[Update]:
    deadline = time.monotonic() + CHECK_SECONDS
    try:
        installed = _manifest_version((plugin_root / "plugin.json").read_text(encoding="utf-8-sig"))
        path = update_cache_path(legion_home(home))
        cached = None
        if not force:
            try:
                saved = UpdateCache.from_json(path.read_text(encoding="utf-8-sig"))
                age = (datetime.now(UTC) - saved.checked_at).total_seconds()
                if saved.source == SOURCE and 0 <= age < 86400:
                    cached = saved
            except (OSError, ValueError, TypeError):
                pass
        if cached is None:
            checked_at = datetime.now(UTC)
            try:
                cached = UpdateCache(SOURCE, checked_at, _manifest_version(_download(deadline)), False)
            except (OSError, ValueError, TypeError):
                cached = UpdateCache(SOURCE, checked_at, None, True)
            _save_cache(path, cached)
        if cached.failed or cached.available is None:
            raise OSError("Marketplace check failed")
        return Update(installed, cached.available, compare_versions(cached.available, installed) > 0)
    except (OSError, ValueError, TypeError):
        if force:
            raise
        return None


# Publish the whole record at once, so a session that reads the cache never sees a partial one.
# A cache that cannot be saved must not prevent checks or session starts, nor change their result.
def _save_cache(path: Path, cached: UpdateCache) -> None:
    temporary = path.with_name(f"{path.name}.{uuid.uuid4().hex}.tmp")
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        file = temporary.open("x", encoding="utf-8")
    except OSError:
        return
    try:
        with file:
            file.write(cached.to_json())
        temporary.replace(path)
    except OSError:
        with contextlib.suppress(OSError):
            temporary.unlink()


def check_lines(plugin_root: Path, home: Optional[Path] = None, *, force: bool = False) -> list[str]:
    try:
        result = get_update(plugin_root, home, force=force)
        if result is None:
            return [FAILURE]  # Any failure without --force; only the session-start hook stays silent about it.
        if not result.newer:
            return [f"legion {result.installed} is up to date."]
        return [f"legion installed: {result.installed}", f"legion available: {result.available}", UPDATE_COMMAND]
    except (OSError, ValueError, TypeError):
        return [FAILURE]
