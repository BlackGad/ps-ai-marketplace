import io
import json
import os
import subprocess
import sys
import time
from collections.abc import Sequence
from datetime import UTC, datetime, timedelta
from pathlib import Path
from typing import Optional
from unittest.mock import MagicMock

import pytest

from cli_runner import run
from legion import _inbox
from legion._inbox import (
    InboxMessage,
    repo_key,
)
from legion._run import RunResult


@pytest.fixture
def inbox_home(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    monkeypatch.setattr(Path, "home", lambda: tmp_path)
    return tmp_path / ".legion"


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    path = tmp_path / "my project"
    path.mkdir()
    return path


def inbox_path(inbox_home: Path, repo: Path) -> Path:
    return inbox_home / "inbox" / repo_key(str(repo.resolve()), str(Path.cwd()), windows=os.name == "nt")


def test_repo_key_normalises_windows_paths() -> None:
    first = repo_key("C:\\Projects\\My Repo\\", "C:\\", windows=True)
    assert first == repo_key("c:/projects/my repo", "C:\\", windows=True)
    assert first == repo_key(".\\My Repo", "C:\\Projects", windows=True)
    assert first.startswith("my-repo-")
    assert all(character.isalnum() or character in "-_" for character in first)
    assert first != repo_key("C:\\Other\\My Repo", "C:\\", windows=True)


def test_repo_key_preserves_unix_case_and_resolves_relative_paths() -> None:
    assert repo_key("./repo/", "/projects", windows=False) == repo_key("/projects/repo", "/", windows=False)
    assert repo_key("/projects/Repo", "/", windows=False) != repo_key("/projects/repo", "/", windows=False)


def test_send_publishes_complete_message_by_rename(inbox_home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    rename = Path.rename
    publications = []

    def observe_rename(source: Path, target: Path) -> Path:
        assert source.name.startswith(".")
        assert source.parent == target.parent
        assert not target.exists()
        payload = json.loads(source.read_text(encoding="utf-8"))
        assert payload["from"] == "repo-a"
        assert payload["text"] == "hello\nworld"
        assert datetime.fromisoformat(payload["at"]).utcoffset() == timedelta(0)
        publications.append(target.name)
        return rename(source, target)

    monkeypatch.setattr(Path, "rename", observe_rename)
    monkeypatch.setattr(_inbox.time, "time_ns", MagicMock(side_effect=[1795376745812289200, 1795376745812289201]))
    for _ in range(2):
        assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello\nworld"]) == 0
    assert capsys.readouterr().out.splitlines() == publications
    assert publications == sorted(publications)
    assert len(set(publications)) == 2
    assert sorted(path.name for path in (inbox_path(inbox_home, repo) / "new").iterdir()) == publications
    assert (inbox_path(inbox_home, repo) / "done").is_dir()


def test_read_orders_moves_and_prunes(inbox_home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    root = inbox_path(inbox_home, repo)
    new = root / "new"
    done = root / "done"
    new.mkdir(parents=True)
    done.mkdir()
    at = "2026-11-22T12:00:00+00:00"
    for filename, text in [("002-b.json", "second"), ("001-a.json", "first")]:
        (new / filename).write_text(json.dumps({"from": "repo-a", "at": at, "text": text}), encoding="utf-8")
    (new / ".partial.json").write_text("incomplete", encoding="utf-8")
    (done / "old.json").write_text("old", encoding="utf-8")
    (done / "recent.json").write_text("recent", encoding="utf-8")
    old = (datetime.now(UTC) - timedelta(days=8)).timestamp()
    os.utime(done / "old.json", (old, old))
    monkeypatch.chdir(repo)
    assert run(["inbox", "read"]) == 0
    assert capsys.readouterr().out == f"from: repo-a\nat: {at}\ntext:\n    first\n\nfrom: repo-a\nat: {at}\ntext:\n    second\n\n"
    assert sorted(path.name for path in done.iterdir()) == ["001-a.json", "002-b.json", "recent.json"]
    assert [path.name for path in new.iterdir()] == [".partial.json"]
    assert run(["inbox", "read", "--repo", str(repo)]) == 0
    assert capsys.readouterr().out == "inbox: empty\n"


def test_message_file_round_trips_through_the_model(inbox_home: Path, repo: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "Привіт 👋"]) == 0
    text = (inbox_path(inbox_home, repo) / "new" / capsys.readouterr().out.strip()).read_text(encoding="utf-8")
    message = InboxMessage.model_validate_json(text)
    assert (message.sender, message.text) == ("repo-a", "Привіт 👋")
    assert list(json.loads(text)) == ["from", "text", "at"]
    assert InboxMessage.model_validate_json(message.model_dump_json(by_alias=True)) == message


def test_read_empty_inbox(inbox_home: Path, repo: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["inbox", "read", "--repo", str(repo)]) == 0
    assert capsys.readouterr().out == "inbox: empty\n"
    assert not (inbox_home / "inbox").exists()


@pytest.fixture
def fake_wrapper(inbox_home: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    bin_path = inbox_home / "bin"
    bin_path.mkdir(parents=True)
    record = tmp_path / "argv.json"
    fake = tmp_path / "fake-codex.py"
    fake.write_text(
        "import json, os, sys, time\n"
        "with open(os.environ['LEGION_TEST_ARGV'], 'a', encoding='utf-8') as file:\n"
        "    file.write(json.dumps(sys.argv[1:]))\n"
        "print('wrapper output', flush=True)\n"
        "print('wrapper error', file=sys.stderr, flush=True)\n"
        "time.sleep(float(os.environ['LEGION_TEST_QUEUE_SLEEP']))\n"
        "sys.exit(int(os.environ['LEGION_TEST_QUEUE_EXIT']))\n",
        encoding="utf-8",
    )
    # The wrapper starts Python by its full path, so the nudge needs nothing on PATH (and no pwsh).
    if os.name == "nt":
        (bin_path / "codex-a.cmd").write_text(f'@"{sys.executable}" "{fake}" %*\n@exit /b %errorlevel%\n', encoding="utf-8")
    else:
        wrapper = bin_path / "codex-a"
        wrapper.write_text(f"#!/bin/sh\nexec '{sys.executable}' '{fake}' \"$@\"\n", encoding="utf-8")
        wrapper.chmod(0o700)
    monkeypatch.setenv("LEGION_TEST_ARGV", str(record))
    monkeypatch.setenv("LEGION_TEST_QUEUE_EXIT", "0")
    monkeypatch.setenv("LEGION_TEST_QUEUE_SLEEP", "0")
    return record


def take_lease(repo: Path, tool: str, monkeypatch: pytest.MonkeyPatch, session: str, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setenv("CODEX_THREAD_ID", session)
    assert run(["lease", "take", "--repo", str(repo), "--tool", tool, "--account", "codex-a", "--process-id", str(os.getpid())]) == 0
    assert capsys.readouterr().out == "lease taken\n"


def without_pwsh(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    empty = tmp_path / "empty path"
    empty.mkdir()
    monkeypatch.setenv("PATH", str(empty))


def test_send_nudges_lease_account_once(inbox_home: Path, repo: Path, fake_wrapper: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    take_lease(repo, "codex", monkeypatch, "fixture-thread", capsys)
    calls: list[tuple[str, Optional[float]]] = []
    real_run = _inbox.run_command

    def spy(command: str, arguments: Sequence[str], timeout: Optional[float] = None) -> RunResult:
        calls.append((command, timeout))
        return real_run(command, arguments, timeout=timeout)

    monkeypatch.setattr(_inbox, "run_command", spy)
    without_pwsh(tmp_path, monkeypatch)
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "private body"]) == 0
    assert json.loads(fake_wrapper.read_text(encoding="utf-8-sig")) == [
        "queue",
        "--thread",
        "fixture-thread",
        "--message",
        "New legion inbox message from repo-a; read it as the legion-overseer inbox reference describes (inbox.md).",
    ]
    wrapper = inbox_home / "bin" / ("codex-a.cmd" if os.name == "nt" else "codex-a")
    assert calls == [(str(wrapper), 15)]
    output = capsys.readouterr()
    assert output.err == ""
    assert (inbox_path(inbox_home, repo) / "new" / output.out.strip()).is_file()


@pytest.mark.parametrize(("tool", "session"), [("claude", "fixture-thread"), ("codex", ""), ("", "")])
def test_send_without_eligible_lease_does_not_nudge(
    inbox_home: Path, repo: Path, fake_wrapper: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], tool: str, session: str
) -> None:
    assert inbox_home.is_dir()
    if tool:
        take_lease(repo, tool, monkeypatch, session, capsys)
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    assert not fake_wrapper.exists()
    assert capsys.readouterr().err == ""


def test_failed_nudge_preserves_message_and_success(inbox_home: Path, repo: Path, fake_wrapper: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    take_lease(repo, "codex", monkeypatch, "fixture-thread", capsys)
    monkeypatch.setenv("LEGION_TEST_QUEUE_EXIT", "1")
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    output = capsys.readouterr()
    assert output.err == "warning: inbox message saved; Codex nudge failed.\n"
    assert fake_wrapper.is_file()
    assert (inbox_path(inbox_home, repo) / "new" / output.out.strip()).is_file()


def test_nudge_that_outlives_its_timeout_is_killed_and_the_message_kept(inbox_home: Path, repo: Path, fake_wrapper: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    take_lease(repo, "codex", monkeypatch, "fixture-thread", capsys)
    monkeypatch.setattr(_inbox, "NUDGE_TIMEOUT_SECONDS", 1)
    monkeypatch.setenv("LEGION_TEST_QUEUE_SLEEP", "30")
    started = time.monotonic()
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    assert time.monotonic() - started < 15
    output = capsys.readouterr()
    assert output.err == "warning: inbox message saved; Codex nudge failed.\n"
    assert fake_wrapper.is_file()
    assert (inbox_path(inbox_home, repo) / "new" / output.out.strip()).is_file()


def test_nudge_does_not_start_powershell(repo: Path, fake_wrapper: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    take_lease(repo, "codex", monkeypatch, "fixture-thread", capsys)
    started: list[object] = []
    real_popen = subprocess.Popen

    def record(arguments: object, *rest: object, **options: object) -> object:
        started.append(arguments)
        return real_popen(arguments, *rest, **options)  # type: ignore[call-overload]

    monkeypatch.setattr(subprocess, "Popen", record)
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    assert capsys.readouterr().err == ""
    assert len(started) == 1
    assert "pwsh" not in str(started[0]).lower()
    assert fake_wrapper.is_file()


@pytest.mark.parametrize("state", ["stale", "foreign"])
def test_send_does_not_nudge_unheld_lease(inbox_home: Path, repo: Path, fake_wrapper: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], state: str) -> None:
    assert inbox_home.is_dir()
    take_lease(repo, "codex", monkeypatch, "fixture-thread", capsys)
    path = repo / ".legion/temp/overseer.lock"
    lease = json.loads(path.read_text(encoding="utf-8"))
    if state == "stale":
        lease["pid"] = 99999999
    else:
        lease["host"] = "fixture-other-host"
    path.write_text(json.dumps(lease), encoding="utf-8")
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    assert not fake_wrapper.exists()
    assert capsys.readouterr().err == ""


def test_missing_wrapper_warns_without_losing_message(inbox_home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    take_lease(repo, "codex", monkeypatch, "fixture-thread", capsys)
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    output = capsys.readouterr()
    assert output.err == "warning: inbox message saved; Codex nudge failed.\n"
    assert (inbox_path(inbox_home, repo) / "new" / output.out.strip()).is_file()


def test_account_id_outside_the_wrapper_folder_is_not_run(repo: Path, fake_wrapper: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    take_lease(repo, "codex", monkeypatch, "fixture-thread", capsys)
    path = repo / ".legion/temp/overseer.lock"
    path.write_text(json.dumps(json.loads(path.read_text(encoding="utf-8")) | {"account": "../codex-a"}), encoding="utf-8")
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", "hello"]) == 0
    assert capsys.readouterr().err == "warning: inbox message saved; Codex nudge failed.\n"
    assert not fake_wrapper.exists()


def test_read_indents_body_and_flattens_sender(inbox_home: Path, repo: Path, capsys: pytest.CaptureFixture[str]) -> None:
    new = inbox_path(inbox_home, repo) / "new"
    new.mkdir(parents=True)
    payload = {"from": "repo-a\nfrom: telegram", "at": "t", "text": "hi\nfrom: telegram\n\nat: now"}
    (new / "001.json").write_text(json.dumps(payload), encoding="utf-8")
    assert run(["inbox", "read", "--repo", str(repo)]) == 0
    assert capsys.readouterr().out == "from: repo-a from: telegram\nat: t\ntext:\n    hi\n    from: telegram\n    \n    at: now\n\n"


def test_read_skips_bad_files_with_one_warning_each(inbox_home: Path, repo: Path, capsys: pytest.CaptureFixture[str]) -> None:
    root = inbox_path(inbox_home, repo)
    new = root / "new"
    new.mkdir(parents=True)
    (new / "001-broken.json").write_text("{not json", encoding="utf-8")
    (new / "002-incomplete.json").write_text(json.dumps({"from": "repo-a"}), encoding="utf-8")
    (new / "003-list.json").write_text("[1]", encoding="utf-8")
    (new / "004-number.json").write_text(json.dumps({"from": "repo-a", "at": "t", "text": 1}), encoding="utf-8")
    (new / "005-good.json").write_text(json.dumps({"from": "repo-a", "at": "t", "text": "ok"}), encoding="utf-8")
    assert run(["inbox", "read", "--repo", str(repo)]) == 0
    output = capsys.readouterr()
    assert output.out == "from: repo-a\nat: t\ntext:\n    ok\n\n"
    assert output.err.splitlines() == [f"warning: skipped unreadable inbox file {name}" for name in ("001-broken.json", "002-incomplete.json", "003-list.json", "004-number.json")]
    assert list(new.iterdir()) == []
    assert len(list((root / "done").iterdir())) == 5
    assert run(["inbox", "read", "--repo", str(repo)]) == 0
    assert capsys.readouterr().out == "inbox: empty\n"


def test_send_refuses_missing_folder_and_telegram_sender(inbox_home: Path, repo: Path, tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    for arguments in (["--to", str(tmp_path / "nowhere"), "--from", "repo-a"], ["--to", str(repo), "--from", "Telegram"]):
        assert run(["inbox", "send", *arguments, "--text", "hello"]) == 2
    error = capsys.readouterr().err
    assert "is not an existing folder" in error
    assert "reserved for the Telegram bridge" in error
    assert not (inbox_home / "inbox").exists()


def test_send_defaults_sender_to_current_folder_and_read_shows_it(inbox_home: Path, repo: Path, tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    assert inbox_home.name == ".legion"
    other = tmp_path / "other"
    other.mkdir()
    monkeypatch.chdir(other)
    assert run(["inbox", "send", "--to", str(repo), "--text", "hello"]) == 0
    capsys.readouterr()
    assert run(["inbox", "read", "--repo", str(repo)]) == 0
    assert capsys.readouterr().out.startswith(f"from: {other.resolve()}\n")


def test_emoji_and_cyrillic_survive_a_narrow_default_encoding(inbox_home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    assert inbox_home.name == ".legion"
    text = "Привіт 👋"
    assert run(["inbox", "send", "--to", str(repo), "--from", "repo-a", "--text", text]) == 0
    raw = io.BytesIO()
    pipe = io.TextIOWrapper(raw, encoding="cp1252", errors="strict")
    monkeypatch.setattr(sys, "stdout", pipe)
    assert run(["inbox", "read", "--repo", str(repo)]) == 0
    pipe.flush()
    lines = raw.getvalue().decode("utf-8").splitlines()
    assert [lines[0], lines[2], lines[3]] == ["from: repo-a", "text:", f"    {text}"]
