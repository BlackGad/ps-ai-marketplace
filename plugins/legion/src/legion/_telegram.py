import json
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import Any, Optional

MESSAGE_LIMIT = 4096
PHOTO_SUFFIXES = {".jpg", ".jpeg", ".png", ".gif", ".webp"}

# An opener instead of urlopen: the URL is fixed https, and ruff flags urlopen (S310).
_opener = urllib.request.build_opener(urllib.request.HTTPSHandler)

# post(token, method, fields, files) returns the Bot API "result" or raises TelegramError.
Post = Callable[[str, str, dict[str, str], list[tuple[str, Path]]], Any]


class TelegramError(Exception):
    # A plain-words failure. `code` is the Bot API error code, or 0 for a network failure.
    def __init__(self, description: str, code: int = 0) -> None:
        super().__init__(description)
        self.code = code


def bot_folder(channel: str) -> Path:
    if not re.fullmatch(r"[a-z][a-z0-9-]*", channel):
        raise TelegramError(f"bad channel id '{channel}'")
    return Path.home() / ".legion" / "channels" / "telegram" / channel


def read_token(channel: str) -> str:
    env_file = bot_folder(channel) / ".env"
    if env_file.is_file():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            name, _, value = line.partition("=")
            if name.strip() == "TELEGRAM_BOT_TOKEN" and value.strip().strip("\"'"):
                token = value.strip().strip("\"'")
                if not re.fullmatch(r"\d+:[A-Za-z0-9_-]+", token):
                    raise TelegramError(f"the bot token for channel '{channel}' has a wrong format")
                return token
    raise TelegramError(f"no bot token for channel '{channel}'; pair the bot on Claude first")


def _multipart(fields: dict[str, str], files: list[tuple[str, Path]]) -> tuple[bytes, str]:
    boundary = uuid.uuid4().hex
    body = b""
    for name, value in fields.items():
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"\r\n\r\n{value}\r\n'.encode()
    for name, path in files:
        body += f'--{boundary}\r\nContent-Disposition: form-data; name="{name}"; filename="{path.name}"\r\n'.encode()
        body += b"Content-Type: application/octet-stream\r\n\r\n" + path.read_bytes() + b"\r\n"
    return body + f"--{boundary}--\r\n".encode(), f"multipart/form-data; boundary={boundary}"


def _post(token: str, method: str, fields: dict[str, str], files: list[tuple[str, Path]]) -> Any:
    if files:
        body, content_type = _multipart(fields, files)
    else:
        body, content_type = urllib.parse.urlencode(fields).encode(), "application/x-www-form-urlencoded"
    request = urllib.request.Request(f"https://api.telegram.org/bot{token}/{method}", data=body, headers={"Content-Type": content_type})
    try:
        with _opener.open(request, timeout=60) as response:
            answer = json.load(response)
    except urllib.error.HTTPError as error:
        # The error text holds the URL, which holds the token: use only Telegram's own description.
        try:
            answer = json.load(error)
        except Exception:
            answer = {}
        raise TelegramError(answer.get("description", f"HTTP {error.code}"), error.code) from None
    except Exception:
        # Any HTTP-layer error can quote the URL, so none is chained or shown.
        raise TelegramError("network error", 0) from None
    if not answer.get("ok"):
        raise TelegramError(answer.get("description", "request failed"), answer.get("error_code", 0))
    return answer.get("result")


def _split(text: str) -> list[str]:
    parts: list[str] = []
    while len(text) > MESSAGE_LIMIT:
        cut = text.rfind("\n", 0, MESSAGE_LIMIT)
        if cut <= 0:
            parts.append(text[:MESSAGE_LIMIT])
            text = text[MESSAGE_LIMIT:]
        else:
            parts.append(text[:cut])
            text = text[cut + 1 :]
    return [*parts, text]


def _run(action: Callable[[], None]) -> int:
    try:
        action()
    except TelegramError as error:
        print(f"telegram: {error}", file=sys.stderr)
        return 1
    return 0


def send(channel: str, chat: str, text: str, text_format: str, reply_to: Optional[int], files: list[Path], *, post: Optional[Post] = None) -> int:
    def action() -> None:
        call = post or _post
        token = read_token(channel)
        reply = {"reply_parameters": json.dumps({"message_id": reply_to})} if reply_to else {}
        for part in _split(text) if text else []:
            fields = {"chat_id": chat, "text": part}
            if text_format == "markdownv2":
                fields["parse_mode"] = "MarkdownV2"
            sent = call(token, "sendMessage", fields | reply, [])
            print(sent["message_id"], flush=True)
            reply = {}
        for path in files:
            photo = path.suffix.lower() in PHOTO_SUFFIXES
            field = "photo" if photo else "document"
            sent = call(token, "sendPhoto" if photo else "sendDocument", {"chat_id": chat} | reply, [(field, path)])
            print(sent["message_id"], flush=True)
            reply = {}

    return _run(action)


def react(channel: str, chat: str, message: str, emoji: str, *, post: Optional[Post] = None) -> int:
    def action() -> None:
        fields = {"chat_id": chat, "message_id": message, "reaction": json.dumps([{"type": "emoji", "emoji": emoji}])}
        (post or _post)(read_token(channel), "setMessageReaction", fields, [])

    return _run(action)
