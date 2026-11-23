import json
import os
import stat
import sys
import tempfile
import time
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

import pytest
from cli_runner import run
from conftest import REPO, Fence

from legion import _forward
from legion._process import process_started_at
from legion._settings_models import Agent
from legion.limits import (
    LimitRow,
    account_rows,
    home_path,
)
from legion.limits import codex
from legion.limits._ping import (
    Ping,
    format_used_percent,
)

FIXTURES = REPO / "tests" / "fixtures" / "limits"
FAKE_CLI = Path(__file__).with_name("limits_fake_cli.py")
ACCESS_VALUE = "fake-access-value"
TOKEN_ARGUMENTS = ["account", "get-access-token", "--resource", "https://cognitiveservices.azure.com", "-o", "json"]
CONFIG_ENVIRONMENT = {"claude": "CLAUDE_CONFIG_DIR", "codex": "CODEX_HOME", "copilot": "COPILOT_HOME"}
FOUNDRY = {"kind": "foundry", "endpoint": "https://my-resource.cognitiveservices.azure.com", "default": "model-a", "deployments": [{"name": "model-a"}]}


def reset_time(seconds: int) -> str:
    return datetime.fromtimestamp(seconds, UTC).astimezone().strftime("%Y-%m-%d %H:%M")


# A fake executable that names itself to the fake CLI: <name>.cmd on Windows, a shell script elsewhere.
def write_executable(folder: Path, name: str, environment: dict[str, str]) -> Path:
    environment = {"LEGION_FAKE_NAME": name.split("-", maxsplit=1)[0], **environment}
    if sys.platform == "win32":
        path = folder / f"{name}.cmd"
        lines = ["@echo off", *(f'set "{key}={value}"' for key, value in environment.items()), f'"{sys.executable}" "{FAKE_CLI}" %*', "exit /b %ERRORLEVEL%"]
        path.write_text("\r\n".join(lines) + "\r\n", encoding="utf-8")
    else:
        path = folder / name
        lines = ["#!/bin/sh", *(f"export {key}='{value}'" for key, value in environment.items()), f"exec '{sys.executable}' '{FAKE_CLI}' \"$@\""]
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        path.chmod(path.stat().st_mode | stat.S_IXUSR)
    return path


