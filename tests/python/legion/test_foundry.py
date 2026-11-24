import json
import os
import signal
import stat
import sys
from types import ModuleType, SimpleNamespace
from typing import Any
from contextlib import AbstractContextManager
from pathlib import Path

import pytest
from cli_runner import run

from legion import _accounts, _settings_io
from legion._home import settings_path
from legion._settings_models import Agent, Deployment, Provider, ToolDescriptor
from legion._settings_io import SettingsError
from legion._validate import load_descriptors
from legion.foundry import _discovery, claude, codex
from legion.foundry import _run
from legion.foundry._az import AzAccessToken
from legion.foundry import _az, copilot
from legion.foundry._types import Launch, ProviderFile
from test_limits import write_executable
from legion.foundry._discovery import DiscoveredDeployment, FoundryDiscovery, listing, standard


def codex_agent(folder: Path) -> Agent:
    provider = Provider(kind="foundry", endpoint="https://example.test", default="gpt-4", deployments=[Deployment(name="gpt-4")])
    return Agent.model_validate({"id": "codex-a", "tool": "codex", "configDir": str(folder), "provider": provider.model_dump(by_alias=True, exclude_none=True)})


def claude_agent(folder: Path) -> Agent:
    provider = Provider(kind="foundry", endpoint="https://example.test", default="m", deployments=[Deployment(name="m")])
    return Agent.model_validate({"id": "claude-a", "tool": "claude", "configDir": str(folder), "provider": provider.model_dump(by_alias=True, exclude_none=True)})


@pytest.mark.parametrize(("recipe", "filename", "original"), [(codex, "config.toml", b'theme = "dark"\n'), (claude, "settings.json", b'{"theme":"dark"}\n')])
def test_failed_config_write_keeps_previous_bytes(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, recipe: ModuleType, filename: str, original: bytes) -> None:
    folder = tmp_path / "account"
    folder.mkdir()
    path = folder / filename
    path.write_bytes(original)
    monkeypatch.setattr(codex, "az", lambda: Path("/fake/az"))
    real_write = Path.write_text

    def interrupted_write(target: Path, content: str, **keywords: Any) -> int:
        if target.suffix == ".tmp":
            real_write(target, content[:4], **keywords)
            raise OSError("disk full")
        return real_write(target, content, **keywords)

    monkeypatch.setattr(Path, "write_text", interrupted_write)
    agent = codex_agent(folder) if recipe is codex else claude_agent(folder)
    with pytest.raises(OSError, match="disk full"):
        recipe.configure(agent, tmp_path)
    assert path.read_bytes() == original


