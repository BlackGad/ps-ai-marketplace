import builtins
import io
import json
import os
import stat
import sys
from pathlib import Path
from typing import Any

import pytest
from cli_runner import run

from legion import _channel
from legion._home import settings_path

SETUP = "run /telegram:configure in that session"


@pytest.fixture
def home(tmp_path: Path) -> Path:
    (tmp_path / "claude1-config").mkdir()
    path = settings_path(tmp_path)
    path.parent.mkdir(parents=True)
    agents = [
        {"id": "claude1", "tool": "claude", "configDir": str(tmp_path / "claude1-config")},
        {"id": "codex1", "tool": "codex", "configDir": "~/codex1-config"},
        {"id": "copilot1", "tool": "copilot", "configDir": "~/copilot1-config"},
        {
            "id": "claude-foundry",
            "tool": "claude",
            "configDir": "~/f-config",
            "provider": {"kind": "foundry", "endpoint": "https://example.cognitiveservices.azure.com", "default": "a", "deployments": [{"name": "a"}]},
        },
    ]
    path.write_text(json.dumps({"schemaVersion": 1, "agents": agents, "channels": []}), encoding="utf-8")
    return tmp_path


def legion(home: Path, *words: str) -> int:
    return run(["--home", str(home), "channel", *words])


def add_words(target: str = "123", *accounts: str) -> list[str]:
    words = ["add", "--id", "my-telegram", "--kind", "telegram", "--target", target]
    for account in accounts or ("claude1",):
        words += ["--account", account]
    return words


def saved_channels(home: Path) -> list[dict[str, Any]]:
    return json.loads(settings_path(home).read_text(encoding="utf-8"))["channels"]


