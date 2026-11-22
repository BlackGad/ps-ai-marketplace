import asyncio
import hashlib
import json
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

COMMON_PATH = Path(__file__).resolve().parents[2] / "bin/lib/common.ps1"


def repo_key(repo: str, cwd: str, *, windows: bool) -> str:
    paths = ntpath if windows else posixpath
    normalised = paths.normpath(paths.join(cwd, repo))
    if windows:
        normalised = normalised.lower()
    folder = paths.basename(normalised.rstrip("/\\"))
    folder = re.sub(r"[^a-zA-Z0-9_-]", "-", folder)[:48] or "repo"
    digest = hashlib.sha256(normalised.encode("utf-8")).hexdigest()[:12]
    return f"{folder}-{digest}"


def _inbox_path(repo: Path) -> Path:
    key = repo_key(str(repo.resolve()), str(Path.cwd()), windows=os.name == "nt")
    return Path.home() / ".legion" / "inbox" / key


def send(repo: Path, sender: str, text: str) -> None:
    inbox = _inbox_path(repo)
    new = inbox / "new"
    new.mkdir(parents=True, exist_ok=True)
    (inbox / "done").mkdir(exist_ok=True)
    name = f"{time.time_ns():020d}-{uuid.uuid4().hex}.json"
    temporary = new / f".{name}.tmp"
    payload = {"from": sender, "text": text, "at": datetime.now(UTC).isoformat()}
    try:
        with temporary.open("x", encoding="utf-8") as stream:
            json.dump(payload, stream, ensure_ascii=False)
        temporary.rename(new / name)
    finally:
        temporary.unlink(missing_ok=True)
    print(name, flush=True)
    asyncio.run(_nudge(repo.resolve(), sender))


def read(repo: Path) -> None:
    inbox = _inbox_path(repo)
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
            payload = json.loads(item.read_text(encoding="utf-8"))
            sender, at, text = payload["from"], payload["at"], payload["text"]
            if not all(isinstance(value, str) for value in (sender, at, text)):
                raise TypeError(item.name)
        except (OSError, ValueError, KeyError, TypeError):
            print(f"warning: skipped unreadable inbox file {item.name}", file=sys.stderr, flush=True)
        else:
            # The sender is one line and the body is indented, so message text cannot fake a header.
            body = "\n".join(f"    {line}" for line in text.splitlines() or [""])
            print(f"from: {' '.join(sender.split())}\nat: {at}\ntext:\n{body}\n", flush=True)
        item.rename(done / item.name)


async def _nudge(repo: Path, sender: str) -> None:
    if not (repo / ".legion/temp/overseer.lock").is_file():
        return
    # Reuse lease lifetime checks and platform wrapper selection from PowerShell.
    command = """
$ErrorActionPreference = 'Stop'
. $env:LEGION_INBOX_COMMON
. (Join-Path (Split-Path $env:LEGION_INBOX_COMMON) 'process.ps1')
$lease = Get-LegionLease -Repo $env:LEGION_INBOX_REPO
if ($lease.State -ne 'held' -or $lease.Data.tool -ne 'codex' -or -not $lease.Data.session) { exit 0 }
$wrapper = Get-LegionWrapperCommand -Id $lease.Data.account -HomeRoot $env:LEGION_INBOX_HOME
$pointer = 'New legion inbox message from ' + $env:LEGION_INBOX_SENDER + '; read it as the legion-overseer inbox reference describes (inbox.md).'
$result = Invoke-LegionProcess -Command $wrapper -Arguments @('queue', '--thread', $lease.Data.session, '--message', $pointer) -TimeoutSeconds 15
exit $result.ExitCode
"""
    environment = os.environ | {
        "LEGION_INBOX_COMMON": str(COMMON_PATH),
        "LEGION_INBOX_REPO": str(repo),
        "LEGION_INBOX_HOME": str(Path.home()),
        "LEGION_INBOX_SENDER": sender,
    }
    try:
        process = await asyncio.create_subprocess_exec(
            "pwsh", "-NoProfile", "-NonInteractive", "-Command", command, env=environment, stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL
        )
        try:
            result = await asyncio.wait_for(process.wait(), timeout=30)
        finally:
            if process.returncode is None:
                process.kill()
                await process.wait()
        if result == 0:
            return
    except (OSError, TimeoutError):
        pass
    print("warning: inbox message saved; Codex nudge failed.", file=sys.stderr)
