from __future__ import annotations

import base64
import json
import os
import runpy
import shlex
import shutil
import subprocess
import sys
from pathlib import Path
from types import SimpleNamespace
from typing import Any, cast

import pytest
from cli_runner import run

from legion.services.channels import _bridge, _channel, _overseer
from legion.services.repository import _lease, _repository
from legion import cli as _cli
from legion.core import _home, _run, _settings_io, _validate
from legion.core._settings_models import Agent, PersonalisationSettings
from legion.services.limits.limit_probes import LimitRow
from legion.services import limits as limits_service


@pytest.fixture
def home(tmp_path: Path) -> Path:
    home = tmp_path / "home"
    _settings_io.save(
        home,
        PersonalisationSettings.model_validate(
            {
                "schemaVersion": 1,
                "agents": [{"id": f"{tool}-a", "tool": tool, "configDir": f"~/{tool}"} for tool in ("claude", "codex", "copilot")],
                "channels": [{"id": "main", "kind": "telegram", "target": "123", "accounts": ["claude-a", "codex-a"]}],
            }
        ),
    )
    return home


@pytest.fixture
def repo(tmp_path: Path) -> Path:
    repo = tmp_path / "my project"
    repo.mkdir()
    git = shutil.which("git")
    assert git is not None
    subprocess.run([git, "init", "--quiet", str(repo)], check=True)
    project = repo / ".legion/configuration/project.json"
    project.parent.mkdir(parents=True)
    project.write_text('{"schemaVersion":1}', encoding="utf-8")
    return repo


@pytest.fixture
def launched(monkeypatch: pytest.MonkeyPatch) -> list[tuple[Path, _overseer.Launch, bool, bool]]:
    calls: list[tuple[Path, _overseer.Launch, bool, bool]] = []

    def start(repo: Path, launch: _overseer.Launch, *, dry_run: bool, in_place: bool) -> int:
        calls.append((repo, launch, dry_run, in_place))
        return 0

    monkeypatch.setattr(_overseer, "start_launch", start)
    monkeypatch.setattr(_overseer, "interactive", lambda: False)
    return calls


def history(home: Path) -> Path:
    return home / ".legion/state/overseer-launches.json"


def saved_launch(repo: Path, home: Path) -> _overseer.LastLaunch:
    saved = _overseer.load_last(repo, home)
    assert saved is not None
    return saved


@pytest.mark.parametrize("words", [[], ["--no-channel"], ["pick"], ["pick", "--no-channel"], ["--dry-run"]])
def test_public_routes_use_python(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch, words: list[str]) -> None:
    monkeypatch.chdir(repo)
    monkeypatch.setattr(_overseer, "interactive", lambda: True)
    monkeypatch.setattr(_cli.click, "prompt", lambda *_args, **_kwargs: 2)
    assert run(["--home", str(home), *words]) == 0
    assert len(launched) == 1
    assert launched[0][1].command == str(_home.wrapper_command("codex-a", home))
    assert launched[0][3]


@pytest.mark.parametrize("words", [["--unknown"], ["pick", "extra"], ["pick", "--unknown"]])
def test_public_usage_errors_never_launch(home: Path, launched: list, words: list[str]) -> None:
    assert run(["--home", str(home), *words]) == 2
    assert not launched


def test_public_explicit_options_and_literal_arguments(home: Path, repo: Path, launched: list) -> None:
    literals = ["--model", "two words", "", "semi;literal", "quote'value", "< > | & ^ %"]
    words = ["--account", "copilot-a", "--tool", "copilot", "--repo", str(repo), "--no-channel", *[f"--argument={value}" for value in literals]]
    assert run(["--home", str(home), *words]) == 0
    assert launched[0][1].arguments == [*literals, "-i", "continue as the overseer"]
    assert not launched[0][3]


def test_fresh_home_stops_before_setup(repo: Path, tmp_path: Path, launched: list) -> None:
    home = tmp_path / "fresh"
    with pytest.raises(_overseer.OverseerError, match="No accounts yet"):
        _overseer.run(repo, home)
    assert not home.exists()
    assert not launched


