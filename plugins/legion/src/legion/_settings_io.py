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
    path = settings_path(home)
    if not path.exists():
        raise SettingsError("No legion settings yet; add an agent first.")
    issues = _validate.validate("personalisation", path)
    if issues:
        raise SettingsError("; ".join(issues))
    return PersonalisationSettings.model_validate_json(_validate.read_text(path))


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
    path = settings_path(home)
    temp: Optional[Path] = None
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("wb", dir=path.parent, prefix=f".{path.name}.", suffix=".tmp", delete=False) as file:
            temp = Path(file.name)
            file.write(text.encode("utf-8"))
        temp.replace(path)
    except OSError as error:
        # Windows refuses the replace while another program holds the file (WinError 5 or 32).
        if isinstance(error, PermissionError) or getattr(error, "winerror", None) in (5, 32):
            raise SettingsError("legion settings are in use by another program; close it and run the command again") from None
        raise SettingsError(" ".join(str(error).split())) from None
    finally:
        if temp is not None:
            temp.unlink(missing_ok=True)
