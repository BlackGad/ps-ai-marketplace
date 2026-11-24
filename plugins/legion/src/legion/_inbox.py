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
from ._home import (
    inbox_root,
    legion_home,
    wrapper_command,
)
from ._run import run_command
from ._settings_models import NAME_PATTERN

NUDGE_TIMEOUT_SECONDS = 15
# The account id rule of Get-LegionWrapperCommand, so an id from the lock cannot point outside <home>/.legion/bin.
ACCOUNT_ID = re.compile(NAME_PATTERN)
# Characters that another cmd.exe pass, such as a call inside the account's own .cmd, could change in a quoted argument.
CMD_CHANGES = re.compile(r'[%!^"]')
# Lines of the Windows launcher that New-LegionWrappers and New-FoundryWrappers write (accounts.ps1).
LAUNCHER_SET = re.compile(r'@set "([A-Za-z_][A-Za-z0-9_]*)=([^"]*)"')
LAUNCHER_RUN = re.compile(r'@(pwsh -NoProfile -File |call )?"([^"]+)"( -Agent [a-z][a-z0-9-]*)? %\*')


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


# Queues a short pointer in the overseer's Codex thread through the account's command; true when it worked.
def _queue_pointer(account: str, session: str, sender: str, home: Path) -> bool:
    if not ACCOUNT_ID.fullmatch(account):
        return False
    pointer = f"New legion inbox message from {' '.join(sender.split())}; read it as the legion-overseer inbox reference describes (inbox.md)."
    arguments = ["queue", "--thread", session, "--message", pointer]
    command_path = wrapper_command(account, home)
    try:
        if os.name != "nt":
            result = run_command(str(command_path), arguments, timeout=NUDGE_TIMEOUT_SECONDS)
        else:
            launcher = _windows_launcher(command_path, account)
            if launcher is None:
                return False
            command, environment = launcher
            # What the .cmd runs next is not legion's, so text it could change is not sent through it.
            if Path(command[0]).suffix.lower() in {".cmd", ".bat"} and any(CMD_CHANGES.search(argument) for argument in arguments):
                return False
            if command[0] == "pwsh":
                pwsh = _pwsh_path()
                if pwsh is None:
                    return False
                command[0] = pwsh
            result = run_command(command[0], [*command[1:], *arguments], timeout=NUDGE_TIMEOUT_SECONDS, env={**os.environ, **environment})
    except (OSError, ValueError):
        return False
    return result.exit_code == 0


# The real command and settings behind a Windows account launcher, or None when it is not one legion wrote.
# The launcher's own cmd.exe line, and its call, would expand %NAME% in the thread and sender, so the nudge
# runs the real command itself: an .exe or pwsh gets an argument vector, a .cmd only text no cmd.exe pass can change.
def _windows_launcher(path: Path, account: str) -> Optional[tuple[list[str], dict[str, str]]]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if lines[:1] != [f"@rem Generated by legion: account {account}"]:
        return None
    environment = {}
    if len(lines) == 2:
        run = lines[1]
    elif len(lines) == 5 and lines[1] == "@setlocal" and lines[4] == "@exit /b %errorlevel%" and (setting := LAUNCHER_SET.fullmatch(lines[2])):
        environment[setting[1]] = setting[2].replace("%%", "%")
        run = lines[3]
    else:
        return None
    match = LAUNCHER_RUN.fullmatch(run)
    if match is None:
        return None
    target = match[2].replace("%%", "%")
    command = ["pwsh", "-NoProfile", "-File", target] if match[1] == "pwsh -NoProfile -File " else [target]
    if match[3]:
        command.extend(match[3].split())
    return command, environment


# pwsh from an absolute PATH folder: for a bare name Windows would look in the current folder first.
def _pwsh_path() -> Optional[str]:
    for folder in os.environ.get("PATH", "").split(os.pathsep):
        candidate = Path(folder) / "pwsh.exe"
        if Path(folder).is_absolute() and candidate.is_file():
            return str(candidate)
    return None