def test_not_git_writes_nothing(home: Path, tmp_path: Path, launched: list, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("GIT_CEILING_DIRECTORIES", str(tmp_path.parent))
    with pytest.raises(_overseer.OverseerError, match="not a git repository"):
        _overseer.run(tmp_path, home)
    assert not history(home).exists()
    assert not launched


@pytest.mark.parametrize("answer", ["", "y", " YES ", "Yes", "n", "no", "yep", "maybe", "ok"])
def test_repository_setup_consent(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], answer: str) -> None:
    project = repo / ".legion/configuration/project.json"
    project.unlink()
    events = []

    def setup(*_args: object) -> list[str]:
        events.append("setup")
        project.write_text('{"schemaVersion":1}', encoding="utf-8")
        return ["prepared: Private orchestration"]

    monkeypatch.setattr(_overseer, "interactive", lambda: True)
    monkeypatch.setattr(_cli.click, "prompt", lambda *_args, **_kwargs: answer)
    monkeypatch.setattr(_repository, "setup", setup)
    assert _overseer.run(repo, home, account="copilot-a") == 0
    accepted = answer.strip().lower() in ("", "y", "yes")
    assert bool(events) == accepted
    assert bool(launched) == accepted
    assert ("prepared:" if accepted else "Nothing changed.") in capsys.readouterr().out


@pytest.mark.parametrize("dry_run", [False, True])
def test_unconfigured_repo_never_prompts_without_console(home: Path, repo: Path, launched: list, dry_run: bool, capsys: pytest.CaptureFixture[str]) -> None:
    project = repo / ".legion/configuration/project.json"
    project.unlink()
    if dry_run:
        assert _overseer.run(repo, home, dry_run=True) == 0
        assert "Set it up (private)? [Y/n]" in capsys.readouterr().out
    else:
        with pytest.raises(_overseer.OverseerError, match="Set it up"):
            _overseer.run(repo, home)
    assert not project.exists()
    assert not launched


def test_setup_failure_propagates(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch) -> None:
    (repo / ".legion/configuration/project.json").unlink()
    monkeypatch.setattr(_overseer, "interactive", lambda: True)
    monkeypatch.setattr(_cli.click, "prompt", lambda *_args, **_kwargs: "y")

    def refused(*_args: object) -> list[str]:
        raise _repository.RepositoryError("setup refused")

    monkeypatch.setattr(_repository, "setup", refused)
    with pytest.raises(_repository.RepositoryError, match="setup refused"):
        _overseer.run(repo, home)
    assert not launched


@pytest.mark.parametrize("kind", ["personalisation", "project"])
def test_validation_refuses_before_history_or_launch(home: Path, repo: Path, launched: list, kind: str) -> None:
    path = _home.settings_path(home) if kind == "personalisation" else repo / ".legion/configuration/project.json"
    path.write_text('{"schemaVersion":99}', encoding="utf-8")
    with pytest.raises((_overseer.OverseerError, _settings_io.SettingsError), match="schemaVersion"):
        _overseer.run(repo, home)
    assert not history(home).exists()
    assert not launched


@pytest.mark.parametrize(("tool", "channel", "expected"), [(None, (), None), ("copilot", (), "copilot-a"), (None, ("main",), None), ("claude", ("main",), "claude-a"), ("copilot", ("main",), None)])
def test_account_eligibility(home: Path, repo: Path, launched: list, tool: str | None, channel: tuple[str, ...], expected: str | None) -> None:
    if expected:
        assert _overseer.run(repo, home, tool=tool, channels=channel, dry_run=True) == 0
        assert launched[0][1].command == str(_home.wrapper_command(expected, home))
    else:
        with pytest.raises(_overseer.OverseerError, match=r"Choose an account|no account fits"):
            _overseer.run(repo, home, tool=tool, channels=channel)
    assert not history(home).exists()


