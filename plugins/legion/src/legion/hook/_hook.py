# The session-start hook: tells a new session whether it is a legion member or in an orchestrated repo.
# Every session waits for it, so it uses only the standard library and the stdlib-only lease and update modules.

import json
import os
import re
import sys
from collections.abc import Mapping
from dataclasses import dataclass
from pathlib import Path
from typing import Optional, TextIO

from legion.core._home import home_path, settings_path
from legion.core._lease_record import LeaseUnreadableError, read_lease, same_host
from legion.services.installation import _update
from legion.core._plugin import PLUGIN_ROOT

MEMBER = (
    "legion: you are a legion member. Load the legion-member skill to read your task from LEGION_TASK and follow it. "
    "Do not load legion-overseer. A summoned unit cannot summon: never start other agents."
)
MEMBER_WITHOUT_TASK = "legion: LEGION_ROLE=member without LEGION_TASK; ignored."
ORCHESTRATED = "legion: this repo is orchestrated. Say continue to act as the overseer."
LEASE_NOTES = {
    "local": " An overseer lease exists (`{tool}/{account}`); the takeover checks whether it is live.",
    "unreadable": " Overseer lease file unreadable.",
    "foreign": " An overseer lease from another host exists; ask the owner before taking over.",
}
MAX_TOPIC_LINES = 40
MAX_BLOCK_CHARS = 4000
MEMBER_KNOWLEDGE = "Before you start, open only the notes whose titles match your task; do not read the whole hub."
OVERSEER_KNOWLEDGE = "Read the matching notes before research, after two failed attempts, and when a failure looks familiar; cite the note."
FAILURE = "legion: mode detection failed; continuing without mode context."


@dataclass(frozen=True)
class HookInput:
    cwd: Optional[str] = None

    @classmethod
    def from_json(cls, text: str) -> "HookInput":
        data = json.loads(text)
        if not isinstance(data, dict):
            raise TypeError("hook input is not a JSON object")
        cwd = data.get("cwd")
        if cwd is not None and not isinstance(cwd, str):
            raise TypeError("hook input cwd is not text")
        return cls(cwd or None)


def main(argv: list[str]) -> int:
    as_json = argv[-2:] == ["--format", "context-json"]
    try:
        text = mode_text(session_folder(sys.stdin), os.environ)
    except Exception:
        text = FAILURE  # Mode detection must never stop a session from starting.
    if as_json:
        write_line(json.dumps({"additionalContext": text}, separators=(",", ":")) if text else "{}")
    elif text:
        write_line(text)
    return 0


# A title or path outside the console code page becomes "?" instead of stopping the hook.
def write_line(text: str) -> None:
    encoding = sys.stdout.encoding or "utf-8"
    sys.stdout.write((text + "\n").encode(encoding, errors="replace").decode(encoding))


def mode_text(folder: Path, environment: Mapping[str, str]) -> str:
    configured_home = environment.get("LEGION_HOME")
    if environment.get("LEGION_ROLE", "").lower() == "member":
        if not environment.get("LEGION_TASK"):
            return MEMBER_WITHOUT_TASK
        hub = knowledge_hub(configured_home)
        return MEMBER if hub is None else f"{MEMBER}\nKnowledge hub index: {hub / '_index.md'}\n{MEMBER_KNOWLEDGE}"
    repo = find_repo_root(folder)
    if not (repo / ".legion" / "state" / "handoff.md").exists():
        return ""
    lines = [ORCHESTRATED + lease_note(repo)]
    try:
        update = _update.get_update(PLUGIN_ROOT, Path(configured_home) if configured_home else None, cache_only=True)
        if update is not None and update.newer:
            lines.append(f'legion {update.available} is available (installed {update.installed}); say "update legion" to update.')
    except Exception:
        pass  # An update check failure keeps the mode guidance.
    text = " ".join(lines)
    hub = knowledge_hub(configured_home)
    return text if hub is None else f"{text}\n{hub_block(hub)}"


def lease_note(repo: Path) -> str:
    try:
        lease = read_lease(repo)
    except LeaseUnreadableError:
        return LEASE_NOTES["unreadable"]
    if lease is None:
        return ""
    if not same_host(lease.host):
        return LEASE_NOTES["foreign"]
    # Only render identifiers in session context, where arbitrary lease text could act as instructions.
    if not all(re.fullmatch(r"[a-z][a-z0-9-]*", value) for value in (lease.tool, lease.account)):
        return LEASE_NOTES["unreadable"]
    return LEASE_NOTES["local"].format(tool=lease.tool, account=lease.account)


