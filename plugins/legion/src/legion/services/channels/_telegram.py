import re
import sys
from collections.abc import Callable
from contextlib import ExitStack
from pathlib import Path
from typing import (
    Literal,
    Optional,
)

import httpx
from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    JsonValue,
    TypeAdapter,
    ValidationError,
)

from legion.core._home import channel_folder, legion_home
from legion.core._http import https_client
from legion.core._settings_models import NAME_PATTERN

MESSAGE_LIMIT = 4096
PHOTO_SUFFIXES = {".jpg", ".jpeg", ".png", ".gif", ".webp"}

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


# The response, or None for any failure of the HTTP layer: its errors can quote the URL, which holds the token.
def _post(url: str, fields: dict[str, str], files: list[tuple[str, Path]]) -> Optional[httpx.Response]:
    try:
        with ExitStack() as stack:
            uploads = {name: (path.name, stack.enter_context(path.open("rb"))) for name, path in files}
            with https_client(60) as client:
                return client.post(url, data=fields, files=uploads or None)
    except Exception:
        return None


def _reply(response: httpx.Response) -> Optional[Reply]:
    try:
        return Reply.model_validate_json(response.content)
    except ValidationError:
        return None


# Telegram's own explanation, unless it echoes the token.
def _explanation(reply: Optional[Reply], token: str) -> Optional[str]:
    if reply is None or not reply.description or token in reply.description:
        return None
    return reply.description


# Every error is raised outside an except block, so no HTTP-layer error is chained or shown.
def call_bot(token: str, method: str, fields: dict[str, str], files: list[tuple[str, Path]]) -> JsonValue:
    response = _post(f"https://api.telegram.org/bot{token}/{method}", fields, files)
    if response is None:
        raise TelegramError("network error", 0)
    reply = _reply(response)
    if not response.is_success:
        raise TelegramError(_explanation(reply, token) or f"HTTP {response.status_code}", response.status_code)
    if reply is None:
        raise TelegramError("network error", 0)
    if not reply.ok:
        raise TelegramError(_explanation(reply, token) or "request failed", reply.error_code)
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