def test_interactive_choices_show_bindings_last_and_retry(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    _overseer.save_last(repo, home, _overseer.LastLaunch(account="codex-a"))
    answers = iter([0, 99, 1])
    monkeypatch.setattr(_overseer, "interactive", lambda: True)
    monkeypatch.setattr(_cli.click, "prompt", lambda *_args, **_kwargs: next(answers))
    assert _overseer.run(repo, home, pick=True, dry_run=True) == 0
    output = capsys.readouterr().out
    assert "1) claude-a (claude) channels: main" in output
    assert "2) codex-a (codex) channels: main (last)" in output
    assert launched[0][1].command == str(_home.wrapper_command("claude-a", home))


@pytest.mark.parametrize(
    ("account", "tool", "channels", "message"),
    [("absent", None, (), "unknown account"), ("claude-a", "codex", (), "not codex"), ("copilot-a", None, ("main",), "does not support"), ("claude-a", None, ("absent",), "unknown.*channel")],
)
def test_explicit_selection_errors(home: Path, repo: Path, launched: list, account: str, tool: str | None, channels: tuple[str, ...], message: str) -> None:
    with pytest.raises((_overseer.OverseerError, _channel.ChannelError), match=message):
        _overseer.run(repo, home, account=account, tool=tool, channels=channels)
    assert not launched


def test_empty_accounts(home: Path, repo: Path, launched: list) -> None:
    _settings_io.save(home, PersonalisationSettings.model_validate_json(_settings_io.EMPTY))
    with pytest.raises(_overseer.OverseerError, match="No accounts yet"):
        _overseer.run(repo, home)
    assert not launched


def test_saved_launch_roundtrip_and_resolved_keys(home: Path, repo: Path, tmp_path: Path) -> None:
    last = _overseer.LastLaunch(account="claude-a", channels=["main"], arguments=["--model", "two words", ""], session="session-a")
    _overseer.save_last(repo, home, last)
    other = tmp_path / "other"
    _overseer.save_last(other, home, _overseer.LastLaunch(account="copilot-a"))
    assert _overseer.load_last(repo / "src/..", home) == last
    assert saved_launch(other, home).account == "copilot-a"
    assert _overseer.load_last(tmp_path / "unseen", home) is None
    assert _overseer.repo_key(Path(repo.anchor)) == os.path.normcase(repo.anchor)
    variant = repo.with_name(repo.name.upper())
    assert (_overseer.repo_key(variant) == _overseer.repo_key(repo)) == (sys.platform == "win32")


@pytest.mark.parametrize("lease_text", ['{"account":"codex-a"}', '{"account":"codex-a","host":"other-host","pid":1,"processStartedAt":"2026-01-01T00:00:00Z"}'])
def test_lease_fallback_uses_lease_module(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch, lease_text: str) -> None:
    path = _lease.lease_path(repo)
    path.parent.mkdir(parents=True)
    path.write_text(lease_text, encoding="utf-8")
    original = _lease.state
    seen = []

    def read(repo: Path) -> _lease.LeaseState:
        seen.append(repo)
        return original(repo)

    monkeypatch.setattr(_lease, "state", read)
    assert _overseer.run(repo, home, dry_run=True) == 0
    assert seen == [repo.resolve()]
    assert launched[0][1].command == str(_home.wrapper_command("codex-a", home))
    assert not history(home).exists()


@pytest.mark.parametrize("state", ["missing", "removed", "malformed", "unreadable"])
def test_unusable_history_and_lease_fall_back_to_choice(home: Path, repo: Path, launched: list, state: str) -> None:
    _overseer.save_last(repo, home, _overseer.LastLaunch(account="removed", channels=["removed"], arguments=["--old"]))
    path = _lease.lease_path(repo)
    path.parent.mkdir(parents=True)
    if state == "unreadable":
        path.mkdir()
    elif state != "missing":
        path.write_text("{broken" if state == "malformed" else '{"account":"removed"}', encoding="utf-8")
    with pytest.raises(_overseer.OverseerError, match="Choose an account"):
        _overseer.run(repo, home)
    assert not launched


@pytest.mark.parametrize("no_channel", [False, True])
def test_bare_restores_arguments_channels_and_resume(home: Path, repo: Path, launched: list, no_channel: bool) -> None:
    _overseer.save_last(repo, home, _overseer.LastLaunch(account="codex-a", channels=["main"], arguments=["--model", "keep", ""], session="last"))
    assert _overseer.run(repo, home, no_channel=no_channel) == 0
    launch = launched[0][1]
    assert launch.arguments == ["resume", "--last", "--model", "keep", "", "continue as the overseer"]
    assert bool(launch.environment) != no_channel
    assert saved_launch(repo, home).channels == ([] if no_channel else ["main"])
    assert launched[0][3]


def test_explicit_filters_bypass_history_and_subfolder_uses_root(home: Path, repo: Path, launched: list) -> None:
    _overseer.save_last(repo, home, _overseer.LastLaunch(account="codex-a", arguments=["--old"]))
    sub = repo / "src"
    sub.mkdir()
    assert _overseer.run(sub, home, tool="claude", no_channel=True) == 0
    assert launched[0][0] == repo.resolve()
    assert "--old" not in launched[0][1].arguments
    assert saved_launch(repo, home).account == "claude-a"


@pytest.mark.parametrize(
    ("tool", "session", "exists", "prefix"),
    [
        ("claude", "session-a", True, ["--resume", "session-a"]),
        ("claude", "session-a", False, ["--session-id"]),
        ("codex", "last", False, ["resume", "--last"]),
        ("codex", "", False, []),
        ("copilot", "last", False, ["-i"]),
    ],
)
def test_resume_rules(home: Path, repo: Path, launched: list, tool: str, session: str, exists: bool, prefix: list[str]) -> None:
    if exists:
        path = home / f"{tool}/projects/my-project/{session}.jsonl"
        path.parent.mkdir(parents=True)
        path.touch()
    _overseer.save_last(repo, home, _overseer.LastLaunch(account=f"{tool}-a", session=session))
    assert _overseer.run(repo, home) == 0
    assert launched[0][1].arguments[: len(prefix)] == prefix
    if tool == "claude":
        assert bool(saved_launch(repo, home).session)
    if tool == "copilot":
        assert saved_launch(repo, home).session == ""


@pytest.mark.parametrize("code", [0, 3, 5])
def test_child_exit_is_preserved_and_failure_clears_resume(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], code: int) -> None:
    monkeypatch.chdir(repo)
    _overseer.save_last(repo, home, _overseer.LastLaunch(account="codex-a", session="last"))
    calls = []

    def start(*_args: object, **_kwargs: object) -> int:
        calls.append(1)
        return code

    monkeypatch.setattr(_overseer, "start_launch", start)
    assert run(["--home", str(home)]) == code
    assert calls == [1]
    assert not launched
    assert saved_launch(repo, home).session == ("" if code else "last")
    assert ("launched " in capsys.readouterr().out) == (code == 0)


