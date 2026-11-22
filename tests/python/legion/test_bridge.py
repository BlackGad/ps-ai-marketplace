import json
import os
from pathlib import Path
from typing import Any, Optional

import pytest

from legion import _bridge
from legion._telegram import TelegramError

BOT_KEY = "123456:secret-token"


@pytest.fixture
def bot_folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    folder = tmp_path / ".legion" / "channels" / "telegram" / "main"
    folder.mkdir(parents=True)
    (folder / ".env").write_text(f"TELEGRAM_BOT_TOKEN={BOT_KEY}\n", encoding="utf-8")
    (folder / "access.json").write_text(json.dumps({"dmPolicy": "allowlist", "allowFrom": ["42"], "groups": {}}), encoding="utf-8")
    return folder


def update(update_id: int, sender: int = 42, chat_type: str = "private", text: Optional[str] = "hello") -> dict[str, Any]:
    message: dict[str, Any] = {
        "message_id": update_id * 10,
        "chat": {"id": sender, "type": chat_type},
        "from": {"id": sender, "first_name": "Ann", "username": "ann"},
    }
    if text is not None:
        message["text"] = text
    return {"update_id": update_id, "message": message}


class Script:
    """Fake Bot API: each getUpdates call returns the next scripted reply; an exception reply is raised."""

    def __init__(self, *replies: Any) -> None:
        self.replies = list(replies)
        self.calls: list[dict[str, str]] = []

    def __call__(self, token: str, method: str, fields: dict[str, str], files: list[tuple[str, Path]]) -> Any:
        assert (token, method) == (BOT_KEY, "getUpdates")
        self.calls.append(fields)
        reply = self.replies.pop(0)
        if isinstance(reply, BaseException):
            raise reply
        return reply


def run(repo: Path, script: Script, delivered: list[tuple[str, str]], alive: Any = lambda _pid: False, sleeps: Optional[list[float]] = None) -> int:
    def deliver(_repo: Path, sender: str, text: str) -> None:
        delivered.append((sender, text))

    pauses = sleeps if sleeps is not None else []
    return _bridge.run("main", repo, post=script, alive=alive, deliver=deliver, sleep=pauses.append)


@pytest.mark.usefixtures("bot_folder")
def test_delivers_only_allowlisted_private_text(tmp_path: Path) -> None:
    delivered: list[tuple[str, str]] = []
    batch = [update(1), update(2, sender=7), update(3, chat_type="group"), update(4, text=None), update(5, text="")]
    assert run(tmp_path, Script(batch, KeyboardInterrupt()), delivered) == 0
    assert delivered == [("telegram", "telegram chat_id=42 message_id=10 user=ann\nhello")]


@pytest.mark.usefixtures("bot_folder")
def test_advances_offset_and_polls_with_timeout(tmp_path: Path) -> None:
    script = Script([update(5), update(9, sender=7)], [], KeyboardInterrupt())
    run(tmp_path, script, [])
    assert script.calls[0] == {"timeout": "30", "allowed_updates": '["message"]'}
    assert script.calls[1]["offset"] == "10"
    assert script.calls[2]["offset"] == "10"


@pytest.mark.usefixtures("bot_folder")
def test_name_falls_back_to_first_name(tmp_path: Path) -> None:
    delivered: list[tuple[str, str]] = []
    item = update(1)
    del item["message"]["from"]["username"]
    run(tmp_path, Script([item], KeyboardInterrupt()), delivered)
    assert delivered[0][1].startswith("telegram chat_id=42 message_id=10 user=Ann\n")


def test_conflict_exits_with_one_line(bot_folder: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    script = Script(TelegramError("Conflict: terminated by other getUpdates request", 409))
    assert run(tmp_path, script, []) == 1
    assert capsys.readouterr().err == "telegram: another program is polling this bot (Conflict: terminated by other getUpdates request)\n"
    assert not (bot_folder / "bridge.pid").exists()


@pytest.mark.usefixtures("bot_folder")
def test_network_errors_back_off_and_retry(tmp_path: Path) -> None:
    sleeps: list[float] = []
    script = Script(TelegramError("network error", 0), TelegramError("Bad Gateway", 502), [update(1)], KeyboardInterrupt())
    delivered: list[tuple[str, str]] = []
    assert run(tmp_path, script, delivered, sleeps=sleeps) == 0
    assert sleeps == [1, 2]
    assert len(delivered) == 1


@pytest.mark.parametrize("name", ["bridge.pid", "bot.pid"])
def test_refuses_when_another_poller_is_alive(bot_folder: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str], name: str) -> None:
    (bot_folder / name).write_text("4242", encoding="utf-8")
    script = Script()
    assert run(tmp_path, script, [], alive=lambda pid: pid == 4242) == 1
    assert "already polling" in capsys.readouterr().err
    assert script.calls == []
    assert (bot_folder / name).exists()


def test_stale_pid_files_do_not_block_and_pid_file_is_removed(bot_folder: Path, tmp_path: Path) -> None:
    (bot_folder / "bridge.pid").write_text("4242", encoding="utf-8")
    (bot_folder / "bot.pid").write_text("not a number", encoding="utf-8")
    seen: list[str] = []

    class Peek(Script):
        def __call__(self, token: str, method: str, fields: dict[str, str], files: list[tuple[str, Path]]) -> Any:
            seen.append((bot_folder / "bridge.pid").read_text(encoding="utf-8"))
            return super().__call__(token, method, fields, files)

    assert run(tmp_path, Peek(KeyboardInterrupt()), []) == 0
    assert seen[0] == str(os.getpid())
    assert not (bot_folder / "bridge.pid").exists()


def test_missing_bot_folder_is_plain_error(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    assert run(tmp_path, Script(), []) == 1
    assert "no bot token" in capsys.readouterr().err


def test_process_alive_for_this_process_only() -> None:
    assert _bridge.process_alive(os.getpid())
    assert not _bridge.process_alive(0)
