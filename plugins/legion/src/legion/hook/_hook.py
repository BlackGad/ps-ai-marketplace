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
        home = Path(argv[1]) if argv[:1] == ["--home"] else None
        text = mode_text(session_folder(sys.stdin), os.environ, home)
    except Exception:
        text = FAILURE  # Mode detection must never stop a session from starting.
    if as_json:
        print(json.dumps({"additionalContext": text}, separators=(",", ":")) if text else "{}")
    elif text:
        print(text)
    return 0


def mode_text(folder: Path, environment: Mapping[str, str], home: Optional[Path] = None) -> str:
    if environment.get("LEGION_ROLE", "").lower() == "member":
        return MEMBER if environment.get("LEGION_TASK") else MEMBER_WITHOUT_TASK
    repo = find_repo_root(folder)
    if not (repo / ".legion" / "state" / "handoff.md").exists():
        return ""
    lines = [ORCHESTRATED + lease_note(repo)]
    if home is None and (configured_home := environment.get("LEGION_HOME")):
        home = Path(configured_home)
    try:
        update = _update.get_update(PLUGIN_ROOT, home, cache_only=True)
        if update is not None and update.newer:
            lines.append(f'legion {update.available} is available (installed {update.installed}); say "update legion" to update.')
    except Exception:
        pass  # An update check failure keeps the mode guidance.
    return " ".join(lines)


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