class Bench:
    def __init__(self, root: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        self.monkeypatch = monkeypatch
        self.home = root / "home"
        self.path = root / "bin"
        self.logs = root / "logs"
        self.azure = root / "azure"
        for folder in (self.home / ".legion" / "bin", self.path, self.logs, self.azure):
            folder.mkdir(parents=True)
        for name in [name for name in os.environ if name.startswith("LEGION_FAKE_")]:
            monkeypatch.delenv(name)
        # Only the fakes can be found: the real PATH is gone.
        monkeypatch.setenv("PATH", str(self.path))
        monkeypatch.setenv("LEGION_FAKE_LOG", str(self.logs))
        monkeypatch.setenv("AZURE_CONFIG_DIR", str(self.azure))
        write_executable(self.path, "git", {})
        write_executable(self.path, "az", {})
        for tool, variable in CONFIG_ENVIRONMENT.items():
            write_executable(self.home / ".legion" / "bin", f"{tool}-a", {variable: str(self.config(f"{tool}-a"))})

    def config(self, account: str) -> Path:
        return self.home / ".legion" / "agents" / account

    def fake(self, **settings: str) -> None:
        for name, value in settings.items():
            self.monkeypatch.setenv(f"LEGION_FAKE_{name}", value)

    def calls(self, name: str) -> list[dict[str, Any]]:
        log = self.logs / f"{name}.jsonl"
        if not log.is_file():
            return []
        return [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()]

    def rows(self, account: str, tool: str, timeout: int = 60, **fields: Any) -> list[LimitRow]:
        agent = Agent.model_validate({"id": account, "tool": tool, "configDir": f"~/.legion/agents/{account}", **fields})
        return account_rows(agent, self.home, timeout)


@pytest.fixture
def bench(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Bench:
    return Bench(tmp_path, monkeypatch)


def assert_disposable_folder(folder: str) -> None:
    assert Path(folder).name.startswith("legion-limits-")
    assert Path(folder).parent == Path(tempfile.gettempdir())
    assert not Path(folder).exists()


def test_claude_reads_every_unified_window(bench: Bench) -> None:
    # A stock claude on PATH is never used: the account launcher is.
    write_executable(bench.path, "claude", {"LEGION_FAKE_CLAUDE_EXIT": "99"})
    bench.fake(STDOUT=str(FIXTURES / "claude-stream.jsonl"))
    assert bench.rows("claude-a", "claude") == [
        LimitRow("five_hour", "69%", reset_time(1795350000), "allowed"),
        LimitRow("seven_day", "55%", reset_time(1795654800), "allowed"),
    ]
    [call] = bench.calls("claude")
    assert call["arguments"] == ["-p", "--output-format", "stream-json", "--verbose", "ping"]
    assert call["stdin"] == ""
    assert call["config"]["CLAUDE_CONFIG_DIR"] == str(bench.config("claude-a"))
    assert_disposable_folder(call["folder"])
    assert bench.calls("git") == []


def test_claude_without_an_event_has_no_readout(bench: Bench) -> None:
    bench.fake(STDOUT=str(FIXTURES / "claude-no-event.jsonl"))
    assert bench.rows("claude-a", "claude") == [LimitRow(status="no limit readout")]


def test_claude_event_without_windows_names_its_type(bench: Bench, tmp_path: Path) -> None:
    stream = tmp_path / "stream.jsonl"
    event = {"type": "rate_limit_event", "rate_limit_info": {"status": "rejected", "resetsAt": 1795350000, "rateLimitType": "five_hour"}}
    stream.write_text("not json\n" + json.dumps(event) + "\n", encoding="utf-8")
    bench.fake(STDOUT=str(stream), EXIT="1")
    assert bench.rows("claude-a", "claude") == [LimitRow("five_hour", "unknown", reset_time(1795350000), "rejected")]


def test_claude_failures_tell_the_quota_from_other_errors(bench: Bench, tmp_path: Path) -> None:
    quota = tmp_path / "quota.txt"
    quota.write_text("Claude AI usage limit reached|1795350000\n", encoding="utf-8")
    bench.fake(STDOUT=str(quota), EXIT="1")
    assert bench.rows("claude-a", "claude") == [LimitRow(status="limit reached")]
    failure = tmp_path / "failure.txt"
    failure.write_text("\n  Invalid API key  \nsecond line\n", encoding="utf-8")
    bench.fake(STDOUT="", STDERR=str(failure))
    assert bench.rows("claude-a", "claude") == [LimitRow(status="ping failed: Invalid API key")]


def test_codex_reads_only_its_own_session(bench: Bench) -> None:
    bench.fake(SESSION=str(FIXTURES / "codex-session.jsonl"), CONCURRENT="1")
    assert bench.rows("codex-a", "codex") == [
        LimitRow("5h", "12%", reset_time(1795350000), "unknown"),
        LimitRow("7d", "40%", reset_time(1795654800), "unknown"),
    ]
    [call] = bench.calls("codex")
    assert call["arguments"] == ["exec", "ping"]
    assert call["stdin"] == ""
    assert call["config"]["CODEX_HOME"] == str(bench.config("codex-a"))
    assert_disposable_folder(call["folder"])
    # Codex needs a git folder: the ping folder is initialised first.
    [git] = bench.calls("git")
    assert git["arguments"] == ["-C", call["folder"], "init", "-q"]


def test_codex_null_windows_have_no_readout(bench: Bench) -> None:
    bench.fake(SESSION=str(FIXTURES / "codex-session-null.jsonl"))
    assert bench.rows("codex-a", "codex") == [LimitRow(status="no limit readout")]


def test_codex_quota_error_names_the_retry_time(bench: Bench) -> None:
    bench.fake(STDERR=str(FIXTURES / "codex-quota.txt"), EXIT="1")
    assert bench.rows("codex-a", "codex") == [LimitRow(resets="2:57 PM", status="limit reached")]


def test_codex_without_git_is_an_error(bench: Bench) -> None:
    next(bench.path.glob("git*")).unlink()
    assert bench.rows("codex-a", "codex") == [LimitRow(status="error: git is not installed")]
    assert bench.calls("codex") == []


@pytest.mark.parametrize(
    ("exit_code", "timed_out", "expected"),
    [(1, False, "ping failed: probe failed"), (-1, True, "ping timed out"), (0, False, "no limit readout")],
    ids=["failed", "timeout", "unrelated session"],
)
def test_codex_never_reuses_another_sessions_windows(tmp_path: Path, exit_code: int, timed_out: bool, expected: str) -> None:
    sessions = tmp_path / "codex" / "sessions"
    sessions.mkdir(parents=True)
    (sessions / "old.jsonl").write_text((FIXTURES / "codex-session.jsonl").read_text(encoding="utf-8"), encoding="utf-8")
    probe = tmp_path / "probe"
    probe.mkdir()
    ping = Ping(exit_code, "", "probe failed", timed_out, probe.resolve())
    assert codex.rows(ping, tmp_path / "codex") == [LimitRow(status=expected)]


def test_codex_matches_a_session_named_through_a_link(fence: Fence) -> None:
    # The session names the probe through the fence's linked home; the ping folder is the physical path.
    probe = fence.temp / "legion-limits-linked"
    probe.mkdir()
    sessions = fence.temp / "codex" / "sessions"
    sessions.mkdir(parents=True)
    records = (FIXTURES / "codex-session.jsonl").read_text(encoding="utf-8").splitlines()[1:]
    metadata = json.dumps({"type": "session_meta", "payload": {"cwd": str(probe)}})
    (sessions / "probe.jsonl").write_text("\n".join([metadata, *records]) + "\n", encoding="utf-8")
    assert probe.resolve() != probe
    rows = codex.rows(Ping(0, "", "", False, probe.resolve()), fence.temp / "codex")
    assert [(row.window, row.used) for row in rows] == [("5h", "12%"), ("7d", "40%")]


@pytest.mark.parametrize(("minutes", "expected"), [(300, "5h"), (10080, "7d"), (90, "90m"), (None, "primary")])
def test_codex_window_name_from_its_length(minutes: int | None, expected: str) -> None:
    assert codex.window_name(minutes, "primary") == expected


def test_copilot_answer_has_no_readout(bench: Bench) -> None:
    assert bench.rows("copilot-a", "copilot") == [LimitRow(status="answers; no limit readout")]
    [call] = bench.calls("copilot")
    assert call["arguments"] == ["-p", "ping", "-s"]
    assert call["stdin"] == ""
    assert call["config"]["COPILOT_HOME"] == str(bench.config("copilot-a"))
    assert_disposable_folder(call["folder"])


def test_copilot_quota_is_the_limit_and_other_failures_are_not(bench: Bench) -> None:
    bench.fake(STDERR=str(FIXTURES / "copilot-quota.txt"), EXIT="1")
    assert bench.rows("copilot-a", "copilot") == [LimitRow(status="limit reached")]
    bench.fake(STDERR=str(FIXTURES / "codex-session-null.jsonl"))
    [row] = bench.rows("copilot-a", "copilot")
    assert row.status.startswith("ping failed: ")


def test_slow_ping_times_out_and_ends_its_whole_tree(bench: Bench) -> None:
    bench.fake(SLEEP="60")
    started = time.monotonic()
    assert bench.rows("copilot-a", "copilot", timeout=3) == [LimitRow(status="ping timed out")]
    assert time.monotonic() - started < 30
    grandchild = int((bench.logs / "grandchild.pid").read_text(encoding="utf-8"))
    deadline = time.monotonic() + 10
    while process_started_at(grandchild) is not None and time.monotonic() < deadline:
        time.sleep(0.1)
    assert process_started_at(grandchild) is None
    assert_disposable_folder(bench.calls("copilot")[0]["folder"])


def test_foundry_token_ok_never_shows_the_token(bench: Bench, tmp_path: Path, capfd: pytest.CaptureFixture[str]) -> None:
    answer = tmp_path / "token.json"
    answer.write_text(json.dumps({"accessToken": ACCESS_VALUE, "expiresOn": "2026-11-18T18:30:00+00:00"}), encoding="utf-8")
    bench.fake(AZ_STDOUT=str(answer))
    rows = bench.rows("foundry-a", "claude", provider=FOUNDRY)
    assert rows == [LimitRow(used="-", resets="-", status="token ok")]
    [call] = bench.calls("az")
    assert call["arguments"] == TOKEN_ARGUMENTS
    assert call["config"]["AZURE_CONFIG_DIR"] == str(bench.azure)
    captured = capfd.readouterr()
    assert ACCESS_VALUE not in captured.out + captured.err + repr(rows)
    assert bench.calls("claude") == []


def test_foundry_failure_shows_the_az_error_without_login(bench: Bench, tmp_path: Path) -> None:
    error = tmp_path / "error.txt"
    error.write_text("ERROR: Please run 'az login' to setup account.\nmore detail\n", encoding="utf-8")
    bench.fake(AZ_STDERR=str(error), AZ_EXIT="1")
    assert bench.rows("foundry-a", "codex", provider=FOUNDRY) == [LimitRow(used="-", resets="-", status="ERROR: Please run 'az login' to setup account.")]
    assert [call["arguments"] for call in bench.calls("az")] == [TOKEN_ARGUMENTS]


def test_foundry_answer_without_a_token_is_not_ok(bench: Bench, tmp_path: Path) -> None:
    answer = tmp_path / "empty.json"
    answer.write_text("{}", encoding="utf-8")
    bench.fake(AZ_STDOUT=str(answer))
    assert bench.rows("foundry-a", "claude", provider=FOUNDRY)[0].status == "az returned no access token"
    answer.write_text("not json", encoding="utf-8")
    assert bench.rows("foundry-a", "claude", provider=FOUNDRY)[0].status == "az returned no access token"


def test_foundry_without_az_names_the_install(bench: Bench) -> None:
    next(bench.path.glob("az*")).unlink()
    assert bench.rows("foundry-a", "copilot", provider=FOUNDRY)[0].status == "az is not installed; run legion-install-tool.ps1 -Tool az"


def test_missing_launcher_requests_setup(bench: Bench) -> None:
    next((bench.home / ".legion" / "bin").glob("claude-a*")).unlink()
    assert bench.rows("claude-a", "claude") == [LimitRow(status="launcher missing; run legion setup")]


@pytest.mark.skipif(sys.platform == "win32", reason="Windows has no executable bit")
def test_launcher_without_the_executable_bit_is_missing(bench: Bench) -> None:
    launcher = bench.home / ".legion" / "bin" / "claude-a"
    launcher.chmod(stat.S_IRUSR | stat.S_IWUSR)
    assert bench.rows("claude-a", "claude") == [LimitRow(status="launcher missing; run legion setup")]


def test_tool_without_a_recipe_says_so(bench: Bench) -> None:
    assert bench.rows("claude-a", "gemini") == [LimitRow(status="no limits script for gemini")]


@pytest.mark.parametrize(("percent", "expected"), [(12.0, "12%"), (12.5, "12%"), (13.5, "14%"), (68.99999, "69%")])
def test_used_percent_rounds_like_powershell(percent: float, expected: str) -> None:
    assert format_used_percent(percent) == expected


def test_codex_skips_unreadable_session_lines(tmp_path: Path) -> None:
    probe = tmp_path / "probe"
    probe.mkdir()
    sessions = tmp_path / "codex" / "sessions"
    (sessions / "0-folder.jsonl").mkdir(parents=True)
    (sessions / "a-broken.jsonl").write_text("not json\n", encoding="utf-8")
    (sessions / "b-list.jsonl").write_text("[1]\n", encoding="utf-8")
    metadata = json.dumps({"type": "session_meta", "payload": {"cwd": str(probe)}})
    records = (FIXTURES / "codex-session.jsonl").read_text(encoding="utf-8").splitlines()[1:]
    (sessions / "c-probe.jsonl").write_text("\n".join([metadata, *records, '{"rate_limits": broken', '["rate_limits"]']) + "\n", encoding="utf-8")
    rows = codex.rows(Ping(0, "", "", False, probe.resolve()), tmp_path / "codex")
    assert [(row.window, row.used) for row in rows] == [("5h", "12%"), ("7d", "40%")]


def test_foundry_az_that_never_answers_is_stopped(bench: Bench) -> None:
    bench.fake(AZ_SLEEP="60")
    assert bench.rows("foundry-a", "claude", timeout=3, provider=FOUNDRY) == [LimitRow(used="-", resets="-", status="az timed out")]


def test_account_folder_starts_at_the_home_root(tmp_path: Path) -> None:
    assert home_path("~/.legion/agents/codex-a", tmp_path) == tmp_path / ".legion/agents/codex-a"
    assert home_path("~\\agents", tmp_path) == tmp_path / "agents"
    assert home_path(str(tmp_path / "elsewhere"), tmp_path) == tmp_path / "elsewhere"


def write_settings(home: Path, agents: list[dict[str, Any]]) -> None:
    file = home / ".legion" / "configuration" / "personalisation.json"
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(json.dumps({"schemaVersion": 1, "agents": agents, "channels": []}), encoding="utf-8")


ACCOUNTS = [
    {"id": "claude-a", "tool": "claude", "configDir": "~/.legion/agents/claude-a"},
    {"id": "codex-a", "tool": "codex", "configDir": "~/.legion/agents/codex-a"},
    {"id": "copilot-a", "tool": "copilot", "configDir": "~/.legion/agents/copilot-a"},
    {"id": "foundry-a", "tool": "claude", "configDir": "~/.legion/agents/foundry-a", "provider": FOUNDRY},
]

# The table the PowerShell limits command printed for these fakes (Format-Table -AutoSize): a blank line first,
# one space between columns, the last column not padded.
EXPECTED_TABLE = """
Account   Tool    Window    Used    Resets at        Status
-------   ----    ------    ----    ---------        ------
claude-a  claude  five_hour 69%     {five_hour} allowed
claude-a  claude  seven_day 55%     {seven_day} allowed
codex-a   codex   5h        12%     {five_hour} unknown
codex-a   codex   7d        40%     {seven_day} unknown
copilot-a copilot -         unknown unknown          answers; no limit readout
foundry-a claude  -         -       -                token ok
"""


def test_limits_prints_the_powershell_table_for_every_account(bench: Bench, tmp_path: Path, capfd: pytest.CaptureFixture[str]) -> None:
    write_settings(bench.home, ACCOUNTS)
    answer = tmp_path / "token.json"
    answer.write_text(json.dumps({"accessToken": ACCESS_VALUE, "expiresOn": "2026-11-18T18:30:00+00:00"}), encoding="utf-8")
    bench.fake(CLAUDE_STDOUT=str(FIXTURES / "claude-stream.jsonl"), CODEX_SESSION=str(FIXTURES / "codex-session.jsonl"), AZ_STDOUT=str(answer))
    assert run(["--home", str(bench.home), "limits"]) == 0
    captured = capfd.readouterr()
    assert captured.out == EXPECTED_TABLE.format(five_hour=reset_time(1795350000), seven_day=reset_time(1795654800))
    assert captured.err == ""
    assert ACCESS_VALUE not in captured.out + captured.err
    assert [len(bench.calls(name)) for name in ("claude", "codex", "copilot", "az")] == [1, 1, 1, 1]


def test_limits_for_one_account_pings_only_that_account(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    write_settings(bench.home, ACCOUNTS)
    assert run(["--home", str(bench.home), "limits", "copilot-a"]) == 0
    assert capsys.readouterr().out.splitlines()[1:] == [
        "Account   Tool    Window Used    Resets at Status",
        "-------   ----    ------ ----    --------- ------",
        "copilot-a copilot -      unknown unknown   answers; no limit readout",
    ]
    assert [len(bench.calls(name)) for name in ("claude", "codex", "copilot", "az")] == [0, 0, 1, 0]


@pytest.mark.parametrize(
    ("agents", "words", "message"),
    [
        (None, [], "No legion settings yet; run legion setup."),
        (ACCOUNTS, ["nobody"], "unknown account 'nobody'"),
        (ACCOUNTS, ["Claude-A"], "unknown account 'Claude-A'"),
    ],
    ids=["no settings", "unknown account", "account names are exact"],
)
def test_limits_errors_exit_one(bench: Bench, capsys: pytest.CaptureFixture[str], agents: list[dict[str, Any]] | None, words: list[str], message: str) -> None:
    if agents is not None:
        write_settings(bench.home, agents)
    assert run(["--home", str(bench.home), "limits", *words]) == 1
    captured = capsys.readouterr()
    assert (captured.out, captured.err) == ("", message + "\n")
    assert bench.calls("claude") == []


def test_limits_with_unreadable_settings_exits_one(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    write_settings(bench.home, [{"id": "claude-a"}])
    assert run(["--home", str(bench.home), "limits"]) == 1
    assert capsys.readouterr().err.startswith("legion settings are not valid: ")


def test_limits_without_accounts_says_to_add_one(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    write_settings(bench.home, [])
    assert run(["--home", str(bench.home), "limits"]) == 0
    assert capsys.readouterr().out == "No accounts yet; run legion add.\n"


@pytest.mark.parametrize("words", [["claude-a", "codex-a"], ["--yes"]], ids=["two accounts", "a flag"])
def test_limits_takes_at_most_one_account_and_no_flags(bench: Bench, words: list[str]) -> None:
    write_settings(bench.home, ACCOUNTS)
    assert run(["--home", str(bench.home), "limits", *words]) == 2
    assert bench.calls("claude") == []


def test_limits_is_served_by_python(capsys: pytest.CaptureFixture[str]) -> None:
    assert "limits" not in _forward.FORWARDED_VERBS
    assert run(["limits", "--help"]) == 0
    assert "Show each account's usage windows and reset times" in capsys.readouterr().out
