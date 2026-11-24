import re
import sys
import urllib.error
import urllib.parse
import urllib.request
import uuid
from collections.abc import Callable
from pathlib import Path
from typing import (
    Literal,
    Optional,
)

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    JsonValue,
    TypeAdapter,
    ValidationError,
)

from ._home import channel_folder, legion_home
from ._settings_models import NAME_PATTERN

MESSAGE_LIMIT = 4096
PHOTO_SUFFIXES = {".jpg", ".jpeg", ".png", ".gif", ".webp"}

# An opener instead of urlopen: the URL is fixed https, and ruff flags urlopen (S310).
_opener = urllib.request.build_opener(urllib.request.HTTPSHandler)

# post(token, method, fields, files) returns the Bot API "result" or raises TelegramError.
Post = Callable[[str, str, dict[str, str], list[tuple[str, Path]]], JsonValue]


# The Telegram plugin's access.json. The bridge reads only the policy and allowlist; the plugin's other
# settings (groups, pending pairings, reactions) stay as they are.
class Access(BaseModel):
    model_config = ConfigDict(extra="allow")
    dm_policy: Literal["pairing", "allowlist", "disabled"] = Field("pairing", alias="dmPolicy")
    allow_from: list[str] = Field(default_factory=list, alias="allowFrom")


# Bot API objects: only the fields legion reads; Telegram adds fields over time.
class User(BaseModel):
    id: int
    first_name: str = ""
    username: Optional[str] = None


class Chat(BaseModel):
    id: int
    type: str


class Message(BaseModel):
    message_id: int
    chat: Chat
    sender: Optional[User] = Field(None, alias="from")
    text: Optional[str] = None
    caption: Optional[str] = None


class Update(BaseModel):
    update_id: int
    message: Optional[Message] = None


class ReplyParameters(BaseModel):
    message_id: int


class EmojiReaction(BaseModel):
    type: Literal["emoji"] = "emoji"
    emoji: str


_REACTIONS = TypeAdapter(list[EmojiReaction])


class Reply(BaseModel):
    ok: bool = False
    result: JsonValue = None
    description: Optional[str] = None
    error_code: int = 0


class TelegramError(Exception):
    # A plain-words failure. `code` is the Bot API error code, or 0 for a network failure.
    def __init__(self, description: str, code: int = 0) -> None:
        super().__init__(description)
        self.code = code


def bot_folder(channel: str, home: Optional[Path] = None) -> Path:
    if not re.fullmatch(NAME_PATTERN, channel):
        raise TelegramError(f"bad channel id '{channel}'")
    return channel_folder("telegram", channel, legion_home(home))


def read_token(channel: str, home: Optional[Path] = None) -> str:
    env_file = bot_folder(channel, home) / ".env"
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


def call_bot(token: str, method: str, fields: dict[str, str], files: list[tuple[str, Path]]) -> JsonValue:
    if files:
        body, content_type = _multipart(fields, files)
    else:
        body, content_type = urllib.parse.urlencode(fields).encode(), "application/x-www-form-urlencoded"
    request = urllib.request.Request(f"https://api.telegram.org/bot{token}/{method}", data=body, headers={"Content-Type": content_type})
    try:
        with _opener.open(request, timeout=60) as response:
            reply = Reply.model_validate_json(response.read())
    except urllib.error.HTTPError as error:
        # The error text holds the URL, which holds the token: use only Telegram's own description.
        try:
            description = Reply.model_validate_json(error.read()).description
        except Exception:
            description = None
        raise TelegramError(description or f"HTTP {error.code}", error.code) from None
    except Exception:
        # Any HTTP-layer error can quote the URL, so none is chained or shown.
        raise TelegramError("network error", 0) from None
    if not reply.ok:
        raise TelegramError(reply.description or "request failed", reply.error_code)
    return reply.result


def _sent(result: JsonValue, method: str) -> Message:
    try:
        return Message.model_validate(result)
    except ValidationError:
        raise TelegramError(f"Telegram sent an unexpected reply to {method}") from None


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


def send(channel: str, chat: str, text: str, text_format: str, reply_to: Optional[int], files: list[Path], *, post: Optional[Post] = None, home: Optional[Path] = None) -> int:
    def action() -> None:
        call = post or call_bot
        token = read_token(channel, home)
        reply = {"reply_parameters": ReplyParameters(message_id=reply_to).model_dump_json()} if reply_to else {}
        for part in _split(text) if text else []:
            fields = {"chat_id": chat, "text": part}
            if text_format == "markdownv2":
                fields["parse_mode"] = "MarkdownV2"
            sent = _sent(call(token, "sendMessage", fields | reply, []), "sendMessage")
            print(sent.message_id, flush=True)
            reply = {}
        for path in files:
            photo = path.suffix.lower() in PHOTO_SUFFIXES
            field = "photo" if photo else "document"
            method = "sendPhoto" if photo else "sendDocument"
            sent = _sent(call(token, method, {"chat_id": chat} | reply, [(field, path)]), method)
            print(sent.message_id, flush=True)
            reply = {}

    return _run(action)


def react(channel: str, chat: str, message: str, emoji: str, *, post: Optional[Post] = None, home: Optional[Path] = None) -> int:
    def action() -> None:
        fields = {"chat_id": chat, "message_id": message, "reaction": _REACTIONS.dump_json([EmojiReaction(emoji=emoji)]).decode()}
        (post or call_bot)(read_token(channel, home), "setMessageReaction", fields, [])

    return _run(action)