# The session folder may be below the repository root; the nearest .legion/state or .git marks the root.
def find_repo_root(folder: Path) -> Path:
    for candidate in (folder, *folder.parents):
        if (candidate / ".legion" / "state").exists() or (candidate / ".git").exists():
            return candidate
    return folder


# Hook runners pass the session as JSON on stdin; its cwd is the session folder, which may differ from ours.
def session_folder(stdin: Optional[TextIO]) -> Path:
    if stdin is not None and not stdin.isatty():
        try:
            cwd = HookInput.from_json(stdin.buffer.read().decode("utf-8-sig")).cwd
        except (ValueError, TypeError):
            cwd = None
        if cwd and Path(cwd).exists():
            return Path(cwd)
    return Path.cwd()


# The hub path when the owner turned knowledge on and the hub folder exists; anything unreadable counts as off.
def knowledge_hub(configured_home: Optional[str]) -> Optional[Path]:
    try:
        home = Path(configured_home) if configured_home else Path.home()
        if read_json(settings_path(home)).get("knowledgeEnabled") is not True:
            return None
        pointer = read_json(home / ".config" / "llm-wiki" / "config.json")
        value = pointer.get("hub_path") or pointer.get("resolved_path") or "~/.legion/knowledge"
        hub = home_path(str(value), home)
        return hub if hub.is_dir() else None
    except (OSError, RuntimeError, ValueError, TypeError, AttributeError):
        return None


def read_json(path: Path) -> dict[str, object]:
    try:
        data = json.loads(path.read_text(encoding="utf-8-sig"))
    except FileNotFoundError:
        return {}
    if not isinstance(data, dict):
        raise TypeError("not a JSON object")
    return data


# The whole block is bounded: at most MAX_TOPIC_LINES topics and MAX_BLOCK_CHARS characters of topic lines.
def hub_block(hub: Path) -> str:
    folders = topic_folders(hub)
    names_only = len(folders) > MAX_TOPIC_LINES
    left_out = names_only
    lines = [f"Knowledge hub: {hub}"]
    room = MAX_BLOCK_CHARS
    for folder in folders[:MAX_TOPIC_LINES]:
        line = f"- {topic_title(folder)}"
        if room < len(line) + 1:
            left_out = True
            break
        titles = [] if names_only else topic_articles(folder)
        shown = []
        for title in titles:
            if len(line) + 1 + len("; ".join([*shown, title])) + 1 > room:
                left_out = True
                break
            shown.append(title)
        if shown:
            line += ": " + "; ".join(shown)
        room -= len(line) + 1
        lines.append(line)
    if left_out:
        lines.append(f"more in {hub / '_index.md'}")
    lines.append(OVERSEER_KNOWLEDGE)
    return "\n".join(lines)


# Each topic folder is a wiki: its title is the first heading of its _index.md, its articles are the table rows of two indexes.
def topic_folders(hub: Path) -> list[Path]:
    try:
        return sorted(path for path in (hub / "topics").iterdir() if path.is_dir() and not path.name.startswith("."))
    except OSError:
        return []


def topic_articles(folder: Path) -> list[str]:
    return [title for index in ("topics", "concepts") for title in article_titles(folder / "wiki" / index / "_index.md")]


def topic_title(folder: Path) -> str:
    for line in read_lines(folder / "_index.md"):
        if line.startswith("# ") and line[2:].strip():
            return clean(line[2:])
    return clean(folder.name)


def article_titles(index: Path) -> list[str]:
    titles = []
    for line in read_lines(index):
        match = re.match(r"\|\s*\[([^\]]+)\]\([^)]*\)\s*\|", line)
        if match:
            titles.append(clean(match.group(1)))
    return titles


def read_lines(path: Path) -> list[str]:
    try:
        return path.read_text(encoding="utf-8-sig").splitlines()
    except (OSError, ValueError):
        return []


# Titles come from files; keep each to one short plain line.
def clean(text: str) -> str:
    return " ".join(text.split())[:80]
