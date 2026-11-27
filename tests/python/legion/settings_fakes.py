from pathlib import Path

from legion.core import _settings_io
from legion.core._settings_models import PersonalisationSettings


def save_settings(home: Path, settings: PersonalisationSettings) -> None:
    with _settings_io.writer(home, require_existing=False):
        _settings_io.save_locked(home, settings)
