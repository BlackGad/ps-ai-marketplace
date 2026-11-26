# Foundry account commands against a fake az; ported from the PowerShell AccountFoundry, FoundryClaudeAliases and ToolAdapters tests.
import json
import re
from pathlib import Path

import pytest
from launcher_fakes import ready_app
from test_foundry_run import (
    ENDPOINT,
    ACCESS_CALL,
    TOKEN_ANSWER,
    Bench,
)

from legion.services.accounts import _accounts
from legion.core import _settings_io
from legion.core._home import settings_path
from legion.services.accounts._launchers import LauncherError, launcher_paths
from legion.core._settings_models import Agent, PersonalisationSettings
from legion.core._validate import settings_issues
from legion.services.foundry import codex

LIST_KEY = "cognitiveservices account list -o json"
DEPLOYMENTS_KEY = "cognitiveservices account deployment list --name res-a --resource-group rg-a -o json"
CLAUDE_ROWS = [{"name": name, "properties": {"model": {"name": name}}} for name in ("claude-opus-x", "claude-sonnet-x", "gpt-x")]
ANSWERS = {
    ACCESS_CALL: TOKEN_ANSWER,
    LIST_KEY: {"stdout": '[{"name":"res-a","resourceGroup":"rg-a"}]'},
    DEPLOYMENTS_KEY: {"stdout": json.dumps(CLAUDE_ROWS)},
}
Selection = tuple[list[str], str, list[str]]
SELECTION: Selection = (["claude-opus-x", "claude-sonnet-x"], "claude-opus-x", ["claude-opus-x=opus", "claude-sonnet-x=sonnet"])


