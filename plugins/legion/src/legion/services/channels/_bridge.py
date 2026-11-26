import os
import sys
import time
from collections.abc import Callable
from functools import partial
from pathlib import Path
from typing import Optional

import psutil
from legion.services.channels import _inbox
from legion.services.channels._telegram import (
    Access,
    Message,
    Post,
    TelegramError,
    Update,
    User,
    bot_folder,
    call_bot,
    parse_updates,
    read_token,
)

MAX_BACKOFF = 60


def process_alive(pid: int) -> bool:
    try:
        if pid <= 0 or not psutil.pid_exists(pid):
            return False
        process = psutil.Process(pid)
        return process.status() != psutil.STATUS_ZOMBIE and process.is_running()
    except (psutil.NoSuchProcess, OverflowError):
        return False
    except psutil.AccessDenied:
        # A PID we cannot inspect may still hold the bridge.
        return True


def _live_pid(path: Path, alive: Callable[[int], bool]) -> bool:
    try:
        return alive(int(path.read_text(encoding="utf-8").strip()))
    except (OSError, ValueError):
        return False


def _claim_pid_file(path: Path, alive: Callable[[int], bool]) -> bool:
    # Exclusive create is the claim; a file whose process is dead is replaced once.
    for _ in range(2):
        try:
            with path.open("x", encoding="utf-8") as stream:
                stream.write(str(os.getpid()))
        except FileExistsError:
            if _live_pid(path, alive):
                return False
            path.unlink(missing_ok=True)
        else:
            return True
    return False


def _allow_from(folder: Path) -> list[str]:
    try:
        access = Access.model_validate_json((folder / "access.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return []
    if access.dm_policy == "disabled":
        return []
    return access.allow_from


def _inbox_text(message: Message, sender: User) -> Optional[str]:
    text = message.text or message.caption
    if not text:
        return None
    name = " ".join(str(sender.username or sender.first_name or sender.id).split())
    return f"telegram chat_id={message.chat.id} message_id={message.message_id} user={name}\n{text}"


def _deliver_updates(updates: list[Update], allowed: list[str], repo: Path, deliver: Callable[[Path, str, str], None]) -> None:
    for item in updates:
        message = item.message
        if message is None or message.sender is None or message.chat.type != "private" or str(message.sender.id) not in allowed:
            continue
        text = _inbox_text(message, message.sender)
        if text:
            deliver(repo, "telegram", text)


def run(
    channel: str,
    repo: Path,
    *,
    post: Post = call_bot,
    alive: Callable[[int], bool] = process_alive,
    deliver: Optional[Callable[[Path, str, str], None]] = None,
    sleep: Callable[[float], None] = time.sleep,
    home: Optional[Path] = None,
) -> int:
    send = deliver or partial(_inbox.send, home=home)
    try:
        token = read_token(channel, home)
    except TelegramError as error:
        print(f"telegram: {error}", file=sys.stderr)
        return 1
    folder = bot_folder(channel, home)
    for name in ("bridge.pid", "bot.pid"):
        if _live_pid(folder / name, alive):
            print(f"telegram: another program is already polling this bot ({name} in the bot folder)", file=sys.stderr)
            return 1
    pid_file = folder / "bridge.pid"
    if not _claim_pid_file(pid_file, alive):
        print("telegram: another program is already polling this bot (bridge.pid in the bot folder)", file=sys.stderr)
        return 1
    offset: Optional[int] = None
    backoff = 1
    try:
        while True:
            fields = {"timeout": "30", "allowed_updates": '["message"]'}
            if offset is not None:
                fields["offset"] = str(offset)
            try:
                updates = parse_updates(post(token, "getUpdates", fields, []))
            except TelegramError as error:
                if error.code == 409:
                    print(f"telegram: another program is polling this bot ({error})", file=sys.stderr)
                    return 1
                if error.code == 401:
                    print(f"telegram: {error}", file=sys.stderr)
                    return 1
                sleep(backoff)
                backoff = min(backoff * 2, MAX_BACKOFF)
                continue
            backoff = 1
            _deliver_updates(updates, _allow_from(folder), repo, send)
            if updates:
                offset = updates[-1].update_id + 1
    except KeyboardInterrupt:
        return 0
    finally:
        pid_file.unlink(missing_ok=True)
