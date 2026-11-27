# The Foundry runner against a fake az and a fake tool; nothing here reaches Azure or starts a real tool.
import contextlib
import json
import os
import signal
import subprocess
import sys
import sysconfig
import time
from collections.abc import Mapping
from pathlib import Path
from types import SimpleNamespace

import pytest
from launcher_fakes import WINDOWS
from test_limits import write_executable

from legion.core._home import settings_path
from legion.services.accounts import _launch
from legion.services.accounts._launchers import LauncherError
from legion.services.foundry._az import AzAccessToken

ACCESS_CALL = "account get-access-token --resource https://cognitiveservices.azure.com -o json"
TOKEN_ANSWER = {"stdout": '{"accessToken":"fake-token","expiresOn":"2026-11-18T18:30:00+00:00"}'}
ENDPOINT = "https://res-a.cognitiveservices.azure.com"
RUNNER = "import sys; from legion import cli as _cli; _cli.main(sys.argv[1:], prog_name='legion')"


def foundry(account: str, tool: str, default: str, deployments: list[dict[str, str]]) -> dict[str, object]:
    provider = {"kind": "foundry", "endpoint": ENDPOINT, "default": default, "deployments": deployments}
    return {"id": account, "tool": tool, "configDir": f"~/.legion/agents/{account}", "provider": provider}


class Bench:
    def __init__(self, root: Path, monkeypatch: pytest.MonkeyPatch, *, with_agents: bool = True) -> None:
        self.monkeypatch = monkeypatch
        self.home = root / "owner with spaces"
        self.bin = root / "bin"
        self.logs = root / "logs"
        for folder in (self.home / ".legion", self.bin, self.logs):
            folder.mkdir(parents=True)
        for name in [name for name in os.environ if name.startswith("LEGION_FAKE_")]:
            monkeypatch.delenv(name)
        for name in [name for name in os.environ if name.startswith("ANTHROPIC_FOUNDRY")]:
            monkeypatch.delenv(name)
        monkeypatch.setenv("PATH", str(self.bin))
        monkeypatch.setenv("LEGION_FAKE_LOG", str(self.logs))
        monkeypatch.setenv("LEGION_FAKE_HOME", str(self.home))
        if WINDOWS:
            monkeypatch.setenv("PATHEXT", ".COM;.EXE;.BAT;.CMD")
        agents = [
            foundry("claude-dev", "claude", "claude-opus-x", [{"name": "claude-opus-x", "model": "claude-opus-x", "alias": "opus"}, {"name": "claude-sonnet-x"}]),
            foundry("copilot-dev", "copilot", "claude-opus-x", [{"name": "claude-opus-x", "model": "claude-opus-x"}, {"name": "claude-sonnet-x"}]),
            foundry("codex-dev", "codex", "gpt-x", [{"name": "gpt-x"}]),
            {"id": "subscription", "tool": "claude", "configDir": "~/.legion/agents/subscription"},
        ]
        settings_path(self.home).parent.mkdir(parents=True)
        settings_path(self.home).write_text(json.dumps({"schemaVersion": 1, "agents": agents if with_agents else [], "channels": []}), encoding="utf-8")
        self.answers({ACCESS_CALL: TOKEN_ANSWER})
        write_executable(self.bin, "az", {})
        for tool in ("claude", "codex", "copilot"):
            write_executable(self.bin, tool, {})

    def answers(self, answers: Mapping[str, Mapping[str, object]]) -> None:
        path = self.logs / "answers.json"
        path.write_text(json.dumps(answers), encoding="utf-8")
        self.monkeypatch.setenv("LEGION_FAKE_AZ_ANSWERS", str(path))

    def calls(self, name: str) -> list[dict[str, object]]:
        log = self.logs / f"{name}.jsonl"
        return [json.loads(line) for line in log.read_text(encoding="utf-8").splitlines()] if log.exists() else []

    def environment(self, name: str) -> dict[str, str]:
        [call] = self.calls(name)
        environment = call["environment"]
        assert isinstance(environment, dict)
        return environment

    def temp_files(self) -> list[Path]:
        folder = self.home / ".legion" / "temp"
        return list(folder.glob("*providers*")) if folder.is_dir() else []