@pytest.fixture
def bench(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Bench:
    bench = Bench(tmp_path, monkeypatch, with_agents=False)
    bench.answers(ANSWERS)
    return bench


def add(bench: Bench, account: str = "claude-dev", *, list_only: bool = False) -> list[str]:
    names, default, aliases = SELECTION
    return _accounts.add_foundry(bench.home, account, "claude", f"{ENDPOINT}/anthropic", names, default, aliases, False, list_only)


def models(bench: Bench, selection: Selection = SELECTION, *, list_only: bool = False) -> list[str]:
    names, default, aliases = selection
    return _accounts.models(bench.home, "claude-dev", names, default, aliases, False, list_only)


def saved(bench: Bench) -> PersonalisationSettings:
    return _settings_io.load(bench.home)


def az_calls(bench: Bench) -> int:
    return len(bench.calls("az"))


def test_list_prints_the_matching_deployments_changes_nothing_and_needs_no_ready_app(bench: Bench) -> None:
    before = settings_path(bench.home).read_bytes()
    [output] = add(bench, list_only=True)
    assert output.lstrip().startswith("{")
    listed = json.loads(output)
    assert list(listed) == ["source", "error", "deployments"]
    assert listed["source"] == "management"
    assert [item["name"] for item in listed["deployments"]] == ["claude-opus-x", "claude-sonnet-x"]
    assert [item["state"] for item in listed["deployments"]] == ["new", "new"]
    assert settings_path(bench.home).read_bytes() == before
    assert list((bench.home / ".legion" / "bin").iterdir()) == []


def test_add_without_a_ready_app_refuses_before_any_write_or_az_call(bench: Bench) -> None:
    before = settings_path(bench.home).read_bytes()
    with pytest.raises(LauncherError, match="the legion app is not ready; run legion setup"):
        add(bench)
    assert settings_path(bench.home).read_bytes() == before
    assert az_calls(bench) == 0
    assert not (bench.home / ".legion" / "agents" / "claude-dev" / "settings.json").exists()
    assert list((bench.home / ".legion" / "bin").iterdir()) == []


def test_add_saves_the_account_writes_the_picker_and_launchers_and_a_repeat_changes_nothing(bench: Bench) -> None:
    ready_app(bench.home)
    folder = bench.home / ".legion" / "agents" / "claude-dev"
    folder.mkdir(parents=True)
    (folder / "settings.json").write_text('{"theme":"dark"}', encoding="utf-8")
    add(bench)
    settings = _settings_io.load(bench.home)
    agent = settings.agents[0]
    assert agent.provider is not None
    assert agent.provider.endpoint == ENDPOINT
    assert agent.provider.deployments[0].model == "claude-opus-x"
    assert agent.provider.deployments[1].alias == "sonnet"
    assert agent.command is None
    assert settings_issues(settings) == []
    picker = json.loads((folder / "settings.json").read_text(encoding="utf-8"))
    assert picker["theme"] == "dark"
    assert picker["modelPicker"]["replaceBuiltInOptions"] is True
    assert [item["model"] for item in picker["modelPicker"]["options"]] == ["claude-opus-x", "claude-sonnet-x"]
    assert [item["label"] for item in picker["modelPicker"]["options"]] == ["claude-opus-x", "claude-sonnet-x"]
    launchers = launcher_paths("claude-dev", bench.home)
    assert all(path.is_file() for path in launchers)
    tracked = [settings_path(bench.home), folder / "settings.json", *launchers]
    stamps = [(path.read_bytes(), path.stat().st_mtime_ns) for path in tracked]
    calls = az_calls(bench)
    assert add(bench) == ["skip: account claude-dev (already done)"]
    assert az_calls(bench) == calls
    assert models(bench) == ["skip: models claude-dev (no changes)"]
    assert [(path.read_bytes(), path.stat().st_mtime_ns) for path in tracked] == stamps


def test_repeat_foundry_add_repairs_missing_launcher_without_discovery(bench: Bench) -> None:
    ready_app(bench.home)
    add(bench)
    for path in launcher_paths("claude-dev", bench.home):
        path.unlink()
    calls = az_calls(bench)
    lines = add(bench)
    assert all(path.is_file() for path in launcher_paths("claude-dev", bench.home))
    assert any(line.startswith("wrote: launcher ") for line in lines)
    assert az_calls(bench) == calls


def test_an_account_for_a_tool_with_the_same_id_is_refused_without_az_when_the_launchers_collide(bench: Bench) -> None:
    ready_app(bench.home)
    owner_file = bench.home / ".legion" / "bin" / "claude-dev"
    owner_file.write_text("owner file", encoding="utf-8")
    with pytest.raises(LauncherError, match="wrapper collision"):
        add(bench)
    assert az_calls(bench) == 0
    assert owner_file.read_text(encoding="utf-8") == "owner file"


def test_models_refuses_a_default_that_is_not_selected_and_leaves_settings_alone(bench: Bench) -> None:
    ready_app(bench.home)
    add(bench)
    before = settings_path(bench.home).read_bytes()
    with pytest.raises(ValueError, match="default 'x' is not one of --deployment"):
        models(bench, (["claude-opus-x"], "x", []))
    assert settings_path(bench.home).read_bytes() == before


def test_models_list_marks_new_kept_and_gone_and_a_failed_discovery_never_marks_gone(bench: Bench) -> None:
    ready_app(bench.home)
    add(bench)
    before = settings_path(bench.home).read_bytes()
    rows = [CLAUDE_ROWS[0], {"name": "claude-haiku-x", "properties": {"model": {"name": "claude-haiku-x"}}}]
    bench.answers({**ANSWERS, DEPLOYMENTS_KEY: {"stdout": json.dumps(rows)}})
    states = {item["name"]: item["state"] for item in json.loads(models(bench, list_only=True)[0])["deployments"]}
    assert states == {"claude-opus-x": "kept", "claude-haiku-x": "new", "claude-sonnet-x": "gone"}
    bench.answers({ACCESS_CALL: TOKEN_ANSWER})
    listed = json.loads(models(bench, list_only=True)[0])
    assert listed["source"] == "none"
    assert [item["state"] for item in listed["deployments"]] == ["kept", "kept"]
    assert "unexpected fake az call" in listed["error"]
    assert settings_path(bench.home).read_bytes() == before
    models(bench)
    assert settings_path(bench.home).read_bytes() == before


def test_models_changes_default_aliases_and_picker_and_prints_nothing(bench: Bench) -> None:
    ready_app(bench.home)
    add(bench)
    rows = [CLAUDE_ROWS[0], {"name": "claude-haiku-x", "properties": {"model": {"name": "claude-haiku-x"}}}]
    bench.answers({**ANSWERS, DEPLOYMENTS_KEY: {"stdout": json.dumps(rows)}})
    assert models(bench, (["claude-opus-x", "claude-haiku-x"], "claude-haiku-x", ["claude-opus-x=opus", "claude-haiku-x=haiku"])) == []
    provider = saved(bench).agents[0].provider
    assert provider is not None
    assert provider.default == "claude-haiku-x"
    assert provider.deployments[1].alias == "haiku"
    picker = json.loads((bench.home / ".legion" / "agents" / "claude-dev" / "settings.json").read_text(encoding="utf-8"))
    assert [item["model"] for item in picker["modelPicker"]["options"]] == ["claude-opus-x", "claude-haiku-x"]


def test_unreadable_claude_settings_stop_add_and_leave_everything_as_it_was(bench: Bench) -> None:
    ready_app(bench.home)
    add(bench)
    folder = bench.home / ".legion" / "agents" / "claude-bad"
    folder.mkdir(parents=True)
    (folder / "settings.json").write_text("{bad", encoding="utf-8")
    with pytest.raises(ValueError, match=r"settings\.json is not valid JSON; fix or remove it"):
        add(bench, "claude-bad")
    assert (folder / "settings.json").read_text(encoding="utf-8") == "{bad"
    assert len(_settings_io.load(bench.home).agents) == 1


def test_rename_moves_a_foundry_account_and_rewrites_its_launchers(bench: Bench) -> None:
    ready_app(bench.home)
    add(bench)
    _accounts.rename(bench.home, "claude-dev", "claude-new")
    assert [agent.id for agent in _settings_io.load(bench.home).agents] == ["claude-new"]
    assert not any(path.exists() for path in launcher_paths("claude-dev", bench.home))
    for path in launcher_paths("claude-new", bench.home):
        assert "foundry run --account" in path.read_text(encoding="utf-8")
        assert "claude-new" in path.read_text(encoding="utf-8")
        assert "claude-dev" not in path.read_text(encoding="utf-8")


# Each case is the old config and the text that must survive; lines are joined so the quotes stay readable.
def toml(*lines: str) -> str:
    return "\n".join(lines) + "\n"


TRIPLE = '"""'
LITERAL_TRIPLE = "'''"
INSTRUCTIONS = ["Escaped delimiter: \\" + TRIPLE, "[model_providers.legion-foundry]", 'model = "preserved-prompt"']
ESCAPED_END = TRIPLE + " # comment with " + LITERAL_TRIPLE + " and [model_providers.legion-foundry.auth]"
ESCAPED_KEPT = toml("developer_instructions = " + TRIPLE, *INSTRUCTIONS, ESCAPED_END)

CODEX_TOML = [
    (
        toml(
            '"model" = "old-model"',
            "'model_provider' = \"old-provider\"",
            'approval_policy = "never"',
            '[model_providers."legion-foundry"]',
            'base_url = "old-endpoint"',
            "[model_providers.'legion-foundry'.auth]",
            'command = "old-command"',
            "[other]",
            "value = 1",
        ),
        toml("[other]", "value = 1"),
    ),
    (
        toml("developer_instructions = " + TRIPLE, "[context]", "Preserve these instructions.", TRIPLE, 'model = "old-model"', 'model_provider = "old-provider"', 'approval_policy = "never"'),
        toml("developer_instructions = " + TRIPLE, "[context]", "Preserve these instructions.", TRIPLE),
    ),
    (
        toml(
            "# Comment with " + TRIPLE + " and [model_providers.legion-foundry]",
            "developer_instructions = " + TRIPLE,
            *INSTRUCTIONS,
            ESCAPED_END,
            'note = "escaped quote: \\" and triple apostrophes ' + LITERAL_TRIPLE + '" # ' + TRIPLE,
            'approval_policy = "never"',
            'model = "old-model"',
            'model_provider = "old-provider"',
            "[model_providers.legion-foundry] # " + LITERAL_TRIPLE,
            'base_url = "old-endpoint"',
            "[model_providers.legion-foundry.auth] # " + TRIPLE,
            'command = "old-command"',
            "[other] # " + TRIPLE,
            "value = 1",
        ),
        ESCAPED_KEPT,
    ),
    (
        toml("matrix = [", "  [1, 2],", "  [3, 4], # comment with " + TRIPLE, "]", 'model = "old-model"', 'model_provider = "old-provider"', 'approval_policy = "never"'),
        toml("matrix = [", "  [1, 2],", "  [3, 4], # comment with " + TRIPLE, "]"),
    ),
    (
        toml(
            "developer_instructions = " + LITERAL_TRIPLE,
            "[model_providers.legion-foundry]",
            "Preserve these instructions.",
            LITERAL_TRIPLE,
            'model = "old-model"',
            'model_provider = "old-provider"',
            'approval_policy = "never"',
        ),
        toml("developer_instructions = " + LITERAL_TRIPLE, "[model_providers.legion-foundry]", "Preserve these instructions.", LITERAL_TRIPLE),
    ),
    (
        toml(
            'approval_policy = "never"',
            'model = "old"',
            'model_provider = "old"',
            "[model_providers.legion-foundry]",
            'base_url = "old"',
            "obsolete = true",
            "[model_providers.legion-foundry.auth]",
            'command = "old"',
            "[other]",
            'model = "kept-nested"',
            "value = 1",
        ),
        toml("[other]", 'model = "kept-nested"', "value = 1"),
    ),
]


@pytest.mark.parametrize(("text", "preserved"), CODEX_TOML)
def test_codex_config_replaces_only_the_foundry_keys_and_keeps_the_rest(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, text: str, preserved: str) -> None:
    folder = tmp_path / "config"
    folder.mkdir()
    (folder / "config.toml").write_bytes(text.encode("utf-8"))
    monkeypatch.setattr(codex, "az", lambda: Path("/fake/az"))
    agent = Agent.model_validate(
        {"id": "codex-a", "tool": "codex", "configDir": str(folder), "provider": {"kind": "foundry", "endpoint": ENDPOINT, "default": "gpt-x", "deployments": [{"name": "gpt-x"}]}}
    )
    assert codex.configure(agent, tmp_path)
    content = (folder / "config.toml").read_text(encoding="utf-8")
    assert not any(old in content for old in ("old-model", "old-provider", "old-endpoint", "old-command", '"old"'))
    assert preserved in content
    assert 'approval_policy = "never"' in content
    assert len(re.findall(r"(?m)^['\"]?model_provider['\"]? = ", content)) == 1
    assert f'base_url = "{ENDPOINT}/openai/v1"' in content
    assert 'wire_api = "responses"' in content
    assert "refresh_interval_ms = 1800000" in content
    assert json.dumps(str(Path("/fake/az")))[1:-1] in content
    assert '"--resource", "https://cognitiveservices.azure.com", "--query", "accessToken", "-o", "tsv"' in content
    assert not codex.configure(agent, tmp_path)
