import hashlib
import ntpath
import os
import posixpath
import re
import sys
import time
import uuid
from datetime import (
    UTC,
    datetime,
    timedelta,
)
from pathlib import Path
from typing import Optional

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
)

from . import _lease
from ._run import run_command

NUDGE_TIMEOUT_SECONDS = 15
# The account id rule of Get-LegionWrapperCommand, so an id from the lock cannot point outside <home>/.legion/bin.
ACCOUNT_ID = re.compile(r"[a-z][a-z0-9-]*")


# One inbox file: {"from": ..., "text": ..., "at": ...}.
class InboxMessage(BaseModel):
    model_config = ConfigDict(strict=True, validate_by_name=True)
    sender: str = Field(validation_alias="from", serialization_alias="from")
    text: str
    at: str


def repo_key(repo: str, cwd: str, *, windows: bool) -> str:
    paths = ntpath if windows else posixpath
    normalised = paths.normpath(paths.join(cwd, repo))
    if windows:
        normalised = normalised.lower()
    folder = paths.basename(normalised.rstrip("/\\"))
    folder = re.sub(r"[^a-zA-Z0-9_-]", "-", folder)[:48] or "repo"
    digest = hashlib.sha256(normalised.encode("utf-8")).hexdigest()[:12]
    return f"{folder}-{digest}"


def _inbox_path(repo: Path, home: Optional[Path]) -> Path:
    key = repo_key(str(repo.resolve()), str(Path.cwd()), windows=os.name == "nt")
    return (home or Path.home()) / ".legion" / "inbox" / key


def send(repo: Path, sender: str, text: str, home: Optional[Path] = None) -> None:
    inbox = _inbox_path(repo, home)
    new = inbox / "new"
    new.mkdir(parents=True, exist_ok=True)
    (inbox / "done").mkdir(exist_ok=True)
    name = f"{time.time_ns():020d}-{uuid.uuid4().hex}.json"
    temporary = new / f".{name}.tmp"
    message = InboxMessage(sender=sender, text=text, at=datetime.now(UTC).isoformat())
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            stream.write(message.model_dump_json(by_alias=True))
        temporary.rename(new / name)
    finally:
        temporary.unlink(missing_ok=True)
    print(name, flush=True)
    _nudge(repo.resolve(), sender, home or Path.home())


def read(repo: Path, home: Optional[Path] = None) -> None:
    inbox = _inbox_path(repo, home)
    done = inbox / "done"
    cutoff = (datetime.now(UTC) - timedelta(days=7)).timestamp()
    for item in done.glob("*.json"):
        if not item.name.startswith(".") and item.is_file() and item.stat().st_mtime < cutoff:
            item.unlink()
    messages = sorted(item for item in (inbox / "new").glob("*.json") if not item.name.startswith(".") and item.is_file())
    if not messages:
        print("inbox: empty")
        return
    done.mkdir(parents=True, exist_ok=True)
    for item in messages:
        try:
            message = InboxMessage.model_validate_json(item.read_text(encoding="utf-8"))
        except (OSError, ValueError):
            print(f"warning: skipped unreadable inbox file {item.name}", file=sys.stderr, flush=True)
        else:
            # The sender is one line and the body is indented, so message text cannot fake a header.
            body = "\n".join(f"    {line}" for line in message.text.splitlines() or [""])
            print(f"from: {' '.join(message.sender.split())}\nat: {message.at}\ntext:\n{body}\n", flush=True)
        item.rename(done / item.name)


def _nudge(repo: Path, sender: str, home: Path) -> None:
    current = _lease.state(repo)
    lease = current.lease
    if current.state != "held" or lease is None or lease.tool != "codex" or not lease.session:
        return
    if _queue_pointer(lease.account, lease.session, sender, home):
        return
    print("warning: inbox message saved; Codex nudge failed.", file=sys.stderr)


# Queues a short pointer in the overseer's Codex thread through the account's command; true when it worked.
def _queue_pointer(account: str, session: str, sender: str, home: Path) -> bool:
    if not ACCOUNT_ID.fullmatch(account):
        return False
    wrapper = home / ".legion" / "bin" / (f"{account}.cmd" if os.name == "nt" else account)
    pointer = f"New legion inbox message from {sender}; read it as the legion-overseer inbox reference describes (inbox.md)."
    try:
        result = run_command(str(wrapper), ["queue", "--thread", session, "--message", pointer], timeout=NUDGE_TIMEOUT_SECONDS)
    except OSError:
        return False
    return result.exit_code == 0