def test_foundry_add_discovers_before_settings_lock(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    home.mkdir()
    events: list[str] = []

    def discover(*_args: object) -> _discovery.FoundryDiscovery:
        events.append("discover")
        return _discovery.FoundryDiscovery(source="management", error="", deployments=[_discovery.DiscoveredDeployment(name="gpt-4", model="gpt-4")])

    original_writer = _settings_io.writer

    def writer(home_path: Path, *, require_existing: bool = True) -> AbstractContextManager[None]:
        events.append("lock")
        return original_writer(home_path, require_existing=require_existing)

    monkeypatch.setattr(_discovery, "discover", discover)
    monkeypatch.setattr(_settings_io, "writer", writer)
    monkeypatch.setattr(_accounts, "_check_new_id", lambda *_args: None)
    monkeypatch.setattr("legion.foundry.claude.configure", lambda *_args: False)
    monkeypatch.setattr("legion._launchers.write_foundry", lambda *_args: [])
    monkeypatch.setattr("legion._launchers.plan_foundry", lambda *_args: {})
    _accounts.add_foundry(home, "claude-a", "claude", "https://example.test", ["gpt-4"], "gpt-4", [], False, False)
    assert events[:2] == ["discover", "lock"]


def test_foundry_repeat_add_never_discovers(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    path = settings_path(home)
    path.parent.mkdir(parents=True)
    path.write_text(
        json.dumps(
            {
                "schemaVersion": 1,
                "agents": [
                    {
                        "id": "codex-a",
                        "tool": "codex",
                        "configDir": str(home / "folder"),
                        "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "gpt-4", "deployments": [{"name": "gpt-4"}]},
                    }
                ],
                "channels": [],
            }
        ),
        encoding="utf-8",
    )

    monkeypatch.setattr(_discovery, "discover", lambda *_args: pytest.fail("repeat add ran discovery"))
    assert _accounts.add_foundry(home, "codex-a", "codex", "https://example.test", ["gpt-4"], "gpt-4", [], False, False) == ["skip: account codex-a (already done)"]


def test_foundry_listing_gone_only_with_management() -> None:

    previous = [Deployment(name="old", model="gpt-old")]
    none = listing(FoundryDiscovery(source="none", error="offline", deployments=[]), previous)
    managed = listing(FoundryDiscovery(source="management", error="", deployments=[]), previous)
    assert none.deployments[0].state == "kept"
    assert managed.deployments[0].state == "gone"
    assert list(json.loads(managed.model_dump_json(indent=2))) == ["source", "error", "deployments"]


@pytest.mark.parametrize(
    "content",
    [
        b"# keep\nmodel = 'old'\n",
        b"\xef\xbb\xbfmodel = 'old'\r\n",
        b"prompt = '''[model_providers.legion-foundry]'''\n",
        b"prompt = '''\n[model_providers.legion-foundry]\n'''\nmodels = [\n  'keep',\n]\n",
        b"[model_providers.'legion-foundry']\nbase_url = 'old' # keep\n",
    ],
)
def test_codex_toml_preserves_unmanaged_text(tmp_path: Path, content: bytes, monkeypatch: pytest.MonkeyPatch) -> None:

    home = tmp_path / "home"
    folder = home / "config"
    folder.mkdir(parents=True)
    config = folder / "config.toml"
    config.write_bytes(content)
    monkeypatch.setattr(codex, "az", lambda: Path("/fake/az"))
    agent = codex_agent(folder)
    assert codex.configure(agent, home)
    result = config.read_bytes()
    if b"prompt" in content:
        assert b"[model_providers.legion-foundry]" in result
        assert b"prompt = '''" in result
    else:
        assert b"model =" in result
    assert result.startswith(b"\xef\xbb\xbf") == content.startswith(b"\xef\xbb\xbf")
    assert (b"\r\n" in result) == (b"\r\n" in content)
    assert not codex.configure(agent, home)
    assert config.read_bytes() == result


def test_invalid_toml_refused(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:

    home = tmp_path / "home"
    folder = home / "config"
    folder.mkdir(parents=True)
    (folder / "config.toml").write_text("broken = [", encoding="utf-8")
    monkeypatch.setattr(codex, "az", lambda: Path("/fake/az"))
    agent = codex_agent(folder)
    with pytest.raises(ValueError, match=r"config\.toml is not valid TOML"):
        codex.configure(agent, home)


@pytest.mark.parametrize("argument", ["--help", "--version", "--account", "--"])
def test_foundry_runner_forwards_tool_flags(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, argument: str) -> None:
    seen: list[str] = []

    def fake_run(_account: str, arguments: list[str], _home: Path) -> int:
        seen.extend(arguments)
        return 0

    monkeypatch.setattr(_run, "run", fake_run)
    assert run(["--home", str(tmp_path), "foundry", "run", "--account", "codex-a", "--", argument]) == 0
    assert seen == [argument]


def test_standard_compares_missing_numeric_part_as_zero() -> None:
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "codex")
    deployments = [DiscoveredDeployment(name="gpt-sol-4", model="gpt-sol"), DiscoveredDeployment(name="gpt-sol-4-0", model="gpt-sol")]
    with pytest.raises(ValueError, match="unresolved"):
        standard(deployments, descriptor)


def test_standard_tokens_ignore_case() -> None:
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "codex")
    deployments = [
        DiscoveredDeployment(name="GPT-SOL-5", model="GPT-SOL"),
        DiscoveredDeployment(name="gpt-other-9", model="gpt-other"),
        DiscoveredDeployment(name="gpt-fable-sol-10", model="gpt-fable"),
    ]
    assert standard(deployments, descriptor) == ("GPT-SOL-5", [])


def test_standard_claude_chooses_aliases_and_sonnet_default() -> None:
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "claude")
    deployments = [
        DiscoveredDeployment(name="claude-opus-4", model="claude-opus"),
        DiscoveredDeployment(name="claude-sonnet-5", model="claude-sonnet"),
        DiscoveredDeployment(name="claude-haiku-3", model="claude-haiku"),
        DiscoveredDeployment(name="claude-fable-99", model="claude-fable"),
    ]
    assert standard(deployments, descriptor) == (
        "claude-sonnet-5",
        ["claude-opus-4=opus", "claude-sonnet-5=sonnet", "claude-haiku-3=haiku"],
    )