def test_add_saves_a_binding_and_a_repeat_skips(home: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert legion(home, *add_words("123", "claude1", "codex1")) == 0
    assert capsys.readouterr().out == "added: channel my-telegram\n"
    assert saved_channels(home) == [{"id": "my-telegram", "kind": "telegram", "target": "123", "accounts": ["claude1", "codex1"]}]
    before = settings_path(home).read_bytes()
    assert legion(home, *add_words("123", "claude1", "codex1")) == 0
    assert capsys.readouterr().out == "skip: channel my-telegram (already done)\n"
    assert settings_path(home).read_bytes() == before


@pytest.mark.parametrize(
    ("words", "message"),
    [
        (add_words("999"), "channel my-telegram exists with other values; remove it first"),
        (add_words("123", "codex1", "claude1"), "channel my-telegram exists with other values; remove it first"),
        (["add", "--id", "other", "--kind", "telegram", "--target", "1", "--account", "nobody"], "unknown account 'nobody'"),
        (["add", "--id", "other", "--kind", "telegram", "--target", "1", "--account", "copilot1"], "account 'copilot1' uses copilot, which telegram does not support"),
        (
            ["add", "--id", "other", "--kind", "telegram", "--target", "1", "--account", "claude-foundry"],
            "account 'claude-foundry' runs through Foundry: channels are not available on third-party providers",
        ),
        (["add", "--id", "Bad_Id", "--kind", "telegram", "--target", "1", "--account", "claude1"], "id 'Bad_Id' must match ^[a-z][a-z0-9-]*$"),
        (["add", "--id", "other", "--kind", "pigeon", "--target", "1", "--account", "claude1"], "unknown channel kind 'pigeon'"),
    ],
    ids=["other target", "other accounts", "unknown account", "unsupported tool", "Foundry account", "bad id", "unknown kind"],
)
def test_add_refusals_print_one_line_and_change_nothing(home: Path, capsys: pytest.CaptureFixture[str], words: list[str], message: str) -> None:
    assert legion(home, *add_words()) == 0
    capsys.readouterr()
    before = settings_path(home).read_bytes()
    assert legion(home, *words) == 1
    output = capsys.readouterr()
    assert (output.out, output.err) == ("", message + "\n")
    assert settings_path(home).read_bytes() == before


def test_remove_and_its_repeat(home: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert legion(home, *add_words()) == 0
    capsys.readouterr()
    assert legion(home, "remove", "--id", "my-telegram") == 0
    assert capsys.readouterr().out == "removed: channel my-telegram\n"
    assert saved_channels(home) == []
    before = settings_path(home).read_bytes()
    assert legion(home, "remove", "--id", "my-telegram") == 0
    assert capsys.readouterr().out == "skip: channel remove my-telegram (already done)\n"
    assert settings_path(home).read_bytes() == before


@pytest.mark.parametrize("words", [["add", "--kind", "telegram"], ["remove", "my-telegram"], ["check", "--account", "claude1"]], ids=["add", "remove", "check"])
def test_ids_and_kinds_are_named_options(home: Path, words: list[str]) -> None:
    assert legion(home, *words) == 2


@pytest.mark.parametrize("words", [add_words(), ["remove", "--id", "my-telegram"], ["check", "--kind", "telegram", "--account", "claude1"]], ids=["add", "remove", "check"])
def test_verbs_without_settings_refuse(tmp_path: Path, capsys: pytest.CaptureFixture[str], words: list[str]) -> None:
    assert legion(tmp_path, *words) == 1
    assert capsys.readouterr().err == "No legion settings yet; add an agent first.\n"
    assert not settings_path(tmp_path).exists()


def fake_bun(folder: Path) -> Path:
    folder.mkdir()
    path = folder / ("bun.cmd" if sys.platform == "win32" else "bun")
    path.write_text("@exit /b 99\r\n" if sys.platform == "win32" else "#!/bin/sh\nexit 99\n", encoding="utf-8")
    path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


def test_check_reports_bun_and_each_account_plugin(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    bun = fake_bun(home / "fake-bin")
    monkeypatch.setenv("PATH", str(bun.parent))
    assert _channel.check(home, "telegram", ["claude1", "codex1", "copilot1"]) == [
        "bun        found",
        "claude1    telegram plugin not found",
        "codex1     telegram plugin not needed",
        "copilot1   not supported (telegram supports: claude, codex)",
    ]
    (home / "claude1-config/plugins/cache/claude-plugins-official/telegram").mkdir(parents=True)
    bun.unlink()
    assert _channel.check(home, "telegram", ["claude1"]) == ["bun        not found", "claude1    telegram plugin found"]


def test_check_refuses_an_unknown_account(home: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert legion(home, "check", "--kind", "telegram", "--account", "nobody") == 1
    assert capsys.readouterr().err == "unknown account 'nobody'\n"


def test_write_failure_prints_one_stderr_line_and_preserves_settings(home: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    before = settings_path(home).read_bytes()

    def fail_replace(_source: object, _target: object) -> None:
        raise OSError("disk write failed\ntry again")

    monkeypatch.setattr(os, "replace", fail_replace)
    assert legion(home, *add_words()) == 1
    output = capsys.readouterr()
    assert (output.out, output.err) == ("", "disk write failed try again\n")
    assert settings_path(home).read_bytes() == before
    assert list(settings_path(home).parent.iterdir()) == [settings_path(home)]


# Any open of the token file fails the test; existence checks only stat it.
def guard_token_file(monkeypatch: pytest.MonkeyPatch, token: Path) -> None:
    def refuse(path: object) -> None:
        if isinstance(path, (str, os.PathLike)) and Path(path).absolute() == token:
            pytest.fail("the token file was opened")

    real_open, real_os_open = builtins.open, os.open

    def guarded_open(file: Any, *args: Any, **kwargs: Any) -> Any:
        refuse(file)
        return real_open(file, *args, **kwargs)

    def guarded_os_open(path: Any, *args: Any, **kwargs: Any) -> int:
        refuse(path)
        return real_os_open(path, *args, **kwargs)

    monkeypatch.setattr(builtins, "open", guarded_open)
    monkeypatch.setattr(io, "open", guarded_open)
    monkeypatch.setattr(os, "open", guarded_os_open)


def test_check_reports_each_bot_folder_without_opening_the_token(home: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setenv("PATH", str(home / "empty"))
    assert legion(home, *add_words()) == 0
    capsys.readouterr()
    folder = home / ".legion/channels/telegram/my-telegram"
    token = folder / ".env"
    missing = f"my-telegram bot folder: missing token ({SETUP})"
    assert _channel.check(home, "telegram", ["claude1"])[-1] == missing
    folder.mkdir(parents=True)
    assert _channel.check(home, "telegram", ["claude1"])[-1] == missing
    token.write_bytes(b"fixture")
    guard_token_file(monkeypatch, token)
    assert legion(home, "check", "--kind", "telegram", "--account", "claude1") == 0
    output = capsys.readouterr().out
    assert output.splitlines()[-1] == "my-telegram bot folder: ready"
    assert "fixture" not in output
