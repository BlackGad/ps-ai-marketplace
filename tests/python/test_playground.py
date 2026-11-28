import importlib.util
from pathlib import Path

import pytest


PLAY = Path(__file__).resolve().parents[1] / "playground" / "play.py"
SPEC = importlib.util.spec_from_file_location("playground_play", PLAY)
assert SPEC
assert SPEC.loader
play = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(play)

INTENT = """---
covers: plugins/legion/src/legion/services/lifecycle/*, install.sh
os: linux
budget: 15
---
Goal: install.
"""


def write(folder: Path, name: str, text: str) -> None:
    (folder / name).write_text(text, encoding="utf-8")


def test_parse_intent_reads_front_matter_and_body() -> None:
    intent = play.parse_intent("install", INTENT)
    assert intent.name == "install"
    assert intent.covers == ["plugins/legion/src/legion/services/lifecycle/*", "install.sh"]
    assert intent.os == "linux"
    assert intent.budget == 15
    assert intent.text.strip() == "Goal: install."


def test_parse_intent_rejects_missing_front_matter() -> None:
    with pytest.raises(ValueError, match="front matter"):
        play.parse_intent("bad", "Goal only.")


def test_parse_intent_rejects_unknown_os() -> None:
    with pytest.raises(ValueError, match="os"):
        play.parse_intent("bad", INTENT.replace("os: linux", "os: beos"))


def test_select_lists_only_playgrounds_whose_paths_changed(tmp_path: Path) -> None:
    write(tmp_path, "a.md", INTENT)
    write(tmp_path, "b.md", INTENT.replace("covers: plugins/legion/src/legion/services/lifecycle/*, install.sh", "covers: install.ps1"))
    names = [intent.name for intent in play.select(["plugins/legion/src/legion/services/lifecycle/apply.py"], tmp_path)]
    assert names == ["a"]
    assert play.select(["README.md"], tmp_path) == []


def test_shipped_intents_parse_and_cover_something() -> None:
    intents = play.load_intents(PLAY.parent / "intents")
    assert len(intents) >= 3
    assert all(intent.covers and intent.budget > 0 for intent in intents)