def test_launch_exception_clears_resume(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch) -> None:
    _overseer.save_last(repo, home, _overseer.LastLaunch(account="codex-a", session="last"))

    def start(*_args: object, **_kwargs: object) -> int:
        raise OSError("terminal failed")

    monkeypatch.setattr(_overseer, "start_launch", start)
    with pytest.raises(OSError, match="terminal failed"):
        _overseer.run(repo, home)
    assert not launched
    assert saved_launch(repo, home).session == ""


@pytest.mark.parametrize("tool", ["claude", "codex"])
def test_bot_readiness_and_dry_run_never_read_token(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], tool: str) -> None:
    before = sorted(str(p) for p in home.rglob("*"))
    assert _overseer.run(repo, home, account=f"{tool}-a", dry_run=True) == 0
    assert "missing token" in capsys.readouterr().err
    assert sorted(str(p) for p in home.rglob("*")) == before
    assert _overseer.run(repo, home, account=f"{tool}-a") == 0
    folder = home / ".legion/channels/telegram/main"
    assert list(folder.iterdir()) == []
    capsys.readouterr()
    token = folder / ".env"
    token.touch()
    original = Path.read_bytes

    def guarded(path: Path) -> bytes:
        assert path != token, "readiness opened the token"
        return original(path)

    monkeypatch.setattr(Path, "read_bytes", guarded)
    assert _overseer.run(repo, home, account=f"{tool}-a", dry_run=True) == 0
    assert "missing token" not in capsys.readouterr().err
    assert token.stat().st_size == 0
    assert launched


