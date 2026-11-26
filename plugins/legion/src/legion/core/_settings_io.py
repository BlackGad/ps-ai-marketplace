# The one reader and writer of the owner's personalisation.json for verbs that change it.

from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

from filelock import FileLock, Timeout

from legion.core import _validate
from legion.core._atomic_write import AtomicWriteError, atomic_write_bytes
from legion.core._home import settings_path
from legion.core._settings_models import PersonalisationSettings

SCHEMA_URL = "https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/schemas/personalisation.schema.json"
EMPTY = '{"schemaVersion":1,"agents":[],"channels":[]}'


class SettingsError(Exception):
    pass


@contextmanager
def writer(home: Path, *, require_existing: bool = True) -> Iterator[None]:
    try:
        path = settings_path(home).resolve()
        if require_existing and not path.is_file():
            raise SettingsError("No legion settings yet; add an agent first.")
        path.parent.mkdir(parents=True, exist_ok=True)
        with FileLock(str(path) + ".lock", timeout=30):
            yield
    except Timeout:
        raise SettingsError("legion settings are busy; another legion command is still running") from None
    except OSError as error:
        raise SettingsError(" ".join(str(error).split())) from None


def load(home: Path) -> PersonalisationSettings:
    return _load(home, references=True)


def load_unchecked(home: Path) -> PersonalisationSettings:
    # Removal can repair a stale channel; save validates the complete remaining settings.
    return _load(home, references=False)


def _load(home: Path, *, references: bool) -> PersonalisationSettings:
    path = settings_path(home)
    if not path.exists():
        raise SettingsError("No legion settings yet; add an agent first.")
    try:
        text = _validate.read_text(path)
    except (OSError, ValueError) as error:
        raise SettingsError(" ".join(str(error).split())) from None
    issues = _validate.validate_text("personalisation", text, references=references)
    if issues:
        raise SettingsError("; ".join(issues))
    return PersonalisationSettings.model_validate_json(text)


# Adding the first account starts from empty settings.
def load_or_empty(home: Path) -> PersonalisationSettings:
    if not settings_path(home).exists():
        return PersonalisationSettings.model_validate_json(EMPTY)
    return load(home)


# Checks first, then a temp file beside the settings replaces them, so a failed write leaves the old file.
def save(home: Path, settings: PersonalisationSettings) -> None:
    with writer(home, require_existing=False):
        save_locked(home, settings)


def save_locked(home: Path, settings: PersonalisationSettings) -> None:
    if settings.schema_uri is not None:
        settings = settings.model_copy(update={"schema_uri": SCHEMA_URL})
    issues = _validate.settings_issues(settings)
    if issues:
        raise SettingsError("; ".join(issues))
    text = settings.model_dump_json(by_alias=True, exclude_none=True, indent=2) + "\n"
    path = settings_path(home).resolve()
    try:
        atomic_write_bytes(path, text.encode("utf-8"), keep_mode=False)
    except AtomicWriteError as error:
        if error.replacing and getattr(error.failure, "winerror", None) in (5, 32):
            message = "legion settings are in use by another program; close it and run the command again"
        else:
            message = " ".join(str(error.failure).split())
        if error.cleanup_failure is not None:
            detail = " ".join(str(error.cleanup_failure).split())
            message = f"{message}; cleanup failed: {detail}" if message else f"cleanup failed: {detail}"
        raise SettingsError(message) from None
