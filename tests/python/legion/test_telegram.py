import json
import logging
from collections.abc import Callable
from pathlib import Path
from typing import Any, Optional

import httpx
import pytest
from pydantic import JsonValue

from cli_runner import run
from legion.core._http import https_client
from legion.services.channels import _telegram
from legion.services.channels._telegram import Access, TelegramError
import contextlib

BOT_KEY = "123456:secret-token"


@pytest.fixture
def bot_folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    folder = tmp_path / ".legion" / "channels" / "telegram" / "main"
    folder.mkdir(parents=True)
    (folder / ".env").write_text(f"OTHER=1\nTELEGRAM_BOT_TOKEN={BOT_KEY}\n", encoding="utf-8")
    return folder


class FakePost:
    def __init__(self, error: Optional[TelegramError] = None) -> None:
        self.calls: list[tuple[str, str, dict[str, str], list[tuple[str, Path]]]] = []
        self.error = error

    def __call__(self, token: str, method: str, fields: dict[str, str], files: list[tuple[str, Path]]) -> Any:
        self.calls.append((token, method, fields, files))
        if self.error:
            raise self.error
        return {"message_id": 100 + len(self.calls), "chat": {"id": 42, "type": "private"}, "date": 0}


@pytest.mark.usefixtures("bot_folder")
def test_send_text_with_format_and_reply(capsys: pytest.CaptureFixture[str]) -> None:
    post = FakePost()
    assert _telegram.send("main", "42", "hi", "markdownv2", 7, [], post=post) == 0
    token, method, fields, files = post.calls[0]
    assert (token, method, files) == (BOT_KEY, "sendMessage", [])
    assert json.loads(fields.pop("reply_parameters")) == {"message_id": 7}
    assert fields == {"chat_id": "42", "text": "hi", "parse_mode": "MarkdownV2"}
    assert capsys.readouterr().out == "101\n"


@pytest.mark.usefixtures("bot_folder")
def test_send_plain_text_has_no_parse_mode() -> None:
    post = FakePost()
    _telegram.send("main", "42", "hi", "text", None, [], post=post)
    assert post.calls[0][2] == {"chat_id": "42", "text": "hi"}


@pytest.mark.usefixtures("bot_folder")
def test_send_splits_long_text(capsys: pytest.CaptureFixture[str]) -> None:
    post = FakePost()
    text = "a" * 4000 + "\n" + "b" * 4000
    _telegram.send("main", "42", text, "text", 7, [], post=post)
    assert [call[2]["text"] for call in post.calls] == ["a" * 4000, "b" * 4000]
    assert "reply_parameters" in post.calls[0][2]
    assert "reply_parameters" not in post.calls[1][2]
    assert capsys.readouterr().out == "101\n102\n"
    post = FakePost()
    _telegram.send("main", "42", "c" * 5000, "text", None, [], post=post)
    assert [len(call[2]["text"]) for call in post.calls] == [4096, 904]


@pytest.mark.usefixtures("bot_folder")
def test_send_files_photo_or_document(tmp_path: Path) -> None:
    image = tmp_path / "pic.PNG"
    image.write_bytes(b"png")
    document = tmp_path / "notes.txt"
    document.write_text("x", encoding="utf-8")
    post = FakePost()
    _telegram.send("main", "42", "see", "text", None, [image, document], post=post)
    assert [call[1] for call in post.calls] == ["sendMessage", "sendPhoto", "sendDocument"]
    assert post.calls[1][3] == [("photo", image)]
    assert post.calls[2][3] == [("document", document)]
    assert post.calls[1][2] == {"chat_id": "42"}


@pytest.mark.usefixtures("bot_folder")
def test_react(capsys: pytest.CaptureFixture[str]) -> None:
    post = FakePost()
    assert _telegram.react("main", "42", "9", "\N{THUMBS UP SIGN}", post=post) == 0
    _, method, fields, _ = post.calls[0]
    assert method == "setMessageReaction"
    assert fields["message_id"] == "9"
    assert json.loads(fields["reaction"]) == [{"type": "emoji", "emoji": "\N{THUMBS UP SIGN}"}]
    assert capsys.readouterr().out == ""


@pytest.mark.usefixtures("bot_folder")
def test_api_error_prints_description_only(capsys: pytest.CaptureFixture[str]) -> None:
    post = FakePost(TelegramError("Bad Request: chat not found", 400))
    assert _telegram.send("main", "42", "hi", "text", None, [], post=post) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == "telegram: Bad Request: chat not found\n"
    assert BOT_KEY not in captured.err


