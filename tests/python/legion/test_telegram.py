import io
import json
import urllib.error
from pathlib import Path
from typing import Any, Optional

import pytest

from legion import _cli, _telegram
from legion._telegram import TelegramError

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
        return {"message_id": 100 + len(self.calls)}


@pytest.mark.usefixtures("bot_folder")
def test_send_text_with_format_and_reply(capsys: pytest.CaptureFixture[str]) -> None:
    post = FakePost()
    assert _telegram.send("main", "42", "hi", "markdownv2", 7, [], post=post) == 0
    token, method, fields, files = post.calls[0]
    assert (token, method, files) == (BOT_KEY, "sendMessage", [])
    assert fields == {"chat_id": "42", "text": "hi", "parse_mode": "MarkdownV2", "reply_parameters": '{"message_id": 7}'}
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


def test_real_post_hides_token_in_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    def refuse(request: Any, **_options: Any) -> Any:
        body = io.BytesIO(json.dumps({"ok": False, "error_code": 409, "description": "Conflict"}).encode())
        raise urllib.error.HTTPError(request.full_url, 409, "Conflict", None, body)  # pyright: ignore[reportArgumentType]

    monkeypatch.setattr(_telegram._opener, "open", refuse)
    with pytest.raises(TelegramError) as caught:
        _telegram._post(BOT_KEY, "getUpdates", {}, [])
    assert (caught.value.code, str(caught.value)) == (409, "Conflict")

    def offline(*_arguments: Any, **_options: Any) -> Any:
        raise urllib.error.URLError("no route")

    monkeypatch.setattr(_telegram._opener, "open", offline)
    with pytest.raises(TelegramError) as caught:
        _telegram._post(BOT_KEY, "getUpdates", {}, [])
    assert caught.value.code == 0
    assert BOT_KEY not in str(caught.value)


def test_real_post_sends_multipart(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    seen: dict[str, Any] = {}

    def accept(request: Any, **_options: Any) -> Any:
        seen["url"] = request.full_url
        seen["type"] = request.get_header("Content-type")
        seen["body"] = request.data
        return io.BytesIO(b'{"ok": true, "result": {"message_id": 5}}')

    monkeypatch.setattr(_telegram._opener, "open", accept)
    attachment = tmp_path / "a b.txt"
    attachment.write_bytes(b"payload")
    result = _telegram._post(BOT_KEY, "sendDocument", {"chat_id": "42"}, [("document", attachment)])
    assert result == {"message_id": 5}
    assert seen["url"] == f"https://api.telegram.org/bot{BOT_KEY}/sendDocument"
    assert seen["type"].startswith("multipart/form-data; boundary=")
    assert b'name="chat_id"\r\n\r\n42' in seen["body"]
    assert b'name="document"; filename="a b.txt"' in seen["body"]
    assert b"payload" in seen["body"]


@pytest.mark.usefixtures("bot_folder")
def test_cli_send_and_react(monkeypatch: pytest.MonkeyPatch) -> None:
    post = FakePost()
    monkeypatch.setattr(_telegram, "_post", post)
    assert _cli.main(["telegram", "send", "--channel", "main", "--chat", "42", "--text", "hi", "--file", "x.txt", "--reply-to", "3"]) == 0
    assert [call[1] for call in post.calls] == ["sendMessage", "sendDocument"]
    assert _cli.main(["telegram", "react", "--channel", "main", "--chat", "42", "--message", "3", "--emoji", "x"]) == 0