def test_runner_does_not_pass_ignored_sigint_to_child(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    agent = Agent.model_validate(
        {
            "id": "codex-a",
            "tool": "codex",
            "configDir": str(tmp_path / "config"),
            "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "gpt-4", "deployments": [{"name": "gpt-4"}]},
        }
    )
    monkeypatch.setattr(_run._settings_io, "load", lambda _home: SimpleNamespace(agents=[agent]))
    monkeypatch.setattr(_run._launchers, "stock_command", lambda *_args: Path("/fake/codex"))
    monkeypatch.setattr(_run, "check_token", lambda: AzAccessToken.model_validate({"accessToken": "secret", "expires_on": 4102444800}))
    monkeypatch.setattr(_run, "recipe", lambda _agent: SimpleNamespace(launch=lambda *_args: Launch(set={}, clear=[])))
    monkeypatch.setattr(_run, "sys", SimpleNamespace(platform="linux"))

    class Child:
        def wait(self) -> int:
            return 0

    def popen(*_args: object, **_kwargs: object) -> Child:
        assert signal.getsignal(signal.SIGINT) != signal.SIG_IGN
        return Child()

    monkeypatch.setattr(_run.subprocess, "Popen", popen)
    assert _run.run("codex-a", [], tmp_path) == 0


def test_token_login_retries_once_and_reports_last_error(monkeypatch: pytest.MonkeyPatch) -> None:
    calls = 0

    def token() -> AzAccessToken:
        nonlocal calls
        calls += 1
        raise ValueError(f"token error {calls}")

    monkeypatch.setattr(_az, "token", token)
    monkeypatch.setattr(_az, "az", lambda: Path("/fake/az"))
    monkeypatch.setattr(_az.subprocess, "run", lambda *_args, **_kwargs: None)
    with pytest.raises(ValueError, match="token error 2"):
        _az.check_token()
    assert calls == 2


def test_invalid_foundry_alias_does_not_write_tool_config(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    home.mkdir()
    discovery = FoundryDiscovery(
        source="management",
        error="",
        deployments=[
            DiscoveredDeployment(name="claude-opus-1", model="claude-opus"),
            DiscoveredDeployment(name="claude-opus-2", model="claude-opus"),
        ],
    )
    monkeypatch.setattr(_discovery, "discover", lambda *_args: discovery)
    monkeypatch.setattr("legion._launchers.plan_foundry", lambda *_args: {})
    with pytest.raises(SettingsError, match="alias"):
        _accounts.add_foundry(home, "claude-a", "claude", "https://example.test", ["claude-opus-1", "claude-opus-2"], "claude-opus-1", ["claude-opus-1=opus", "claude-opus-2=opus"], False, False)
    assert not (home / ".legion" / "agents" / "claude-a" / "settings.json").exists()


def test_copilot_provider_file_is_exclusive_and_expiry_uses_injected_time(tmp_path: Path) -> None:
    folder = tmp_path / "temp"
    folder.mkdir()
    expired = folder / "copilot-providers-100-00000000-0000-0000-0000-000000000001.json"
    fresh = folder / "copilot-providers-200-00000000-0000-0000-0000-000000000002.json"
    expired.write_text("old", encoding="utf-8")
    fresh.write_text("new", encoding="utf-8")
    copilot.cleanup(folder, now=150)
    assert not expired.exists()
    assert fresh.read_text(encoding="utf-8") == "new"
    with pytest.raises(FileExistsError):
        copilot.write_provider(fresh, ProviderFile(providers=[], models=[]))
    assert fresh.read_text(encoding="utf-8") == "new"


def test_copilot_provider_json_uses_typed_camel_case_model(tmp_path: Path) -> None:
    agent = Agent.model_validate(
        {
            "id": "copilot-a",
            "tool": "copilot",
            "configDir": str(tmp_path / "config"),
            "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "claude-a", "deployments": [{"name": "claude-a"}]},
        }
    )
    token = AzAccessToken.model_validate({"accessToken": "secret", "expires_on": 4102444800})
    launch = copilot.launch(agent, tmp_path, token, now=1)
    assert launch.provider_file is not None
    assert isinstance(launch.provider_file[1], ProviderFile)
    data = json.loads(launch.provider_file[1].model_dump_json(by_alias=True))
    assert data["providers"][0]["bearerToken"] == "secret"
    assert data["models"][0]["wireModel"] == "claude-a"


@pytest.mark.skipif(os.name == "nt", reason="POSIX mode bits")
def test_copilot_provider_file_starts_private(tmp_path: Path) -> None:
    path = tmp_path / "provider.json"
    copilot.write_provider(path, ProviderFile(providers=[], models=[]))
    assert stat.S_IMODE(path.stat().st_mode) == 0o600


@pytest.mark.parametrize("failure", [False, True])
def test_copilot_runner_removes_provider_after_child(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, failure: bool, capsys: pytest.CaptureFixture[str]) -> None:
    agent = Agent.model_validate(
        {
            "id": "copilot-a",
            "tool": "copilot",
            "configDir": str(tmp_path / "config"),
            "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "claude-a", "deployments": [{"name": "claude-a"}]},
        }
    )
    monkeypatch.setattr(_run._settings_io, "load", lambda _home: SimpleNamespace(agents=[agent]))
    monkeypatch.setattr(_run._launchers, "stock_command", lambda *_args: Path("/fake/copilot"))
    monkeypatch.setattr(_run, "check_token", lambda: AzAccessToken.model_validate({"accessToken": "secret", "expires_on": 4102444800}))
    paths: list[Path] = []

    class Child:
        def wait(self) -> int:
            return 7

    def popen(_line: object, *, env: dict[str, str]) -> Child:
        path = Path(env["COPILOT_PROVIDERS_CONFIG"])
        paths.append(path)
        assert json.loads(path.read_text(encoding="utf-8"))["providers"][0]["bearerToken"] == "secret"
        if failure:
            raise OSError("fake child failed")
        return Child()

    monkeypatch.setattr(_run.subprocess, "Popen", popen)
    if failure:
        with pytest.raises(OSError, match="fake child failed"):
            _run.run("copilot-a", [], tmp_path)
    else:
        assert _run.run("copilot-a", [], tmp_path) == 7
    assert len(paths) == 1
    assert not paths[0].exists()
    assert "secret" not in str(capsys.readouterr())


def test_foundry_run_missing_settings_is_one_line(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--home", str(tmp_path), "foundry", "run", "--account", "missing", "--"]) == 1
    captured = capsys.readouterr()
    assert captured.out == ""
    assert captured.err == "No legion settings yet; add an agent first.\n"


def test_discovery_walks_default_then_subscription_and_filters_literal_prefix(monkeypatch: pytest.MonkeyPatch) -> None:
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "codex")
    calls: list[list[str]] = []

    def az_call(arguments: list[str]) -> str:
        calls.append(arguments)
        if arguments[:3] == ["cognitiveservices", "account", "list"] and "--subscription" not in arguments:
            return "[]"
        if arguments[:2] == ["account", "list"]:
            return "sub-a\n"
        if arguments[:3] == ["cognitiveservices", "account", "list"]:
            return '[{"name":"resource","resourceGroup":"group"}]'
        return '[{"name":"one","properties":{"model":{"name":"GPT-4"}}},{"name":"two","properties":{"model":{"name":"claude-4"}}}]'

    monkeypatch.setattr(_discovery, "check_token", lambda: None)
    monkeypatch.setattr(_discovery, "call", az_call)
    result = _discovery.discover("https://resource.example.test", descriptor)
    assert [(item.name, item.model) for item in result.deployments] == [("one", "GPT-4")]
    assert result.source == "management"
    assert calls[-1][-2:] == ["--subscription", "sub-a"]


def test_discovery_joins_az_errors(monkeypatch: pytest.MonkeyPatch) -> None:
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "codex")

    def az_call(arguments: list[str]) -> str:
        if arguments[:2] == ["account", "list"]:
            raise ValueError("subscription error")
        raise ValueError("account error")

    monkeypatch.setattr(_discovery, "check_token", lambda: None)
    monkeypatch.setattr(_discovery, "call", az_call)
    result = _discovery.discover("https://resource.example.test", descriptor)
    assert result.source == "none"
    assert result.error == "account error\nsubscription error"


def test_endpoint_normalizes_host_and_drops_path() -> None:
    assert _discovery.endpoint_url("https://RESOURCE.Example.TEST:443/project") == "https://resource.example.test"


def test_discovery_uses_fake_az_and_walks_subscriptions(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    bin_folder = tmp_path / "bin"
    logs = tmp_path / "logs"
    bin_folder.mkdir()
    logs.mkdir()
    answers = {
        "account get-access-token --resource https://cognitiveservices.azure.com -o json": {"stdout": '{"accessToken":"fake","expires_on":4102444800}'},
        "cognitiveservices account list -o json": {"stdout": "[]"},
        "account list --query [].id -o tsv": {"stdout": "sub-a\n"},
        "cognitiveservices account list -o json --subscription sub-a": {"stdout": '[{"name":"resource","resourceGroup":"group"}]'},
        "cognitiveservices account deployment list --name resource --resource-group group -o json --subscription sub-a": {"stdout": '[{"name":"gpt-4","properties":{"model":{"name":"GPT-4"}}}]'},
    }
    answers_path = tmp_path / "answers.json"
    answers_path.write_text(json.dumps(answers), encoding="utf-8")
    monkeypatch.setenv("PATH", str(bin_folder))
    monkeypatch.setenv("LEGION_FAKE_LOG", str(logs))
    monkeypatch.setenv("LEGION_FAKE_AZ_ANSWERS", str(answers_path))
    if sys.platform == "win32":
        monkeypatch.setenv("PATHEXT", ".COM;.EXE;.BAT;.CMD")
    write_executable(bin_folder, "az", {})
    descriptor = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "codex")
    result = _discovery.discover("https://resource.example.test", descriptor)
    assert [(item.name, item.model) for item in result.deployments] == [("gpt-4", "GPT-4")]
    calls = [json.loads(line)["arguments"] for line in (logs / "az.jsonl").read_text(encoding="utf-8").splitlines()]
    assert calls[-1][-2:] == ["--subscription", "sub-a"]


def test_models_uses_fresh_settings_after_discovery(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    path = settings_path(home)
    path.parent.mkdir(parents=True)
    data = {
        "schemaVersion": 1,
        "agents": [
            {
                "id": "claude-a",
                "tool": "claude",
                "configDir": str(home / "config"),
                "provider": {"kind": "foundry", "endpoint": "https://example.test", "default": "claude-a", "deployments": [{"name": "claude-a", "alias": "opus"}]},
            }
        ],
        "channels": [],
    }
    path.write_text(json.dumps(data), encoding="utf-8")

    def discover(*_args: object) -> FoundryDiscovery:
        data["agents"][0]["provider"]["deployments"][0]["alias"] = "sonnet"
        path.write_text(json.dumps(data), encoding="utf-8")
        return FoundryDiscovery(source="management", error="", deployments=[DiscoveredDeployment(name="claude-a", model="claude-a")])

    monkeypatch.setattr(_discovery, "discover", discover)
    monkeypatch.setattr(_accounts, "recipe", lambda _agent: SimpleNamespace(configure=lambda *_args: False))
    monkeypatch.setattr("legion._launchers.write_foundry", lambda *_args: [])
    _accounts.models(home, "claude-a", ["claude-a"], "claude-a", None, False, False)
    assert json.loads(path.read_text(encoding="utf-8"))["agents"][0]["provider"]["deployments"][0]["alias"] == "sonnet"


def test_copilot_cleanup_survives_a_file_that_another_launch_just_removed(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    gone = tmp_path / "copilot-providers-100-00000000-0000-0000-0000-000000000001.json"
    monkeypatch.setattr(Path, "glob", lambda _self, _pattern: [gone])
    copilot.cleanup(tmp_path, now=150)


def test_tool_with_foundry_descriptor_but_no_recipe_is_refused_in_one_line_before_az(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    fourth = next(item for item in load_descriptors(ToolDescriptor, "tool.json") if item.id == "codex").model_copy(update={"id": "fourth"})
    monkeypatch.setattr(_accounts, "get_tool", lambda _tool_id: fourth)
    monkeypatch.setattr(_discovery, "discover", lambda *_args: pytest.fail("az ran"))
    with pytest.raises(_accounts.AccountError, match="tool 'fourth' does not support Foundry"):
        _accounts.add_foundry(tmp_path, "fourth-a", "fourth", "https://example.test", ["m"], "m", [], False, False)


def test_codex_config_that_already_says_the_same_is_left_alone_in_any_quote_style(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / "config"
    folder.mkdir(parents=True)
    monkeypatch.setattr(codex, "az", lambda: Path("/fake/az"))
    agent = codex_agent(folder)
    assert codex.configure(agent, home)
    config = folder / "config.toml"
    text = config.read_text(encoding="utf-8")
    text = text.replace('model = "gpt-4"', "model = 'gpt-4'")
    start = text.index("args = [")
    end = text.index("]", start) + 1
    text = text[:start] + 'args = [\n  "account",\n  "get-access-token",\n  "--resource",\n  "https://cognitiveservices.azure.com",\n  "--query",\n  "accessToken",\n  "-o",\n  "tsv",\n]' + text[end:]
    config.write_bytes(text.encode("utf-8"))
    assert not codex.configure(agent, home)
    assert config.read_bytes() == text.encode("utf-8")


@pytest.mark.parametrize("newline", ["\n", "\r\n"])
def test_claude_settings_with_a_byte_order_mark_keep_it_and_are_not_rewritten_when_unchanged(tmp_path: Path, newline: str) -> None:
    home = tmp_path / "home"
    folder = home / "config"
    folder.mkdir(parents=True)
    agent = claude_agent(folder)
    path = folder / "settings.json"
    path.write_bytes(b"\xef\xbb\xbf" + b'{"theme": "dark"}' + newline.encode())
    assert claude.configure(agent, home)
    written = path.read_bytes()
    assert written.startswith(b"\xef\xbb\xbf")
    assert (b"\r\n" in written) == (newline == "\r\n")
    assert not claude.configure(agent, home)
    assert path.read_bytes() == written


def test_claude_settings_that_are_not_json_are_refused_and_left_as_they_are(tmp_path: Path) -> None:
    folder = tmp_path / "config"
    folder.mkdir()
    (folder / "settings.json").write_text("[1]", encoding="utf-8")
    agent = claude_agent(folder)
    with pytest.raises(ValueError, match=r"settings\.json is not valid JSON; fix or remove it"):
        claude.configure(agent, tmp_path)
    assert (folder / "settings.json").read_text(encoding="utf-8") == "[1]"