def test_channel_intersection_binding_state_and_unique_kind(home: Path, repo: Path, launched: list) -> None:
    settings = _settings_io.load(home)
    main = settings.channels[0]
    settings.channels.append(main.model_copy(update={"id": "alerts", "accounts": ["claude-a"]}))
    _settings_io.save(home, settings)
    with pytest.raises(_overseer.OverseerError, match="one bot folder"):
        _overseer.run(repo, home, account="claude-a", channels=("main", "alerts"))
    assert _overseer.run(repo, home, account="claude-a", channels=("main", "main"), dry_run=True) == 0
    assert launched[0][1].arguments.count("--channels") == 1
    settings.channels[1].accounts = ["copilot-a"]
    # Invalid settings are refused by the settings reader before launch assembly.
    _home.settings_path(home).write_text(settings.model_dump_json(by_alias=True, exclude_none=True), encoding="utf-8")
    with pytest.raises(_settings_io.SettingsError, match="unsupported tool"):
        _overseer.run(repo, home, account="claude-a", channels=("main", "alerts"))


def test_descriptor_argument_order_and_multiple_kinds(home: Path, repo: Path, launched: list, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    plugin = tmp_path / "plugin"
    skills = plugin / "skills"
    shutil.copytree(_validate.PLUGIN_ROOT / "skills", skills)
    fourth = skills / "legion-fourth"
    fourth.mkdir()
    fixture = Path(__file__).resolve().parents[2] / "fixtures/tools/legion-fourth/tool.json"
    (fourth / "tool.json").write_bytes(fixture.read_bytes())
    extra = skills / "legion-fixture"
    extra.mkdir()
    literals = ["--channels", "second value", "", "2026-11-19", "semi;literal", "quote'value"]
    (extra / "channel.json").write_text(json.dumps({"schemaVersion": 1, "id": "fixture", "launch": {"claude": literals}}), encoding="utf-8")
    monkeypatch.setattr(_validate, "PLUGIN_ROOT", plugin)
    settings = _settings_io.load(home)
    settings.agents.append(settings.agents[0].model_copy(update={"id": "fourth-a", "tool": "fourth"}))
    settings.channels.append(settings.channels[0].model_copy(update={"id": "extra", "kind": "fixture", "accounts": ["claude-a"]}))
    _settings_io.save(home, settings)
    assert _overseer.run(repo, home, account="fourth-a", arguments=("--account", "account value", "", "2026-11-19"), dry_run=True) == 0
    assert launched[-1][1].arguments == ["--account", "account value", "", "2026-11-19", "--interactive", "space value", "continue as the overseer"]
    assert _overseer.run(repo, home, account="claude-a", channels=("main", "extra", "extra"), dry_run=True) == 0
    args = launched[-1][1].arguments
    assert args[2:] == ["--channels", "plugin:telegram@claude-plugins-official", *literals, "--", "continue as the overseer"]


@pytest.mark.parametrize(("in_place", "semicolon", "terminal", "use_tab"), [(True, False, True, False), (False, True, True, False), (False, False, False, False), (False, False, True, True)])
def test_terminal_selection_and_literal_transport(repo: Path, monkeypatch: pytest.MonkeyPatch, in_place: bool, semicolon: bool, terminal: bool, use_tab: bool) -> None:
    launch = _overseer.Launch(command="fixture.cmd", arguments=["two words", "quote'value", ""], environment={"BOT_FOLDER": "bot;folder" if semicolon else "bot folder"})
    calls = []

    def child(command: object, **kwargs: object) -> SimpleNamespace:
        calls.append((command, kwargs))
        return SimpleNamespace(returncode=5)

    monkeypatch.setattr(_overseer, "WINDOWS", True)
    monkeypatch.setattr(_overseer.shutil, "which", lambda _name: "wt.exe" if terminal else None)
    monkeypatch.setattr(_overseer.subprocess, "run", child)
    assert _overseer.start_launch(repo, launch, in_place=in_place, dry_run=False) == 5
    command, kwargs = calls[0]
    assert (command[0] == "wt.exe") == use_tab
    if use_tab:
        assert "pwsh" not in str(command)
        payload = _overseer.Launch.model_validate_json(base64.urlsafe_b64decode(command[-1]))
        assert payload == launch
        assert command[1:4] == ["new-tab", "-d", str(repo)]
    else:
        assert kwargs["cwd"] == repo


def test_in_place_inherits_console_and_cleans_environment(repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    markers = {"NO_COLOR": "1", "TERM": "dumb", "CLAUDECODE": "1", "CLAUDE_CODE_FIXTURE": "x", "TELEGRAM_BOT_TOKEN": "fake-token"}
    for name, value in markers.items():
        monkeypatch.setenv(name, value)
    launch = _overseer.Launch(command="fixture", arguments=["x"], environment={"TELEGRAM_STATE_DIR": "bot folder"}, remove=["TELEGRAM_BOT_TOKEN"])
    before = dict(os.environ)
    cwd = Path.cwd()

    def child(_command: object, **kwargs: Any) -> SimpleNamespace:
        environment = kwargs["env"]
        assert not any(name in environment for name in markers)
        assert environment["TELEGRAM_STATE_DIR"] == "bot folder"
        assert kwargs["cwd"] == repo
        assert not any(name in kwargs for name in ("stdin", "stdout", "stderr", "capture_output"))
        return SimpleNamespace(returncode=7)

    monkeypatch.setattr(_overseer.subprocess, "run", child)
    assert _overseer.start_launch(repo, launch, in_place=True, dry_run=False) == 7
    assert dict(os.environ) == before
    assert Path.cwd() == cwd


@pytest.mark.parametrize("tool", ["claude", "codex", "copilot"])
@pytest.mark.parametrize("mode", ["in-place", "current-terminal", "new-tab"])
def test_launched_overseer_requires_limits_ids_and_preserves_owner_shell(home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch, tool: str, mode: str) -> None:
    # Start from the owner's ordinary shell; no test-injected automation marker.
    assert "LEGION_ROLE" not in os.environ
    assert "LEGION_TASK" not in os.environ
    before = dict(os.environ)
    settings = _settings_io.load(home)
    agent = next(agent for agent in settings.agents if agent.tool == tool)
    launch = _overseer._launch(settings, agent, (), ("--model", "two words"), "", False, repo, home)
    probes: list[str] = []
    calls: list[tuple[Any, dict[str, Any]]] = []

    def probe(agent: Agent, _home: Path, _timeout: float) -> list[LimitRow]:
        probes.append(agent.id)
        return [LimitRow(status="fake answer")]

    def child(command: Any, **kwargs: Any) -> SimpleNamespace:
        calls.append((command, kwargs))
        if command[0] == "wt.exe":
            # Exercise the actual module entry used by a new terminal tab.
            assert command[1:7] == ["new-tab", "-d", str(repo), sys.executable, "-m", "legion.services.channels._overseer"]
            assert command[7] == str(repo)
            assert _overseer.Launch.model_validate_json(base64.urlsafe_b64decode(command[8])) == launch
            with monkeypatch.context() as entry:
                entry.setattr(sys, "argv", command[6:])
                entry.delitem(sys.modules, _overseer.__name__)
                with pytest.raises(SystemExit) as result:
                    runpy.run_module(_overseer.__name__, run_name="__main__")
            assert result.value.code == 0
            return SimpleNamespace(returncode=0)

        expected = [launch.command, *launch.arguments]
        if _overseer.WINDOWS and Path(launch.command).suffix.lower() in (".cmd", ".bat"):
            expected = _run._cmd_line(expected)
        assert command == expected
        assert kwargs["cwd"] == repo
        assert not any(name in kwargs for name in ("stdin", "stdout", "stderr", "capture_output"))
        with monkeypatch.context() as session:
            # Run the CLI under precisely the environment supplied to the agent.
            session.setattr(os, "environ", kwargs["env"].copy())
            assert run(["--home", str(home), "limits"]) == 1
            assert probes == []
            assert os.environ["LEGION_ROLE"] == "overseer"
            assert run(["--home", str(home), "limits", "--id", agent.id]) == 0
            assert probes == [agent.id]
            probes.clear()
        return SimpleNamespace(returncode=0)

    monkeypatch.setattr(limits_service, "account_rows", probe)
    with monkeypatch.context() as transport:
        transport.setattr(_overseer, "WINDOWS", mode == "new-tab" or sys.platform == "win32")
        transport.setattr(_overseer.shutil, "which", lambda _name: "wt.exe" if mode == "new-tab" else None)
        transport.setattr(_overseer.subprocess, "run", child)
        assert _overseer.start_launch(repo, launch, in_place=mode == "in-place") == 0
    assert len(calls) == (2 if mode == "new-tab" else 1)
    assert dict(os.environ) == before
    assert run(["--home", str(home), "limits"]) == 0
    assert probes == [agent.id for agent in settings.agents]
    assert dict(os.environ) == before


def test_terminal_payload_survives_rejoin_and_module_entry(repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    launch = _overseer.Launch(
        command="fixture",
        arguments=["continue as the overseer", 'double"quote', "quote'value", "", "< > | & ^ %", "Привіт"],
        environment={"BOT_FOLDER": "bot folder"},
    )
    calls = []
    monkeypatch.setattr(_overseer, "WINDOWS", True)
    monkeypatch.setattr(_overseer.shutil, "which", lambda _name: "wt.exe")
    monkeypatch.setattr(_overseer.subprocess, "run", lambda command, **kwargs: calls.append((command, kwargs)) or SimpleNamespace(returncode=5))
    assert _overseer.start_launch(repo, launch) == 5
    words = calls.pop()[0][4:]
    assert not any(character in words[-1] for character in (" ", '"', ";"))
    # Hand-built, reason: Terminal rejoins words with spaces and wraps words containing spaces,
    # without escaping embedded quotes. Disable shlex escapes to retain Windows path separators.
    command_line = " ".join(f'"{word}"' if " " in word else word for word in words)
    parser = shlex.shlex(command_line, posix=True)
    parser.whitespace_split = True
    parser.escape = ""
    arguments = list(parser)
    assert arguments == words
    monkeypatch.setattr(sys, "argv", arguments[2:])
    monkeypatch.delitem(sys.modules, _overseer.__name__)
    with pytest.raises(SystemExit) as result:
        runpy.run_module(_overseer.__name__, run_name="__main__")
    assert result.value.code == 5
    command, kwargs = calls.pop()
    assert command == [launch.command, *launch.arguments]
    assert kwargs["cwd"] == repo
    assert kwargs["env"]["BOT_FOLDER"] == "bot folder"


@pytest.mark.parametrize("fails", [False, True])
def test_bridge_surrounds_child_even_on_failure(repo: Path, home: Path, monkeypatch: pytest.MonkeyPatch, fails: bool) -> None:
    events = []
    launch = _overseer.Launch(command="fixture", arguments=[], bridge=[sys.executable, "fake bridge"], bot_folder=str(home))
    process = SimpleNamespace(pid=123)
    monkeypatch.setattr(_overseer, "start_bridge", lambda *_args: events.append("start") or process)
    monkeypatch.setattr(_overseer, "stop_bridge", lambda *_args: events.append("stop"))

    def child(*_args: object, **_kwargs: object) -> SimpleNamespace:
        events.append("session")
        if fails:
            raise OSError("fixture failed")
        return SimpleNamespace(returncode=5)

    monkeypatch.setattr(_overseer.subprocess, "run", child)
    if fails:
        with pytest.raises(OSError, match="fixture failed"):
            _overseer.start_launch(repo, launch, in_place=True, dry_run=False)
    else:
        assert _overseer.start_launch(repo, launch, in_place=True, dry_run=False) == 5
    assert events == ["start", "session", "stop"]


@pytest.mark.parametrize("live", [False, True])
def test_bridge_stops_only_owned_process_and_preserves_other_pid(home: Path, monkeypatch: pytest.MonkeyPatch, live: bool) -> None:
    home.mkdir(exist_ok=True)
    pid_file = home / "bridge.pid"
    pid_file.write_text("456", encoding="utf-8")
    events = []
    process = SimpleNamespace(kill=lambda: events.append("kill"), wait=lambda **_kwargs: events.append("wait"))
    monkeypatch.setattr(_bridge, "process_alive", lambda _pid: live)
    _overseer.stop_bridge(cast(subprocess.Popen[bytes], process), home)
    assert events == ["kill", "wait"]
    assert pid_file.exists() == live


def test_bridge_start_uses_direct_python_logs_and_repo(home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    launch = _overseer.Launch(command="fixture", arguments=[], bridge=[sys.executable, "fake bridge"], bot_folder=str(home))
    calls = []

    def start(command: object, **kwargs: object) -> SimpleNamespace:
        calls.append((command, kwargs))
        return SimpleNamespace(pid=123)

    monkeypatch.setattr(_overseer.subprocess, "CREATE_NO_WINDOW", 0x08000000, raising=False)
    monkeypatch.setattr(_overseer.subprocess, "Popen", start)
    assert _overseer.start_bridge(launch, repo) is not None
    assert calls[0][0] == launch.bridge
    assert calls[0][1]["cwd"] == repo
    assert calls[0][1].get("creationflags", 0) == 0
    assert calls[0][1]["stdin"] == subprocess.DEVNULL
    assert calls[0][1]["stdout"].name == str(home / "bridge.log")
    assert calls[0][1]["stderr"].name == str(home / "bridge.err")
    assert (home / "bridge.log").exists()
    assert (home / "bridge.err").exists()


def test_dry_run_shows_bridge_and_creates_nothing(home: Path, repo: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setattr(_overseer, "interactive", lambda: False)
    assert _overseer.run(repo, home, account="codex-a", dry_run=True) == 0
    output = capsys.readouterr().out
    assert "bridge:" in output
    assert "telegram bridge --channel main --repo" in output
    assert not history(home).exists()
    assert not (home / ".legion/channels").exists()


def test_windows_batch_uses_existing_literal_transport(repo: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    launch = _overseer.Launch(command="fixture.cmd", arguments=["< > | & ^ %", "", "two words"])
    calls = []
    monkeypatch.setattr(_overseer, "WINDOWS", True)
    monkeypatch.setattr(_overseer.subprocess, "run", lambda command, **_kwargs: calls.append(command) or SimpleNamespace(returncode=0))
    assert _overseer.start_launch(repo, launch, in_place=True, dry_run=False) == 0
    assert calls == [_run._cmd_line([launch.command, *launch.arguments])]


def test_python_module_bridge_needs_no_uv(home: Path, repo: Path) -> None:
    result = subprocess.run(
        [sys.executable, "-m", "legion.cli", "--home", str(home), "telegram", "bridge", "--channel", "main", "--repo", str(repo)],
        env={**os.environ, "PATH": ""},
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 1
    assert "no bot token for channel 'main'" in result.stderr
    assert not (home / ".legion/channels").exists()