def test_missing_token_is_plain_error(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    assert _telegram.send("main", "42", "hi", "text", None, [], post=FakePost()) == 1
    assert "no bot token" in capsys.readouterr().err


@pytest.mark.usefixtures("bot_folder")
def test_bad_channel_id_is_refused(capsys: pytest.CaptureFixture[str]) -> None:
    assert _telegram.react("../x", "42", "9", "x", post=FakePost()) == 1
    assert "channel id" in capsys.readouterr().err


def use_transport(monkeypatch: pytest.MonkeyPatch, handler: Callable[[httpx.Request], httpx.Response]) -> None:
    monkeypatch.setattr(_telegram, "https_client", lambda timeout: https_client(timeout, httpx.MockTransport(handler)))


def test_real_post_hides_token_in_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    use_transport(monkeypatch, lambda _request: httpx.Response(409, json={"ok": False, "error_code": 409, "description": "Conflict"}))
    with pytest.raises(TelegramError) as caught:
        _telegram.call_bot(BOT_KEY, "getUpdates", {}, [])
    assert (caught.value.code, str(caught.value)) == (409, "Conflict")

    def offline(request: httpx.Request) -> httpx.Response:
        raise httpx.ConnectError("no route", request=request)

    use_transport(monkeypatch, offline)
    with pytest.raises(TelegramError) as caught:
        _telegram.call_bot(BOT_KEY, "getUpdates", {}, [])
    assert caught.value.code == 0
    assert BOT_KEY not in str(caught.value)
    assert caught.value.__cause__ is None
    assert caught.value.__context__ is None


def test_a_failure_without_a_description_names_the_http_status(monkeypatch: pytest.MonkeyPatch) -> None:
    use_transport(monkeypatch, lambda _request: httpx.Response(502, text="<html>bad gateway</html>"))
    with pytest.raises(TelegramError) as caught:
        _telegram.call_bot(BOT_KEY, "getUpdates", {}, [])
    assert (caught.value.code, str(caught.value)) == (502, "HTTP 502")


def test_real_post_sends_multipart(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    seen: dict[str, Any] = {}

    def accept(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        seen["type"] = request.headers["content-type"]
        seen["body"] = request.read()
        return httpx.Response(200, json={"ok": True, "result": {"message_id": 5, "chat": {"id": 42, "type": "private"}}})

    use_transport(monkeypatch, accept)
    attachment = tmp_path / "a b.txt"
    attachment.write_bytes(b"payload")
    result = _telegram.call_bot(BOT_KEY, "sendDocument", {"chat_id": "42"}, [("document", attachment)])
    assert result == {"message_id": 5, "chat": {"id": 42, "type": "private"}}
    assert seen["url"] == f"https://api.telegram.org/bot{BOT_KEY}/sendDocument"
    assert seen["type"].startswith("multipart/form-data; boundary=")
    assert b'name="chat_id"\r\n\r\n42' in seen["body"]
    assert b'name="document"; filename="a b.txt"' in seen["body"]
    assert b"payload" in seen["body"]


def test_plain_post_is_form_encoded(monkeypatch: pytest.MonkeyPatch) -> None:
    seen: dict[str, Any] = {}

    def accept(request: httpx.Request) -> httpx.Response:
        seen["type"] = request.headers["content-type"]
        seen["body"] = request.read()
        return httpx.Response(200, json={"ok": True, "result": True})

    use_transport(monkeypatch, accept)
    assert _telegram.call_bot(BOT_KEY, "getMe", {"chat_id": "42"}, []) is True
    assert seen == {"type": "application/x-www-form-urlencoded", "body": b"chat_id=42"}


@pytest.mark.usefixtures("bot_folder")
def test_cli_send_and_react(monkeypatch: pytest.MonkeyPatch) -> None:
    post = FakePost()
    monkeypatch.setattr(_telegram, "call_bot", post)
    assert run(["telegram", "send", "--channel", "main", "--chat", "42", "--text", "hi", "--file", "x.txt", "--reply-to", "3"]) == 0
    assert [call[1] for call in post.calls] == ["sendMessage", "sendDocument"]
    assert run(["telegram", "react", "--channel", "main", "--chat", "42", "--message", "3", "--emoji", "x"]) == 0


def test_http_layer_errors_never_show_the_token(monkeypatch: pytest.MonkeyPatch) -> None:
    def invalid(request: httpx.Request) -> httpx.Response:
        raise httpx.InvalidURL(f"URL can't contain control characters. {request.url!r}")

    use_transport(monkeypatch, invalid)
    with pytest.raises(TelegramError) as caught:
        _telegram.call_bot(BOT_KEY, "getUpdates", {}, [])
    assert BOT_KEY not in str(caught.value)
    assert caught.value.__cause__ is None
    assert caught.value.__context__ is None


def test_a_description_that_echoes_the_token_reports_the_status_only(monkeypatch: pytest.MonkeyPatch) -> None:
    echo = f"Not Found: /bot{BOT_KEY}/getUpdates"
    use_transport(monkeypatch, lambda _request: httpx.Response(404, json={"ok": False, "error_code": 404, "description": echo}))
    with pytest.raises(TelegramError) as caught:
        _telegram.call_bot(BOT_KEY, "getUpdates", {}, [])
    assert (caught.value.code, str(caught.value)) == (404, "HTTP 404")
    use_transport(monkeypatch, lambda _request: httpx.Response(200, json={"ok": False, "error_code": 400, "description": echo}))
    with pytest.raises(TelegramError) as caught:
        _telegram.call_bot(BOT_KEY, "getUpdates", {}, [])
    assert (caught.value.code, str(caught.value)) == (400, "request failed")


class Collector(logging.Handler):
    def __init__(self) -> None:
        super().__init__(logging.DEBUG)
        self.records: list[logging.LogRecord] = []

    def emit(self, record: logging.LogRecord) -> None:
        self.records.append(record)


def respond(request: httpx.Request, status: int, body: dict[str, Any], headers: Optional[dict[str, str]] = None) -> httpx.Response:
    # What httpcore would log at DEBUG for this exchange, since the mock transport skips httpcore.
    logging.getLogger("httpcore.http11").debug("receive_response_headers.complete %s", request.url)
    return httpx.Response(status, json=body, headers=headers)


@pytest.mark.parametrize("case", ["success", "http error", "network error", "location echo"])
def test_http_loggers_are_silent_during_a_telegram_call_and_restored_after(monkeypatch: pytest.MonkeyPatch, case: str) -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if case == "network error":
            logging.getLogger("httpcore.connection").debug("connect_tcp.failed %s", request.url)
            raise httpx.ConnectError("no route", request=request)
        if case == "http error":
            return respond(request, 409, {"ok": False, "error_code": 409, "description": "Conflict"})
        headers = {"Location": str(request.url)} if case == "location echo" else None
        return respond(request, 200, {"ok": True, "result": True}, headers)

    use_transport(monkeypatch, handler)
    collector = Collector()
    root = logging.getLogger()
    monkeypatch.setattr(root, "level", logging.DEBUG)
    root.addHandler(collector)
    httpx_logger = logging.getLogger("httpx")
    monkeypatch.setattr(httpx_logger, "level", logging.DEBUG)
    child = logging.getLogger("httpcore.http11")
    before = [(logger.level, logger.propagate) for logger in (httpx_logger, logging.getLogger("httpcore"), child)]
    try:
        with contextlib.suppress(TelegramError):
            _telegram.call_bot(BOT_KEY, "getUpdates", {}, [])
        assert [record for record in collector.records if record.name.startswith(("httpx", "httpcore"))] == []
        assert before == [(logger.level, logger.propagate) for logger in (httpx_logger, logging.getLogger("httpcore"), child)]
        logging.getLogger("httpx").info("after the call")
        assert [record.getMessage() for record in collector.records] == ["after the call"]
    finally:
        root.removeHandler(collector)


def test_a_malformed_result_in_a_successful_reply_hides_the_token() -> None:
    with pytest.raises(TelegramError) as caught:
        _telegram._sent({"message_id": BOT_KEY, "chat": BOT_KEY}, "sendMessage")
    assert BOT_KEY not in str(caught.value)
    assert (caught.value.__cause__, caught.value.__context__) == (None, None)


@pytest.mark.parametrize("token", ["no-colon", "123456:has space", "abc:def", "123456:"])
def test_malformed_token_is_refused_before_use(bot_folder: Path, capsys: pytest.CaptureFixture[str], token: str) -> None:
    (bot_folder / ".env").write_text(f"TELEGRAM_BOT_TOKEN={token}\n", encoding="utf-8")
    post = FakePost()
    assert _telegram.send("main", "42", "hi", "text", None, [], post=post) == 1
    error = capsys.readouterr().err
    assert "wrong format" in error
    assert token not in error
    assert post.calls == []


def test_access_file_round_trips_with_the_plugin_fields_it_does_not_use() -> None:
    text = json.dumps({"dmPolicy": "allowlist", "allowFrom": ["42"], "groups": {"-100": {"requireMention": True, "allowFrom": []}}, "pending": {}, "ackReaction": "👀"})
    access = Access.model_validate_json(text)
    assert (access.dm_policy, access.allow_from) == ("allowlist", ["42"])
    assert json.loads(access.model_dump_json(by_alias=True)) == json.loads(text)


def test_access_defaults_match_the_plugin() -> None:
    access = Access.model_validate_json("{}")
    assert (access.dm_policy, access.allow_from) == ("pairing", [])


@pytest.mark.usefixtures("bot_folder")
def test_send_refuses_a_reply_that_is_not_a_message(capsys: pytest.CaptureFixture[str]) -> None:
    def post(_token: str, _method: str, _fields: dict[str, str], _files: list[tuple[str, Path]]) -> JsonValue:
        return True

    assert _telegram.send("main", "42", "hi", "text", None, [], post=post) == 1
    assert capsys.readouterr().err == "telegram: Telegram sent an unexpected reply to sendMessage\n"
