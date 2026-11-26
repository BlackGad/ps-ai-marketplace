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

from legion.services.accounts._accounts import AccountError
from legion.services.accounts._launch import account_command
from legion.services.accounts._launchers import LauncherError
from legion.services.foundry._az import AzAccessToken, check_token
from legion.services.repository import _lease
from legion.core import _settings_io
from legion.core._home import inbox_root, legion_home
from legion.core._run import run_command

NUDGE_TIMEOUT_SECONDS = 15
# Characters that another cmd.exe pass, such as the one inside a .cmd program (an npm shim), could change in a quoted argument.
CMD_CHANGES = re.compile(r'[%!^"]')


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
    return inbox_root(legion_home(home)) / key


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
    _nudge(repo.resolve(), sender, legion_home(home))


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


# Queues a short pointer in the overseer's Codex thread through the account's program; true when it worked.
def _queue_pointer(account: str, session: str, sender: str, home: Path) -> bool:
    pointer = f"New legion inbox message from {' '.join(sender.split())}; read it as the legion-overseer inbox reference describes (inbox.md)."
    arguments = ["queue", "--thread", session, "--message", pointer]
    # A .cmd program reads its arguments in a second cmd.exe pass on Windows, so text that pass could change is not sent.
    if os.name == "nt" and any(CMD_CHANGES.search(argument) for argument in arguments):
        return False
    # Preparing the account and queueing share one deadline; a Foundry account never starts an interactive az login here.
    deadline = time.monotonic() + NUDGE_TIMEOUT_SECONDS

    def token() -> AzAccessToken:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError("the nudge deadline has passed")
        return check_token(login=False, timeout=remaining)

    try:
        agent = next((item for item in _settings_io.load(home).agents if item.id == account), None)
        if agent is None:
            return False
        command = account_command(agent, home, token_check=token)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            return False
        words = command.words(arguments)
        result = run_command(words[0], words[1:], timeout=remaining, env=command.environment())
    except (AccountError, LauncherError, _settings_io.SettingsError, OSError, ValueError):
        return False
    return result.exit_code == 0
