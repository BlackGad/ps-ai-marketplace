# The one reader and writer of the owner's personalisation.json for verbs that change it.

import tempfile
from pathlib import Path
from typing import Optional

from . import _validate
from ._home import settings_path
from ._settings_models import PersonalisationSettings

SCHEMA_URL = "https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/schemas/personalisation.schema.json"
EMPTY = '{"schemaVersion":1,"agents":[],"channels":[]}'


class SettingsError(Exception):
    pass


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
    except OSError as error:
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
    if settings.schema_uri is not None:
        settings = settings.model_copy(update={"schema_uri": SCHEMA_URL})
    issues = _validate.settings_issues(settings)
    if issues:
        raise SettingsError("; ".join(issues))
    text = settings.model_dump_json(by_alias=True, exclude_none=True, indent=2) + "\n"
    path = settings_path(home).resolve()
    temp: Optional[Path] = None
    failure: Optional[OSError] = None
    cleanup_failure: Optional[OSError] = None
    replacing = False
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("wb", dir=path.parent, prefix=f".{path.name}.", suffix=".tmp", delete=False) as file:
            temp = Path(file.name)
            file.write(text.encode("utf-8"))
        replacing = True
        temp.replace(path)
    except OSError as error:
        failure = error
    finally:
        if temp is not None:
            try:
                temp.unlink(missing_ok=True)
            except OSError as error:
                cleanup_failure = error
    if failure is not None and replacing and getattr(failure, "winerror", None) in (5, 32):
        message = "legion settings are in use by another program; close it and run the command again"
    elif failure is not None:
        message = " ".join(str(failure).split())
    else:
        message = ""
    if cleanup_failure is not None:
        detail = " ".join(str(cleanup_failure).split())
        message = f"{message}; cleanup failed: {detail}" if message else f"cleanup failed: {detail}"
    if message:
        raise SettingsError(message) from None
