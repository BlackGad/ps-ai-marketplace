import json
import re
from pathlib import Path
from typing import Any

import pytest
from conftest import REPO

PLUGIN = REPO / "plugins/legion"
SKILLS = PLUGIN / "skills"


def read_json(path: Path) -> Any:
    return json.loads(path.read_text(encoding="utf-8"))


def test_marketplace_entries() -> None:
    claude = read_json(REPO / ".claude-plugin/marketplace.json")
    codex = read_json(REPO / ".agents/plugins/marketplace.json")
    assert claude["name"] == "ps-legion-marketplace"
    assert claude["owner"]["name"]
    (entry,) = claude["plugins"]
    assert entry["name"] == "legion"
    assert entry["source"] == "./plugins/legion"
    entry = codex["plugins"][0]
    assert entry["source"]["source"] == "local"
    assert entry["source"]["path"] == "./plugins/legion"
    assert entry["policy"]["installation"] == "AVAILABLE"
    assert entry["category"]


def test_client_manifest_paths() -> None:
    claude = read_json(PLUGIN / ".claude-plugin/plugin.json")
    codex = read_json(PLUGIN / ".codex-plugin/plugin.json")
    copilot = read_json(PLUGIN / "plugin.json")
    assert [manifest["name"] for manifest in (claude, codex, copilot)] == ["legion"] * 3
    assert codex["skills"] == "./skills/"
    assert codex["hooks"] == "./hooks/hooks.json"
    assert copilot["skills"] == "skills/"
    assert copilot["hooks"] == "hooks/copilot-hooks.json"


@pytest.mark.parametrize("folder", sorted(path for path in SKILLS.iterdir() if path.is_dir()), ids=lambda path: path.name)
def test_skill_name_and_frontmatter(folder: Path) -> None:
    assert folder.name.startswith("legion-")
    assert len(folder.name) <= 64
    assert re.fullmatch(r"[a-z][a-z0-9]*(-[a-z0-9]+)*", folder.name)
    content = (folder / "SKILL.md").read_text(encoding="utf-8")
    frontmatter = re.match(r"(?s)^---\s*\n(.*?)\n---", content)
    assert frontmatter
    assert re.search(rf"(?m)^name:\s*{re.escape(folder.name)}\s*$", frontmatter[1])
    assert re.search(r"(?mi)^description:\s*Use when", frontmatter[1])


def test_hook_commands_use_the_required_root_and_format() -> None:
    neutral = read_json(PLUGIN / "hooks/copilot-hooks.json")["hooks"]["sessionStart"][0]
    shared = read_json(PLUGIN / "hooks/hooks.json")["hooks"]["SessionStart"][0]["hooks"][0]
    uv = 'uv run --no-project --no-python-downloads --offline --quiet --python ">=3.12" '
    fallback = "legion: uv or Python 3.12 is missing, so mode detection did not run; run the legion installer. If LEGION_ROLE=member is set, load the legion-member skill."
    fallback_json = json.dumps({"additionalContext": fallback}, separators=(",", ":"))
    assert neutral["powershell"] == uv + rf""""$env:COPILOT_PLUGIN_ROOT\hooks\session_start.py" --format context-json; if (-not $?) {{ '{fallback_json}' }}"""
    assert neutral["bash"] == uv + '"$COPILOT_PLUGIN_ROOT/hooks/session_start.py" --format context-json || echo ' + f"'{fallback_json}'"
    assert shared["command"] == uv + f'''"${{CLAUDE_PLUGIN_ROOT}}/hooks/session_start.py" --format text || echo "{fallback}"'''
    assert shared["commandWindows"] == uv + rf""""$env:CLAUDE_PLUGIN_ROOT\hooks\session_start.py" --format text; if (-not $?) {{ '{fallback}' }}"""


def test_stable_schema_references() -> None:
    template = read_json(SKILLS / "legion-repository/references/project-template.json")
    assert template["$schema"] == "https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/schemas/project.schema.json"
    schemas = sorted((PLUGIN / "schemas").glob("*.schema.json"))
    assert schemas
    for schema in schemas:
        assert read_json(schema)["$schema"] == "http://json-schema.org/draft-07/schema#", schema