@pytest.fixture
def bench(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Bench:
    return Bench(tmp_path, monkeypatch)


def test_claude_child_gets_foundry_environment_and_parent_is_untouched(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CLAUDE_CODE_USE_BEDROCK", "1")
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", "parent-config")
    monkeypatch.setenv("VIRTUAL_ENV", sys.prefix)
    monkeypatch.setenv("UV_PROJECT_ENVIRONMENT", sys.prefix)
    parent_path = os.pathsep.join([sysconfig.get_path("scripts"), os.environ["PATH"]])
    monkeypatch.setenv("PATH", parent_path)
    assert _launch.run_account("claude-dev", ["-p", "hi"], bench.home) == 0
    environment = bench.environment("claude")
    assert environment["CLAUDE_CODE_USE_FOUNDRY"] == "1"
    assert environment["ANTHROPIC_FOUNDRY_BASE_URL"] == f"{ENDPOINT}/anthropic"
    assert environment["ANTHROPIC_MODEL"] == "claude-opus-x"
    assert environment["ANTHROPIC_DEFAULT_OPUS_MODEL"] == "claude-opus-x"
    assert "CLAUDE_CODE_USE_BEDROCK" not in environment
    assert "VIRTUAL_ENV" not in environment
    assert "UV_PROJECT_ENVIRONMENT" not in environment
    assert environment["PATH"] == str(bench.bin)
    assert Path(environment["CLAUDE_CONFIG_DIR"]) == bench.home / ".legion" / "agents" / "claude-dev"
    assert bench.calls("claude")[0]["arguments"] == ["-p", "hi"]
    assert os.environ["CLAUDE_CODE_USE_BEDROCK"] == "1"
    assert os.environ["CLAUDE_CONFIG_DIR"] == "parent-config"
    assert os.environ["PATH"] == parent_path


def test_codex_child_gets_only_its_config_home_and_arguments_keep_their_boundaries(bench: Bench) -> None:
    assert _launch.run_account("codex-dev", ["-p", "hi there", "a&b"], bench.home) == 0
    environment = bench.environment("codex")
    assert Path(environment["CODEX_HOME"]) == bench.home / ".legion" / "agents" / "codex-dev"
    assert bench.calls("codex")[0]["foundry_names"] == []
    assert bench.calls("codex")[0]["arguments"] == ["-p", "hi there", "a&b"]


@pytest.mark.parametrize("code", [0, 3])
def test_copilot_exit_code_passes_and_provider_file_lives_only_while_the_tool_runs(bench: Bench, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], code: int) -> None:
    monkeypatch.setenv("LEGION_FAKE_EXIT", str(code))
    assert _launch.run_account("copilot-dev", ["--resume"], bench.home) == code
    captured = capsys.readouterr()
    assert "fake-token" not in captured.out + captured.err
    expiry = AzAccessToken.model_validate({"accessToken": "x", "expiresOn": "2026-11-18T18:30:00+00:00"}).expiry().strftime("%H:%M")
    assert f"token valid until {expiry}; after that restart with: legion run --account copilot-dev -- --resume" in captured.out
    environment = bench.environment("copilot")
    assert Path(environment["COPILOT_HOME"]) == bench.home / ".legion" / "agents" / "copilot-dev"
    assert Path(environment["COPILOT_PROVIDERS_CONFIG"]).parent == bench.home / ".legion" / "temp"
    assert not Path(environment["COPILOT_PROVIDERS_CONFIG"]).exists()
    assert bench.temp_files() == []
    seen = bench.calls("copilot")[0]["providers"]
    assert isinstance(seen, str)
    provider = json.loads(seen)
    assert len(provider["providers"]) == 1
    assert provider["providers"][0]["name"] == "legion-foundry"
    assert provider["providers"][0]["type"] == "anthropic"
    assert provider["providers"][0]["baseUrl"] == f"{ENDPOINT}/anthropic"
    assert provider["providers"][0]["bearerToken"] == "fake-token"
    assert provider["providers"][0]["headers"]["anthropic-version"] == "2023-06-01"
    assert len(provider["models"]) == 2
    assert provider["models"][1]["modelId"] == "claude-sonnet-x"
    assert provider["models"][1]["wireModel"] == "claude-sonnet-x"
    assert provider["models"][1]["provider"] == "legion-foundry"


def test_exit_code_three_survives_a_real_process_through_the_command_line(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LEGION_FAKE_EXIT", "3")
    monkeypatch.setenv("LEGION_HOME", str(bench.home.parent / "different home"))
    arguments = [sys.executable, "-c", RUNNER, "--home", str(bench.home), "run", "--account", "codex-dev", "--", "--flag", "two words"]
    assert subprocess.run(arguments, capture_output=True, text=True, check=False).returncode == 3
    assert bench.calls("codex")[0]["arguments"] == ["--flag", "two words"]
    assert Path(bench.environment("codex")["LEGION_HOME"]) == bench.home


def test_token_failure_exits_one_after_one_login_and_starts_no_tool(bench: Bench) -> None:
    bench.answers({ACCESS_CALL: {"exit": 1, "stdout": "fake token denied"}, "login -o none": {"exit": 0}})
    with pytest.raises(ValueError, match="fake token denied"):
        _launch.run_account("claude-dev", [], bench.home)
    assert bench.calls("claude") == []
    assert [call["arguments"] for call in bench.calls("az")].count(["login", "-o", "none"]) == 1
    assert bench.temp_files() == []


def test_missing_tool_names_the_installer(bench: Bench) -> None:
    for path in bench.bin.glob("claude*"):
        path.unlink()
    with pytest.raises(LauncherError, match=r"claude is not installed; run legion tool install --tool claude"):
        _launch.run_account("claude-dev", [], bench.home)


def test_unknown_account_is_refused_before_az(bench: Bench) -> None:
    with pytest.raises(LauncherError, match="unknown account 'x'"):
        _launch.run_account("x", [], bench.home)
    assert bench.calls("az") == []


def test_a_subscription_account_runs_without_az(bench: Bench) -> None:
    assert _launch.run_account("subscription", ["-p", "hi"], bench.home) == 0
    assert Path(bench.environment("claude")["CLAUDE_CONFIG_DIR"]) == bench.home / ".legion" / "agents" / "subscription"
    assert bench.calls("az") == []


def test_a_tool_that_cannot_start_removes_the_provider_file_and_never_prints_the_token(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    for path in bench.bin.glob("copilot*"):
        path.unlink()
    broken = bench.bin / ("copilot.exe" if WINDOWS else "copilot")
    broken.write_bytes(bytes([0, 1, 2, 3]))
    broken.chmod(0o755)
    with pytest.raises(OSError):
        _launch.run_account("copilot-dev", [], bench.home)
    assert bench.temp_files() == []
    captured = capsys.readouterr()
    assert "token valid until" in captured.out
    assert "fake-token" not in captured.out + captured.err


def test_ctrl_c_ends_the_run_with_130_and_deletes_the_provider_file(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    if sys.platform == "win32":
        pytest.skip("POSIX signals")
    monkeypatch.setenv("LEGION_FAKE_SLEEP", "30")
    arguments = [sys.executable, "-c", RUNNER, "--home", str(bench.home), "run", "--account", "copilot-dev", "--"]
    runner = subprocess.Popen(arguments, stdout=subprocess.DEVNULL, start_new_session=True)
    # The fake tool publishes grandchild.pid once it runs; that is the readiness marker, no sleeping.
    deadline = time.monotonic() + 30
    while not (bench.logs / "grandchild.pid").is_file() and time.monotonic() < deadline:
        time.sleep(0.05)
    assert (bench.logs / "grandchild.pid").is_file()
    assert len(bench.temp_files()) == 1
    os.killpg(runner.pid, signal.SIGINT)
    assert runner.wait(timeout=30) == 130
    assert bench.temp_files() == []


# A supervisor that signals only legion's process, not its group, still stops the tool; the provider file goes too.
@pytest.mark.parametrize("number", [signal.SIGINT, signal.SIGTERM] if sys.platform != "win32" else [])
def test_a_signal_sent_to_the_legion_process_reaches_the_tool(bench: Bench, monkeypatch: pytest.MonkeyPatch, number: int) -> None:
    monkeypatch.setenv("LEGION_FAKE_SLEEP", "30")
    arguments = [sys.executable, "-c", RUNNER, "--home", str(bench.home), "run", "--account", "copilot-dev", "--"]
    runner = subprocess.Popen(arguments, stdout=subprocess.DEVNULL, start_new_session=True)
    deadline = time.monotonic() + 30
    while not (bench.logs / "grandchild.pid").is_file() and time.monotonic() < deadline:
        time.sleep(0.05)
    assert (bench.logs / "grandchild.pid").is_file()
    try:
        os.kill(runner.pid, number)
        assert runner.wait(timeout=30) == 128 + number
        assert bench.temp_files() == []
    finally:
        # Only the tool is signalled, so its sleeping grandchild is ended here by its own pid.
        with contextlib.suppress(ProcessLookupError):
            os.kill(int((bench.logs / "grandchild.pid").read_text(encoding="utf-8")), signal.SIGTERM)


def test_a_tool_killed_by_a_signal_is_reported_as_a_shell_would(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    agent = SimpleNamespace(id="codex-a")
    monkeypatch.setattr(_launch._settings_io, "load", lambda _home: SimpleNamespace(agents=[agent]))
    monkeypatch.setattr(_launch, "account_command", lambda *_args: _launch.AccountCommand(Path("/fake/codex"), [], {}))
    monkeypatch.setattr(_launch, "sys", SimpleNamespace(platform="linux", stdout=sys.stdout, stderr=sys.stderr))
    monkeypatch.setattr(_launch.subprocess, "Popen", lambda *_args, **_kwargs: SimpleNamespace(pid=2**30, wait=lambda: -signal.SIGINT, stdout=None, stderr=None))
    assert _launch.run_account("codex-a", [], tmp_path) == 130
