# Setup and add against fakes: fake CLIs on a private PATH, a fake uv, no real winget, npm, installer or network.
# The account, app and tool-install code under it runs for real; only the two outside seams are fakes:
# the CLI install (`install_tool`) and the plugin install (`install_plugin`).
import json
import os
import stat
import subprocess
from pathlib import Path
from typing import Any, Optional

import pytest
from app_fakes import FakeUv, make_source
from click.testing import CliRunner
from cli_runner import run
from filelock import FileLock, Timeout
from launcher_fakes import (
    WINDOWS,
    fake_cli,
    login,
    only_on_path,
)

from legion.services.accounts import _accounts, _setup
from legion.services.installation import (
    _installed_runtime,
    _knowledge_hub,
    installer as _installer,
    _refresh,
    _tool_install,
)
from legion.services.status import _status
from legion.services.status import status
from legion import cli
from legion.services.repository import _footprints
from legion.services.installation import _user_path
from legion.core._home import bin_folder, footprint_index, settings_path
from legion.core._plugin import PLUGIN_ROOT
from legion.core._run import RunResult
from legion.core._settings_models import ToolDescriptor
from legion.core._validate import load_descriptors

REAL_INSTALL_TOOL = _setup.install_tool
REAL_INSTALL_PLUGIN = _setup.install_plugin
VERSION = "1.0.0"
RULE = "Bash(LEGION_ROLE=member *)"
posix_only = pytest.mark.skipif(WINDOWS, reason="POSIX file modes and shell profile")
windows_only = pytest.mark.skipif(not WINDOWS, reason="Windows user PATH")


def descriptor(tool_id: str) -> ToolDescriptor:
    return next(tool for tool in load_descriptors(ToolDescriptor, "tool.json") if tool.id == tool_id)


class Bench:
    def __init__(self, base: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        self.base = base
        self.monkeypatch = monkeypatch
        self.home = base / "home"
        self.home.mkdir()
        self.tools = base / "tools"
        for name, variable in (("claude", "CLAUDE_CONFIG_DIR"), ("codex", "CODEX_HOME"), ("copilot", "COPILOT_HOME"), ("claude1", "CLAUDE_CONFIG_DIR")):
            fake_cli(self.tools, name, variable)
        only_on_path(monkeypatch, self.tools)
        monkeypatch.setenv("SHELL", "/bin/bash")
        self.user_path_file = base / "user-path.txt"
        self.user_path_file.write_text("fixture-path", encoding="utf-8")
        monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(self.user_path_file))
        monkeypatch.setattr(_user_path, "persistent_folders", list)
        self.uv = FakeUv(monkeypatch)
        self.source = make_source(base, VERSION)
        real_refresh = _refresh.refresh
        monkeypatch.setattr(_refresh, "refresh", lambda home, **keywords: real_refresh(home, self.source, **keywords))
        self.tool_installs: list[str] = []
        self.tool_failure = ""
        self.needs_terminal = False
        self.plugin_installs: list[tuple[str, Path, Optional[str]]] = []
        self.failing_folder: Optional[Path] = None
        monkeypatch.setattr(_setup, "install_tool", self.install_tool)
        monkeypatch.setattr(_setup, "install_plugin", self.install_plugin)

    # --- fakes ---

    def install_tool(self, _home: Path, tool_id: str) -> Optional[str]:
        self.tool_installs.append(tool_id)
        if self.tool_failure:
            return self.tool_failure
        if not self.needs_terminal:
            fake_cli(self.tools, tool_id, descriptor(tool_id).config_env)
        return None

    def install_plugin(self, tool_id: str, folder: Path, home: Path, source: Optional[str]) -> int:
        self.plugin_installs.append((tool_id, folder, source))
        if self.failing_folder is not None and _setup.same_path(folder, self.failing_folder):
            return 1
        manifest = folder / (descriptor(tool_id).plugin.installed_root or "") / VERSION / "plugin.json"
        manifest.parent.mkdir(parents=True, exist_ok=True)
        manifest.write_text(json.dumps({"name": "legion", "version": VERSION}), encoding="utf-8")
        return 0

    # --- calls ---

    def hide(self, name: str) -> None:
        for path in self.tools.glob(f"{name}*"):
            if path.stem == name:
                path.unlink()

    def preview(self, tool: Optional[str] = None, folder: Optional[Path] = None, account_id: Optional[str] = None) -> list[str]:
        return _setup.preview(self.home, tool, str(folder) if folder is not None else None, account_id)

    def apply(self, tool: Optional[str] = None, folder: Optional[Path] = None, account_id: Optional[str] = None) -> list[str]:
        lines: list[str] = []
        _setup.run(self.home, tool, str(folder) if folder is not None else None, account_id, None, True, lines.append)
        return lines

    def settings(self) -> dict[str, Any]:
        return json.loads(settings_path(self.home).read_text(encoding="utf-8"))

    def ids(self) -> list[str]:
        return [agent["id"] for agent in self.settings()["agents"]]

    def tree(self) -> dict[str, tuple[bytes, int]]:
        return {str(path.relative_to(self.home)): (path.read_bytes(), path.stat().st_mtime_ns) for path in sorted(self.home.rglob("*")) if path.is_file()}

    def folder(self, account: str) -> Path:
        return self.home / ".legion" / "agents" / account

    def seed(self, account: str, tool_id: str, command: Optional[Path] = None, folder: Optional[Path] = None) -> None:
        # An account as the verbs leave it: settings with its command when it has one.
        self.apply()
        data = self.settings()
        entry: dict[str, str] = {"id": account, "tool": tool_id, "configDir": str(folder or self.folder(account))}
        if command is not None:
            entry["command"] = str(command)
        data["agents"].append(entry)
        settings_path(self.home).write_text(json.dumps(data), encoding="utf-8")


@pytest.fixture
def bench(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Bench:
    monkeypatch.chdir(tmp_path)
    return Bench(tmp_path, monkeypatch)


def text(lines: list[str]) -> str:
    return "\n".join(lines)


@pytest.mark.parametrize(("answer", "saved"), [("y\n", True), ("\n", False), (None, None)])
def test_setup_remembers_the_knowledge_answer(bench: Bench, monkeypatch: pytest.MonkeyPatch, answer: Optional[str], saved: Optional[bool]) -> None:
    monkeypatch.setattr(_setup, "interactive", lambda: answer is not None)
    args = ["--home", str(bench.home), "setup", "--yes"]
    first = CliRunner().invoke(cli.main, args, input=answer)
    assert first.exit_code == 0, first.output
    question = "Install the llm-wiki knowledge base in every account? [y/N]"
    assert (question in first.output) == (answer is not None)
    assert bench.settings().get("knowledgeEnabled") is saved
    assert "skip: settings (already done)" not in first.output
    assert (bench.home / ".legion/knowledge/wikis.json").exists() is (saved is True)
    report = status(bench.base, bench.home)
    state = {True: "on", False: "declined", None: "off"}[saved]
    assert report.knowledge.state == state
    assert f"knowledge: {state}" in text(_status.status_lines(report))
    if saved is not None:
        repeat = CliRunner().invoke(cli.main, args)
        assert repeat.exit_code == 0, repeat.output
        assert question not in repeat.output


def test_knowledge_question_does_not_hold_the_settings_lock(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    bench.apply()
    monkeypatch.setattr(_setup, "interactive", lambda: True)

    def answer(*_args: object, **_options: object) -> bool:
        with FileLock(str(settings_path(bench.home)) + ".lock", timeout=0):
            return False

    monkeypatch.setattr(_setup.click, "confirm", answer)
    result = CliRunner().invoke(cli.main, ["--home", str(bench.home), "setup"])
    assert result.exit_code == 0, result.exception
    assert bench.settings()["knowledgeEnabled"] is False


def test_invalid_setup_leaves_no_settings_even_with_a_knowledge_choice(bench: Bench) -> None:
    with pytest.raises(_setup.SetupError, match="unknown tool"):
        _setup.run(bench.home, "unknown", None, None, None, True, lambda _: None, knowledge=True)
    assert not settings_path(bench.home).exists()


def test_unattended_setup_prints_the_plan_and_repairs_the_hub(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_setup, "interactive", lambda: False)
    args = ["--home", str(bench.home), "setup"]
    assert CliRunner().invoke(cli.main, [*args, "--yes", "--knowledge"]).exit_code == 0
    log = bench.home / ".legion/knowledge/log.md"
    log.unlink()
    first = CliRunner().invoke(cli.main, args)
    assert first.exit_code == 0, first.output
    assert "Nothing to do." in first.output
    assert log.is_file()
    assert "done: knowledge hub" in first.output
    repeat = CliRunner().invoke(cli.main, args)
    assert "skip: knowledge hub (already done)" in repeat.output
    assert "skip: llm-wiki hub pointer (already done)" in repeat.output


@pytest.mark.parametrize("tool", ["claude", "codex", "copilot"])
def test_knowledge_adopts_the_plugin_and_follows_later_accounts(bench: Bench, monkeypatch: pytest.MonkeyPatch, tool: str) -> None:
    wiki = "wiki@llm-wiki"
    first_id, later_id = f"wiki-{tool}-a", f"wiki-{tool}-b"
    bench.apply(tool, account_id=first_id)
    first, later = bench.folder(first_id), bench.folder(later_id)
    markets = {(first, "llm-wiki"): ("example/wiki-fork", "main")}
    plugins = {(first, wiki)}
    calls: list[tuple[Path, list[str]]] = []
    entry = descriptor(tool)
    hub = bench.home / ".legion/knowledge"
    pointer = bench.home / ".config/llm-wiki/config.json"
    fail_later = False

    def fake_run(_program: str, args: list[str], *, env: dict[str, str], **_options: object) -> RunResult:
        folder = Path(env[entry.config_env])
        calls.append((folder, args))
        output = ""
        legion = folder / (entry.plugin.installed_root or "") / VERSION
        if args == entry.plugin.marketplace_list:
            market_rows: list[dict[str, object]] = []
            for (account, name), (source, ref) in markets.items():
                if account != folder:
                    continue
                url = f"https://github.com/{source}.git"
                if tool == "codex":
                    market_rows.append({"name": name, "root": str(folder), "marketplaceSource": {"sourceType": "git", "source": url}})
                    (folder / "config.toml").write_text(f'[marketplaces.{name}]\nsource = "{url}"\nref = "{ref}"\n', encoding="utf-8")
                elif tool == "claude":
                    market_rows.append({"name": name, "source": "github", "repo": source, "ref": ref, "installLocation": str(folder)})
                else:
                    market_rows.append({"name": name, "source": f"GitHub: {source}", "isDefault": False})
                    data = {"extraKnownMarketplaces": {name: {"source": {"source": "github", "repo": source, "ref": ref}}}}
                    (folder / "settings.json").write_text(json.dumps(data), encoding="utf-8")
            output = json.dumps({"marketplaces": market_rows} if tool == "codex" else market_rows)
        elif args == entry.plugin.list_command:
            ids = [plugin for account, plugin in plugins if account == folder]
            rows = [{"id": plugin, "enabled": True} for plugin in ids]
            if (legion / "plugin.json").is_file():
                rows.append({"id": "legion@ps-legion-marketplace", "enabled": True, "installPath": str(legion)})
            output = json.dumps(rows) if tool == "claude" else "\n".join(f"{row['id']} {VERSION} {row.get('installPath', '')}".rstrip() for row in rows)
        elif tool == "codex" and args[:3] == ["plugin", "marketplace", "upgrade"]:
            assert args[3:] == ["ps-legion-marketplace"]
        elif args in (entry.plugin.marketplace_update, entry.plugin.update, entry.plugin.uninstall):
            pass
        elif args[:3] == ["plugin", "marketplace", "add"]:
            assert all((hub / name).is_file() for name in ("wikis.json", "log.md", "_index.md"))
            assert (hub / "topics").is_dir()
            assert json.loads(pointer.read_bytes()) == {"hub_path": "~/.legion/knowledge"}
            pin = ["nvk/llm-wiki", "--ref", "v1.0.0"] if tool == "codex" else ["nvk/llm-wiki#v1.0.0"]
            assert args[3:] == pin
            markets[folder, "llm-wiki"] = ("nvk/llm-wiki", "v1.0.0")
        elif args[:3] == ["plugin", "marketplace", "remove"]:
            assert (folder, wiki) not in plugins
            markets.pop((folder, args[3]))
        elif args[1] in ("remove", "uninstall"):
            plugins.remove((folder, args[2]))
        else:
            assert args == ["plugin", "add" if tool == "codex" else "install", wiki]
            if fail_later and folder == later:
                return RunResult(exit_code=1, output="", error="fixture plugin failure", timed_out=False)
            plugins.add((folder, wiki))
            cache = "installed-plugins" if tool == "copilot" else "plugins/cache"
            manifest = folder / cache / "llm-wiki/wiki" / VERSION / "plugin.json"
            manifest.parent.mkdir(parents=True, exist_ok=True)
            manifest.write_text(json.dumps({"name": "wiki", "version": VERSION}), encoding="utf-8")
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", fake_run)
    args = ["--home", str(bench.home), "setup", "--knowledge"]
    result = CliRunner().invoke(cli.main, args)
    assert result.exit_code == 0, result.output
    assert markets[first, "llm-wiki"] == ("nvk/llm-wiki", "v1.0.0"), result.output
    assert (first, wiki) in plugins
    assert any(command[1] in ("uninstall", "remove") for _, command in calls)
    assert bench.settings()["knowledgeEnabled"] is True
    calls.clear()
    fail_later = True
    lines = bench.apply(tool, account_id=later_id)
    assert plugins == {(first, wiki)}
    assert f"knowledge: {later_id}:" in text(lines)
    assert "fixture plugin failure" in text(lines)
    assert _status.installed_version(later, entry) == VERSION
    assert all(folder != first or args in (entry.plugin.list_command, entry.plugin.marketplace_list) for folder, args in calls)
    (hub / "log.md").unlink()
    report = status(bench.base, bench.home)
    assert report.knowledge.missing_accounts == [later_id]
    assert report.knowledge.hub == "invalid"
    monkeypatch.setattr(_installer, "_hand_over", lambda *_: None)
    fail_later = False
    _installer.install(bench.home, [tool], config_dir=later, update=True, yes=True)
    assert (later, wiki) in plugins
    _installer.install(bench.home, [tool], config_dir=first, uninstall=True, yes=True)
    assert (first, wiki) not in plugins
    assert (first, "llm-wiki") not in markets
    assert hub.is_dir()
    assert pointer.is_file()


@pytest.mark.parametrize(("was_enabled", "fail_once", "missing_cli"), [(True, False, False), (True, True, False), (False, False, False), (True, False, True)])
def test_setup_no_knowledge_removes_only_managed_wiki(bench: Bench, monkeypatch: pytest.MonkeyPatch, was_enabled: bool, fail_once: bool, missing_cli: bool) -> None:
    if missing_cli:
        bench.seed("wiki-missing", "codex", command=bench.base / "missing.exe")
    for account in ("wiki-a", "wiki-b"):
        bench.apply("claude", account_id=account)
    folders = {bench.folder(account) for account in ("wiki-a", "wiki-b")}
    if was_enabled:
        _knowledge_hub.initialize(bench.home, [])
        path = settings_path(bench.home)
        path.write_text(json.dumps({**bench.settings(), "knowledgeEnabled": True}), encoding="utf-8")
    hub = bench.home / ".legion/knowledge"
    pointer = bench.home / ".config/llm-wiki/config.json"
    before = {path: path.read_bytes() for path in (*hub.rglob("*"), pointer) if path.is_file()}
    plugins, marketplaces = folders.copy(), folders.copy()
    removals: list[tuple[Path, list[str]]] = []
    remove_plugin = ["plugin", "uninstall", "wiki@llm-wiki"]
    remove_marketplace = ["plugin", "marketplace", "remove", "llm-wiki"]
    fail_removal = fail_once

    def fake_run(_program: str, args: list[str], *, env: dict[str, str], **_options: object) -> RunResult:
        nonlocal fail_removal
        folder = Path(env["CLAUDE_CONFIG_DIR"])
        output = ""
        if args == ["plugin", "list", "--json"]:
            output = json.dumps([{"id": "wiki@llm-wiki", "enabled": False}] if folder in plugins else [])
        elif args == ["plugin", "marketplace", "list", "--json"]:
            output = json.dumps([{"name": "llm-wiki"}] if folder in marketplaces else [])
        elif args == remove_plugin:
            plugins.remove(folder)
            removals.append((folder, args))
            output = "fixture removed wiki plugin"
        else:
            assert args == remove_marketplace
            assert folder not in plugins
            if fail_removal:
                fail_removal = False
                return RunResult(exit_code=1, output="", error="fixture marketplace failure", timed_out=False)
            marketplaces.remove(folder)
            removals.append((folder, args))
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", fake_run)
    args = ["--home", str(bench.home), "setup", "--no-knowledge"]
    result = CliRunner().invoke(cli.main, args)
    if fail_once:
        assert result.exit_code == 1
        assert "fixture marketplace failure" in result.output
        assert "fixture removed wiki plugin\nknowledge stays on; run legion setup --no-knowledge again\n" in result.output
        assert bench.settings()["knowledgeEnabled"] is True
        result = CliRunner().invoke(cli.main, args)
    assert result.exit_code == 0, result.output
    if missing_cli:
        assert "skip: knowledge: wiki-missing (codex command is missing)\nfixture removed wiki plugin" in result.output
    assert plugins == marketplaces == (set() if was_enabled else folders)
    for folder in folders:
        assert [args for target, args in removals if target == folder] == ([remove_plugin, remove_marketplace] if was_enabled else [])
    assert status(bench.base, bench.home).knowledge.state == "declined"
    saved = settings_path(bench.home).read_bytes()
    removals.clear()
    repeat = CliRunner().invoke(cli.main, args)
    assert repeat.exit_code == 0, repeat.output
    assert "skip: knowledge declined (already done)" in repeat.output
    assert not removals
    assert settings_path(bench.home).read_bytes() == saved
    assert {path: path.read_bytes() for path in (*hub.rglob("*"), pointer) if path.is_file()} == before


@pytest.mark.parametrize("external", [False, True])
def test_knowledge_preserves_settings_and_purge_asks(bench: Bench, monkeypatch: pytest.MonkeyPatch, external: bool) -> None:
    hub = bench.home / ".legion/knowledge"
    pointer = bench.home / ".config/llm-wiki/config.json"
    pointer.parent.mkdir(parents=True)
    existing: dict[str, str | bool] = {"other": True}
    if external:
        existing["hub_path"] = "~/other-wiki"
    pointer.write_text(json.dumps(existing), encoding="utf-8")
    result = CliRunner().invoke(cli.main, ["--home", str(bench.home), "setup", "--knowledge", "--yes"])
    assert result.exit_code == 0, result.output
    assert ("other-wiki" in result.output) is external
    expected = existing if external else {**existing, "hub_path": "~/.legion/knowledge"}
    assert json.loads(pointer.read_bytes()) == expected
    assert hub.is_dir()
    monkeypatch.setattr(_installer, "_listing", lambda *_: "")
    handed: list[list[Path]] = []
    monkeypatch.setattr(_installer._handover, "start", handed.append)
    answers = iter((False, True))

    def confirm(question: str, **_options: object) -> bool:
        assert question == "Also delete the knowledge hub in ~/.legion/knowledge? [y/N]"
        return next(answers)

    monkeypatch.setattr(_installer.click, "confirm", confirm)
    _installer.install(bench.home, uninstall=True, purge=True, yes=True)
    assert hub.is_dir()
    assert pointer.is_file()
    _installer.install(bench.home, uninstall=True, purge=True, yes=True)
    assert hub.is_dir()
    assert handed[-1] == [hub.parent]
    assert json.loads(pointer.read_bytes()) == existing


def test_knowledge_reports_a_missing_account_command(bench: Bench) -> None:
    bench.seed("wiki-account", "codex", command=bench.base / "missing.exe")
    result = CliRunner().invoke(cli.main, ["--home", str(bench.home), "setup", "--knowledge"])
    assert result.exit_code == 0, result.output
    assert "knowledge: wiki-account: codex command is missing" in result.output
    assert status(bench.base, bench.home).knowledge.missing_accounts == ["wiki-account"]


def test_invalid_pointer_is_reported_once_and_the_wikis_still_install(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    bench.apply("claude")
    bench.apply("codex")
    pointer = bench.home / ".config/llm-wiki/config.json"
    pointer.parent.mkdir(parents=True)
    pointer.write_bytes(b"invalid JSON")
    installed: list[str] = []
    monkeypatch.setattr(_installer, "_install_steps", lambda entry, *_: installed.append(entry.id))
    result = CliRunner().invoke(cli.main, ["--home", str(bench.home), "setup", "--knowledge"])
    assert result.exit_code == 0, result.output
    assert result.output.count("knowledge: hub setup failed:") == 1
    assert installed == ["claude", "codex"]
    assert pointer.read_bytes() == b"invalid JSON"


# --- the plan and a plain apply ---


def test_a_fresh_plan_has_the_contract_lines_and_changes_nothing(bench: Bench) -> None:
    before = bench.tree()
    plan = bench.preview()
    for expected in ("Plan (nothing changed yet):", "  create   settings and notes", "  commands write legion", "  path     ", "Run again with --yes to apply."):
        assert expected in text(plan)
    assert bench.tree() == before
    assert not (bench.home / ".legion").exists()


def test_apply_creates_settings_and_notes_and_a_repeat_only_skips(bench: Bench) -> None:
    bench.apply()
    assert bench.settings() == {"schemaVersion": 1, "agents": [], "channels": []}
    template = PLUGIN_ROOT / "skills" / "legion-personalisation" / "references" / "notes-template.md"
    assert (settings_path(bench.home).parent / "notes.md").read_text(encoding="utf-8") == template.read_text(encoding="utf-8")
    before = bench.tree()
    repeat = bench.apply()
    assert [line for line in repeat if not line.startswith("skip:")] == []
    assert bench.tree() == before
    assert bench.preview() == ["Nothing to do."]


# --- accounts ---


def test_accounts_plan_apply_and_repeat(bench: Bench) -> None:
    adopt = bench.base / "my codex"
    adopt.mkdir()
    (adopt / "owner.txt").write_text("keep login data", encoding="utf-8")
    before = bench.tree()
    plan = text(bench.preview("claude")) + "\n" + text(bench.preview("codex", adopt))
    assert "  add      claude2 (claude) new folder" in plan  # claude1 is an application on PATH
    assert f"  add      codex1 (codex) existing folder {adopt}" in plan
    assert "  install  legion into " in plan
    assert bench.tree() == before
    bench.hide("claude1")
    calls: list[tuple[str, str]] = []
    real = _accounts.add_subscription
    bench.monkeypatch.setattr(_accounts, "add_subscription", lambda home, account, tool, command, config_dir: (calls.append((account, tool)), real(home, account, tool, command, config_dir))[1])
    bench.apply("claude")
    apply = bench.apply("codex", adopt)
    assert calls == [("claude1", "claude"), ("codex1", "codex")]
    assert bench.ids() == ["claude1", "codex1"]
    assert [call[0] for call in bench.plugin_installs] == ["claude", "codex"]
    assert bench.plugin_installs[1][1] == adopt
    assert (adopt / "owner.txt").read_text(encoding="utf-8") == "keep login data"
    assert "account  tool  folder  legion  next step" in apply
    assert any(line.startswith("claude1  claude  ") and line.endswith(f"  log in: {login('CLAUDE_CONFIG_DIR', bench.home / '.legion' / 'agents' / 'claude1', 'claude')}") for line in apply)
    assert any(line.startswith("codex1  codex  ") and line.endswith(f"  {VERSION}  ready") for line in apply)
    assert "Log in once:" not in text(apply)
    assert "Existing account folder kept at" not in text(apply)
    app = bench.home / ".legion" / "app" / VERSION
    assert (app / ".legion-app-ready").is_file()
    before = bench.tree()
    installs = len(bench.plugin_installs)
    repeat = bench.apply()
    assert bench.tree() == before
    assert len(bench.plugin_installs) == installs
    assert bench.tool_installs == []
    assert "skip: legion in " in text(repeat)
    assert "account  tool  folder  legion  next step" in repeat
    assert [line for line in apply if line.startswith("claude1  ")] == [line for line in repeat if line.startswith("claude1  ")]
    assert bench.preview()[-1] == "Nothing to do."
    assert "  add      claude2 (claude) new folder" in text(bench.preview("claude"))


@pytest.mark.parametrize(
    ("tool", "folder", "account_id", "message"),
    [
        ("claude", None, "legion", "reserved for an owner command"),
        ("codex", "missing", None, "Existing account config folder does not exist."),
        ("nothing", None, None, "unknown tool 'nothing'"),
    ],
)
def test_bad_input_is_rejected_before_any_change(bench: Bench, tool: str, folder: Optional[str], account_id: Optional[str], message: str) -> None:
    before = bench.tree()
    with pytest.raises((_setup.SetupError, _accounts.AccountError), match=message):
        bench.apply(tool, bench.base / folder if folder else None, account_id)
    assert bench.tree() == before
    assert not (bench.home / ".legion").exists()
    assert bench.plugin_installs == []
    assert bench.tool_installs == []
    assert bench.user_path_file.read_text(encoding="utf-8") == "fixture-path"


def test_an_account_add_failure_stops_before_plugin_installs_and_path(bench: Bench) -> None:
    calls: list[str] = []

    def fail(_home: Path, account: str, *_rest: object) -> list[str]:
        calls.append(account)
        raise _accounts.AccountError("fixture add failure\r\nsecond line")

    bench.monkeypatch.setattr(_accounts, "add_subscription", fail)
    with pytest.raises(_setup.SetupError) as error:
        bench.apply("claude")
    assert str(error.value) == "fixture add failure second line"
    assert len(calls) == 1
    assert bench.settings()["agents"] == []
    assert bench.plugin_installs == []
    assert bench.user_path_file.read_text(encoding="utf-8") == "fixture-path"


def test_the_account_add_gets_the_id_the_tool_and_an_adopted_folder_only(bench: Bench) -> None:
    calls: list[tuple[Any, ...]] = []
    real = _accounts.add_subscription
    bench.monkeypatch.setattr(_accounts, "add_subscription", lambda *args: (calls.append(args), real(*args))[1])
    bench.apply("codex")
    assert calls == [(bench.home, "codex1", "codex", None, None)]
    folder = bench.base / "existing"
    folder.mkdir()
    calls.clear()
    bench.apply("claude", folder)
    assert [(call[1], call[2], call[3], call[4]) for call in calls] == [("claude2", "claude", None, str(folder))]


def test_setup_plans_under_the_settings_lock_and_does_the_outside_work_without_it(bench: Bench) -> None:
    held: dict[str, bool] = {}

    def locked() -> bool:
        try:
            with FileLock(str(settings_path(bench.home)) + ".lock", timeout=0):
                return False
        except Timeout:
            return True

    def watch(module: Any, name: str, label: str) -> None:
        real = getattr(module, name)
        bench.monkeypatch.setattr(module, name, lambda *args: (held.__setitem__(label, locked()), real(*args))[1])

    watch(_setup, "build_plan", "plan")
    for name in ("install_tools", "add_allow_rules", "install_plugins", "write_commands"):
        watch(_setup, name, name)
    watch(_accounts, "add_subscription", "add")
    bench.seed("seeded-a", "codex")
    held.clear()
    bench.apply("codex")
    assert held["plan"]
    assert {label: state for label, state in held.items() if label != "plan"} == {"install_tools": False, "add": False, "add_allow_rules": False, "install_plugins": False, "write_commands": False}


def test_missing_uv_is_a_plan_line_and_a_next_step_but_no_python_work(bench: Bench) -> None:
    bench.seed("ready-a", "codex")
    calls: list[str] = []
    bench.monkeypatch.setattr(_installed_runtime, "find_uv", lambda: None)
    bench.monkeypatch.setattr(_accounts, "add_subscription", lambda *args: calls.append(args[1]) or [])
    assert "  uv       missing; ask the owner before installing it" in bench.preview("codex")
    output = bench.apply("codex")
    assert "uv is missing. Ask the owner before installing it." in output
    assert any(line.startswith("codex1  codex") and line.endswith("uv is missing") for line in output)
    assert calls == []


# --- allow rules ---


def test_the_allow_rule_is_added_once_and_the_rest_of_the_file_stays(bench: Bench) -> None:
    adopted = bench.base / "adopted-claude"
    adopted.mkdir()
    (adopted / "settings.json").write_text(json.dumps({"model": "opus", "permissions": {"allow": ["Bash(git status)"], "deny": ["Bash(rm *)"]}}), encoding="utf-8")
    assert "permission" in text(bench.preview("claude", adopted))
    assert not settings_path(bench.home).exists()
    bench.hide("claude1")
    bench.apply("claude")
    bench.apply("claude", adopted)
    bench.apply("codex")
    bench.apply("copilot")
    created = next(Path(agent["configDir"]) for agent in bench.settings()["agents"] if agent["tool"] == "claude" and not agent["configDir"].endswith("adopted-claude"))
    assert json.loads((created / "settings.json").read_text(encoding="utf-8"))["permissions"]["allow"] == [RULE]
    kept = json.loads((adopted / "settings.json").read_text(encoding="utf-8"))
    assert kept["permissions"]["allow"] == ["Bash(git status)", RULE]
    assert kept["model"] == "opus"
    assert kept["permissions"]["deny"] == ["Bash(rm *)"]
    for other in ("codex1", "copilot1"):
        assert not (bench.folder(other) / "settings.json").exists()
    before = bench.tree()
    assert "skip: permission" in text(bench.apply())
    assert bench.tree() == before


def test_an_allow_rule_the_owner_already_had_is_a_skip_and_is_not_recorded(bench: Bench) -> None:
    folder = bench.base / "owner-claude"
    folder.mkdir()
    (folder / "settings.json").write_text(json.dumps({"permissions": {"allow": [RULE]}}), encoding="utf-8")
    bench.apply("claude", folder)
    assert [entry for entry in _footprints.read(bench.home).entries if entry.kind == "edit"] == []
    assert f"skip: permission rule in {folder} (already done)" in bench.apply()


def test_an_unreadable_settings_file_of_the_account_stops_the_plan(bench: Bench) -> None:
    folder = bench.base / "broken"
    folder.mkdir()
    (folder / "settings.json").write_text("{not json", encoding="utf-8")
    with pytest.raises(_setup.SetupError, match="cannot read"):
        bench.preview("claude", folder)


# --- repair, adoption and ids ---


# A custom program that is gone can only be named again by the owner; a missing stock CLI is installed instead.
def test_a_missing_target_needs_the_owner_and_is_never_repaired(bench: Bench) -> None:
    target = bench.base / "custom command.ps1"
    target.write_text("# inert target", encoding="utf-8")
    bench.seed("recover-a", "codex", command=target)
    target.unlink()
    before = bench.tree()
    assert "  account  target needed: recover-a" in text(bench.preview())
    assert bench.tree() == before
    assert "target needed: recover-a" in text(bench.apply())
    assert bench.tree() == before
    assert bench.plugin_installs == []


def test_a_custom_command_account_stays_usable_when_the_stock_cli_cannot_install(bench: Bench) -> None:
    for add_stock in (False, True):
        custom = bench.base / f"custom command {add_stock}.ps1"
        custom.write_text("# inert custom command", encoding="utf-8")
        account = f"custom-{int(add_stock)}"
        bench.seed(account, "codex", command=custom)
        bench.hide("codex")
        bench.tool_failure = "fixture failure"
        bench.tool_installs.clear()
        output = text(bench.apply("codex" if add_stock else None))
        assert f"target needed: {account}" not in output
        assert not any(bin_folder(bench.home).glob(f"{account}*"))
        assert len(bench.tool_installs) == int(add_stock)
        fake_cli(bench.tools, "codex", "CODEX_HOME")


def test_a_stored_custom_command_is_kept_and_needs_no_stock_cli(bench: Bench) -> None:
    folder = bench.base / "custom account"
    folder.mkdir()
    custom = bench.base / "custom'100% command.ps1"
    custom.write_text("# inert custom command", encoding="utf-8")
    bench.seed("custom-a", "codex", command=custom, folder=folder)
    bench.hide("codex")
    explicit = _setup.build_plan(bench.home, "codex", str(folder), "custom-a")
    assert explicit.accounts[0].command == str(custom)
    assert explicit.missing_tools == []
    settings = settings_path(bench.home).read_bytes()
    bench.apply("codex", folder, "custom-a")
    assert settings_path(bench.home).read_bytes() == settings
    plan = text(bench.preview())
    assert "cli      install" not in plan
    assert "custom-a" not in plan


def test_an_account_without_a_command_uses_the_stock_cli(bench: Bench) -> None:
    folder = bench.base / "stock account"
    folder.mkdir()
    bench.seed("stock-a", "codex", folder=folder)
    assert "stock-a" not in text(bench.preview())
    bench.hide("codex")
    plan = text(bench.preview())
    assert "install codex" in plan
    assert "target needed" not in plan


@posix_only
def test_the_legion_command_that_lost_its_execute_permission_is_restored(bench: Bench) -> None:
    bench.apply("codex")
    command = bin_folder(bench.home) / "legion"
    command.chmod(stat.S_IRUSR | stat.S_IWUSR)
    assert "  commands restore execute permission for legion" in text(bench.preview())
    bench.apply()
    assert os.access(command, os.X_OK)


def test_adopting_a_folder_twice_reuses_the_account(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    folder = bench.base / "existing"
    folder.mkdir()
    assert run(["--home", str(bench.home), "add", "codex", str(folder), "--yes"]) == 0
    capsys.readouterr()
    before = bench.tree()
    spellings = [str(folder) + os.sep]
    if WINDOWS:
        spellings.append(str(folder).upper())
    for spelling in spellings:
        assert run(["--home", str(bench.home), "add", "codex", spelling, "--yes"]) == 0
        assert "skip: account codex1 (already done)" in capsys.readouterr().out
    assert bench.ids() == ["codex1"]
    assert bench.tree() == before


def test_an_id_is_never_a_command_on_the_path_or_a_recorded_account(bench: Bench) -> None:
    bench.apply("claude")
    assert bench.ids() == ["claude2"]
    bench.apply("claude")
    assert bench.ids() == ["claude2", "claude3"]


# --- tools ---


@pytest.mark.parametrize("scenario", ["success", "failure", "terminal"])
def test_a_missing_cli_installs_once_for_several_accounts(bench: Bench, scenario: str) -> None:
    for account, tool in (("codex1", "codex"), ("codex2", "codex"), ("claude2", "claude")):
        _accounts.add_subscription(bench.home, account, tool, None, None)
    bench.hide("codex")
    bench.tool_failure = "fixture failure\nsecond line" if scenario == "failure" else ""
    bench.needs_terminal = scenario == "terminal"
    plan = text(bench.preview("codex"))
    assert "  cli      install codex (" in plan
    assert bench.tool_installs == []
    output = bench.apply("codex")
    assert bench.tool_installs == ["codex"]
    if scenario == "success":
        assert bench.ids() == ["codex1", "codex2", "claude2", "codex3"]
        assert len(bench.plugin_installs) == 4
        return
    assert bench.ids() == ["codex1", "codex2", "claude2"]
    assert [call[0] for call in bench.plugin_installs] == ["claude"]
    expected = "codex install failed: fixture failure second line" if scenario == "failure" else "codex installed: open a new terminal, then repeat the add"
    assert expected in text(output)
    assert not bench.folder("codex3").exists()


def test_a_plugin_install_failure_is_a_table_row_and_the_next_folder_still_installs(bench: Bench) -> None:
    bench.hide("claude1")
    bench.failing_folder = bench.folder("claude1")
    _accounts.add_subscription(bench.home, "claude1", "claude", None, None)
    output = bench.apply("codex")
    assert "install failed: log in with claude1, then finish setup" in text(output)
    assert len(bench.plugin_installs) == 2


def test_copilot_setup_reports_login_when_plugin_installed_despite_installer_error(bench: Bench) -> None:
    install = bench.install_plugin

    def installed_with_error(tool_id: str, folder: Path, home: Path, source: Optional[str]) -> int:
        install(tool_id, folder, home, source)
        return 1

    bench.monkeypatch.setattr(_setup, "install_plugin", installed_with_error)
    output = bench.apply("copilot")
    assert any(line.startswith("copilot1  copilot  ") and line.endswith(f"  {VERSION}  log in: {login('COPILOT_HOME', bench.home / '.legion' / 'agents' / 'copilot1', 'copilot')}") for line in output)


def test_a_plugin_installer_that_raises_is_a_failure_row_for_each_target(bench: Bench) -> None:
    bench.hide("claude1")
    attempts: list[str] = []

    def broken(tool_id: str, *_rest: object) -> int:
        attempts.append(tool_id)
        raise OSError("fixture missing installer")

    bench.monkeypatch.setattr(_setup, "install_plugin", broken)
    _accounts.add_subscription(bench.home, "claude1", "claude", None, None)
    output = bench.apply("codex")
    assert attempts == ["claude", "codex"]
    assert "install failed: log in with claude1, then finish setup" in text(output)
    assert "install failed: log in with codex1, then finish setup" in text(output)


def test_the_plugin_is_installed_only_where_it_is_missing_whatever_version_is_there(bench: Bench) -> None:
    for delivered in ("0.5.0", "9.0.0"):
        folder = bench.base / f"folder-{delivered}"
        folder.mkdir()
        manifest = folder / (descriptor("codex").plugin.installed_root or "") / delivered / "plugin.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text(json.dumps({"name": "legion", "version": delivered}), encoding="utf-8")
        bench.apply("codex", folder, f"codex-{delivered.replace('.', '-')}")
        assert bench.plugin_installs == []
        assert "skip: legion in" in text(bench.apply())
        assert f"install  legion into {folder}" not in text(bench.preview())


def test_installs_are_keyed_by_folder_with_the_system_comparer(bench: Bench) -> None:
    codex = descriptor("codex")
    rows = [_setup.Row(id="codex-a", tool=codex, folder=bench.base / name, usable=True) for name in ("account", "ACCOUNT", "account")]
    plan = _setup.Plan(home=bench.home, settings_file=settings_path(bench.home), accounts=rows, uv_missing=False, missing_tools=[], bin=bin_folder(bench.home), commands=[], needs_path=False)
    _setup.install_plugins(plan, None, lambda _line: None)
    assert len(bench.plugin_installs) == (1 if WINDOWS else 2)


def test_plan_hints_show_the_prerequisites_and_commands(bench: Bench) -> None:
    bench.hide("copilot")
    assert "  cli      install copilot (" in text(bench.preview("copilot"))


def test_a_cli_found_only_on_the_saved_path_counts_as_installed(bench: Bench) -> None:
    saved = bench.base / "saved"
    fake_cli(saved, "copilot", "COPILOT_HOME")
    bench.hide("copilot")
    bench.monkeypatch.setattr(_user_path, "persistent_folders", lambda: [str(saved)])
    plan = _setup.build_plan(bench.home, "copilot", None, None)
    assert (plan.missing_tools == []) == WINDOWS


# --- commands, PATH and the table ---


def test_the_owner_command_is_published_and_rewritten_when_it_is_ours_and_old(bench: Bench) -> None:
    command = bin_folder(bench.home)
    command.mkdir(parents=True)
    stale = _installed_runtime.shim_text(Path("/gone/app/0.0.1"), bench.home, windows=False).replace(' "$@"', ' --keep "$@"')
    (command / "legion").write_text(stale, encoding="utf-8")
    bench.apply()
    rewritten = (command / "legion").read_text(encoding="utf-8")
    assert str(bench.home / ".legion" / "app" / VERSION) in rewritten or f"app/{VERSION}" in rewritten.replace("\\", "/")
    assert "--keep" not in rewritten
    assert "skip: command legion (already done)" in bench.apply()


def test_a_command_that_is_not_ours_is_listed_once_and_left_alone(bench: Bench) -> None:
    command = bin_folder(bench.home)
    command.mkdir(parents=True)
    (command / "legion").write_text("owner command", encoding="utf-8")
    plan = bench.preview()
    assert "blocked: command legion (another file is there)" in plan
    output = bench.apply()
    assert (command / "legion").read_text(encoding="utf-8") == "owner command"
    assert "Blocked commands: legion" in output
    assert len([line for line in output if "another file" in line or line.startswith("Blocked commands:")]) == 1
    bench.hide("none")
    bench.monkeypatch.setenv("PATH", os.environ["PATH"] + os.pathsep + str(command))
    assert bench.preview()[-1] == "Nothing to do."


@windows_only
def test_windows_appends_the_folder_to_the_saved_user_path_once(bench: Bench) -> None:
    bench.apply()
    assert bench.user_path_file.read_text(encoding="utf-8") == f"fixture-path;{bin_folder(bench.home)}"
    bench.apply()
    assert bench.user_path_file.read_text(encoding="utf-8").count(str(bin_folder(bench.home))) == 1
    assert [entry.path for entry in _footprints.read(bench.home).entries if entry.kind == "path-entry"] == ["user PATH"]


@posix_only
def test_other_systems_write_the_shell_profile_not_the_registry(bench: Bench) -> None:
    plan = text(bench.preview())
    assert str(bench.home / ".bashrc") in plan
    assert not (bench.home / ".bashrc").exists()
    bench.apply()
    assert _user_path.shell_profile(bench.home).has_path
    assert bench.user_path_file.read_text(encoding="utf-8") == "fixture-path"
    again = bench.apply()
    assert "skip: shell profile PATH (already done)" in again
    assert not _setup.build_plan(bench.home, None, None, None).needs_path


@windows_only
def test_setup_status_and_installer_agree_about_expanded_path_entries(bench: Bench) -> None:
    folder = bin_folder(bench.home)
    folder.mkdir(parents=True)
    bench.monkeypatch.setenv("LEGION_STATUS_BIN", str(folder.parent))
    bench.monkeypatch.delenv("OS", raising=False)
    entry = rf"%LEGION_STATUS_BIN%\other\..\{folder.name}"
    bench.user_path_file.write_text(entry, encoding="utf-8")
    bench.monkeypatch.setenv("PATH", entry)
    assert not _setup.build_plan(bench.home, None, None, None).needs_path
    assert _status.on_path(folder)
    lines: list[str] = []
    _installer.ensure_path(bench.home, False, lines)
    assert lines == ["skip: path (already done)"]
    assert os.environ["PATH"] == entry
    assert bench.user_path_file.read_text(encoding="utf-8") == entry


@windows_only
def test_a_cli_installed_onto_a_new_saved_path_folder_is_found_and_this_path_is_restored(bench: Bench) -> None:
    saved = bench.base / "saved"
    folders: list[str] = []
    bench.monkeypatch.setattr(_user_path, "persistent_folders", lambda: list(folders))
    bench.hide("codex")

    def install(_home: Path, tool_id: str) -> Optional[str]:
        fake_cli(saved, tool_id, "CODEX_HOME")
        folders.append(str(saved))
        return None

    bench.monkeypatch.setattr(_setup, "install_tool", install)
    before = os.environ["PATH"]
    bench.apply("codex")
    assert bench.ids() == ["codex1"]
    assert os.environ["PATH"] == before


@windows_only
def test_the_preview_shows_the_command_the_apply_runs_when_npm_is_only_on_the_saved_path(bench: Bench) -> None:
    saved = bench.base / "saved"
    fake_cli(saved, "node")
    bench.hide("copilot")
    bench.monkeypatch.setattr(_user_path, "persistent_folders", lambda: [str(saved)])
    bench.monkeypatch.setattr(_setup, "install_tool", REAL_INSTALL_TOOL)
    ran: list[list[str]] = []
    bench.monkeypatch.setattr(_tool_install.ToolInstaller, "execute", lambda _self, command: ran.append(command) or 0)
    shown = text(bench.preview("copilot"))
    bench.apply("copilot")
    assert ran == [["npm", "install", "-g", "@github/copilot"]]
    assert " ".join(ran[0]) in shown


# --- the plugin installer process ---


def installer_calls(bench: Bench, lines: list[str] | Exception) -> list[tuple[Path, dict[str, Any]]]:
    calls: list[tuple[Path, dict[str, Any]]] = []

    def fake_install(home: Path, **options: Any) -> list[str]:
        calls.append((home, options))
        if isinstance(lines, Exception):
            raise lines
        return lines

    bench.monkeypatch.setattr(_installer, "install", fake_install)
    return calls


def test_the_plugin_installer_gets_its_options_and_a_log(bench: Bench) -> None:
    calls = installer_calls(bench, ["inert installer output", "second line"])
    folder = bench.base / "target folder"
    assert REAL_INSTALL_PLUGIN("codex", folder, bench.home, None) == 0
    assert calls == [(bench.home, {"tools": ["codex"], "config_dir": folder, "update": True, "yes": True, "source": _setup._installer.DEFAULT_SOURCE, "with_knowledge": False})]
    assert (bench.home / ".legion" / "temp" / "setup-install-codex.log").read_text(encoding="utf-8") == "inert installer output\nsecond line"


@pytest.mark.parametrize("source", ["owner/repo", "work folder/my-project"])
def test_a_source_reaches_the_plugin_installer_unchanged(bench: Bench, source: str) -> None:
    calls = installer_calls(bench, [])
    REAL_INSTALL_PLUGIN("claude", bench.base, bench.home, source)
    assert calls[0][1]["source"] == source


def test_a_failed_plugin_install_returns_one_and_logs_why(bench: Bench) -> None:
    installer_calls(bench, _installer.InstallerError("claude exited 3\nboom"))
    assert REAL_INSTALL_PLUGIN("claude", bench.base, bench.home, None) == 1
    assert "boom" in (bench.home / ".legion" / "temp" / "setup-install-claude.log").read_text(encoding="utf-8")


def test_the_plugin_install_never_looks_for_pwsh(bench: Bench) -> None:
    installer_calls(bench, [])
    bench.monkeypatch.setenv("PATH", str(bench.base / "empty"))
    assert REAL_INSTALL_PLUGIN("claude", bench.base, bench.home, None) == 0


def test_a_cli_install_reports_its_failures_as_one_line(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    class Failing(_tool_install.ToolInstaller):
        def install(self, tool: str, method: Optional[str] = None) -> int:
            raise _tool_install.ToolInstallError("first line\nsecond line")

    monkeypatch.setattr(_tool_install, "ToolInstaller", Failing)
    real = REAL_INSTALL_TOOL
    assert real(bench.home, "codex") == "first line second line"

    class Choose(_tool_install.ToolInstaller):
        def install(self, tool: str, method: Optional[str] = None) -> int:
            self.say("winget failed (exit 1).")
            return 2

    monkeypatch.setattr(_tool_install, "ToolInstaller", Choose)
    assert "winget failed (exit 1)." in str(real(bench.home, "codex"))

    class Fine(_tool_install.ToolInstaller):
        def install(self, tool: str, method: Optional[str] = None) -> int:
            return 0

    monkeypatch.setattr(_tool_install, "ToolInstaller", Fine)
    assert real(bench.home, "codex") is None


# --- the owner's flow: plan, Apply?, --yes ---


class Talk:
    def __init__(self, monkeypatch: pytest.MonkeyPatch, interactive: bool, answers: list[str]) -> None:
        self.asked: list[str] = []
        monkeypatch.setattr(_setup, "interactive", lambda: interactive)
        monkeypatch.setattr(_setup, "ask", lambda: self.asked.append("Apply? [Y/n]") or answers.pop(0))


@pytest.mark.parametrize("answer", ["", "y", "yes", " Y "])
def test_an_interactive_owner_who_says_yes_applies_and_never_sees_the_run_again_hint(bench: Bench, monkeypatch: pytest.MonkeyPatch, answer: str) -> None:
    talk = Talk(monkeypatch, True, [answer])
    lines: list[str] = []
    _setup.run(bench.home, "codex", None, None, None, False, lines.append)
    assert talk.asked == ["Apply? [Y/n]"]
    assert "Plan (nothing changed yet):" in lines
    assert "Run again with --yes to apply." not in text(lines)
    assert bench.ids() == ["codex1"]


def test_an_owner_who_says_no_changes_nothing(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    Talk(monkeypatch, True, ["n"])
    lines: list[str] = []
    _setup.run(bench.home, "codex", None, None, None, False, lines.append)
    assert lines[-1] == "Setup plan declined."
    assert not (bench.home / ".legion").exists()


def test_declining_setup_does_not_reconcile_a_saved_knowledge_opt_in(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    _setup.run(bench.home, None, None, None, None, True, lambda _: None, knowledge=True)
    log = bench.home / ".legion/knowledge/log.md"
    log.unlink()
    Talk(monkeypatch, True, ["n"])
    _setup.run(bench.home, "codex", None, None, None, False, lambda _: None)
    assert not log.exists()
    assert bench.ids() == []


def test_a_script_gets_the_plan_and_the_run_again_hint_and_no_prompt(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    talk = Talk(monkeypatch, False, [])
    lines: list[str] = []
    _setup.run(bench.home, "codex", None, None, None, False, lines.append)
    assert talk.asked == []
    assert lines[-1] == "Run again with --yes to apply."
    assert not (bench.home / ".legion").exists()


def test_nothing_to_do_asks_nothing_after_knowledge_is_declined(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    _setup.run(bench.home, None, None, None, None, True, lambda _: None, knowledge=False)
    talk = Talk(monkeypatch, True, [])
    lines: list[str] = []
    _setup.run(bench.home, None, None, None, None, False, lines.append)
    assert lines == ["Nothing to do."]
    assert talk.asked == []


def test_yes_applies_without_asking(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    talk = Talk(monkeypatch, True, [])
    _setup.run(bench.home, "codex", None, None, None, True, lambda _line: None)
    assert talk.asked == []
    assert bench.ids() == ["codex1"]


# --- the verbs ---


def test_setup_through_the_verb_prints_the_plan_for_a_script_and_applies_with_yes(bench: Bench, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_setup, "interactive", lambda: False)
    assert run(["--home", str(bench.home), "setup"]) == 0
    assert "Run again with --yes to apply." in capsys.readouterr().out
    assert not settings_path(bench.home).exists()
    assert run(["--home", str(bench.home), "setup", "--yes"]) == 0
    assert "skip:" not in capsys.readouterr().out
    assert settings_path(bench.home).is_file()


@pytest.mark.parametrize("inline", [False, True])
def test_add_preserves_an_adoption_folder_with_a_space_and_platform_colons(bench: Bench, capsys: pytest.CaptureFixture[str], inline: bool) -> None:
    folder = bench.base / ("my codex" if WINDOWS else "my codex:folder")
    folder.mkdir()
    target = [f"codex:{folder}"] if inline else ["codex", str(folder)]
    assert run(["--home", str(bench.home), "add", *target, "--yes"]) == 0
    assert bench.settings()["agents"][0]["configDir"] == str(folder)
    assert "account  tool  folder  legion  next step" in capsys.readouterr().out


def test_add_takes_a_hidden_id_and_source_for_the_skills(bench: Bench) -> None:
    assert run(["--home", str(bench.home), "add", "codex", "--id", "codex-x", "--source", "owner/repo", "--yes"]) == 0
    assert bench.ids() == ["codex-x"]
    assert bench.plugin_installs[0][2] == "owner/repo"


@pytest.mark.parametrize("arguments", [["add"], ["add", "a", "b", "c"], ["setup", "extra"]])
def test_the_verbs_refuse_the_wrong_number_of_arguments(bench: Bench, arguments: list[str]) -> None:
    assert run(["--home", str(bench.home), *arguments]) == 2


def test_an_error_is_one_line_on_stderr_with_exit_one(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--home", str(bench.home), "add", "nothing", "--yes"]) == 1
    captured = capsys.readouterr()
    assert captured.err.strip() == "unknown tool 'nothing'"
    assert captured.out == ""
    assert run(["--home", str(bench.home), "add", "codex", str(bench.base / "missing"), "--yes"]) == 1
    assert "does not exist" in capsys.readouterr().err
    assert not (bench.home / ".legion").exists()


def test_a_plan_that_fails_stops_before_any_prompt(bench: Bench, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    talk = Talk(monkeypatch, True, [])
    assert run(["--home", str(bench.home), "add", "nothing"]) == 1
    assert talk.asked == []
    assert capsys.readouterr().err.strip() == "unknown tool 'nothing'"


# --- review fixes ---


def link_to(link: Path, real: Path) -> Path:
    real.mkdir()
    try:
        link.symlink_to(real, target_is_directory=True)
    except OSError:
        # Windows: a junction needs no privilege and resolves the same way.
        if not WINDOWS or subprocess.run([os.environ["COMSPEC"], "/c", "mklink", "/J", str(link), str(real)], capture_output=True, check=False).returncode != 0:
            pytest.skip("links need a privilege here")
    return link


def test_the_same_folder_through_a_link_and_its_real_path_is_one_account_and_one_install(bench: Bench) -> None:
    real = bench.base / "real"
    link = link_to(bench.base / "link", real)
    for folder in (link, real):
        assert run(["--home", str(bench.home), "add", "codex", str(folder), "--yes"]) == 0
    assert bench.ids() == ["codex1"]
    assert bench.plugin_installs == [("codex", link, None)]

    other = bench.base / "second"
    other_link = link_to(bench.base / "second-link", other)
    _accounts.add_subscription(bench.home, "codex2", "codex", None, str(other_link))
    _accounts.add_subscription(bench.home, "codex3", "codex", None, str(other))
    assert run(["--home", str(bench.home), "setup", "--yes"]) == 0
    assert bench.plugin_installs == [("codex", link, None), ("codex", other_link, None)]


def test_an_interrupted_write_leaves_the_settings_file_and_never_makes_a_partial_one(bench: Bench) -> None:
    def fail(_self: Path, _target: Path) -> Path:
        raise OSError("interrupted")

    bench.monkeypatch.setattr(Path, "replace", fail)
    plan = _setup.build_plan(bench.home, None, None, None)
    with pytest.raises(OSError, match="interrupted"):
        _setup.initialize_files(plan, lambda _line: None)
    assert not settings_path(bench.home).exists()
    assert not plan.notes.exists()


def test_an_interrupted_allow_rule_write_keeps_the_account_settings_whole(bench: Bench) -> None:
    folder = bench.base / "claude-folder"
    folder.mkdir()
    original = '{"theme": "dark"}'
    (folder / "settings.json").write_text(original, encoding="utf-8")
    plan = _setup.build_plan(bench.home, "claude", str(folder), None)

    real_replace = Path.replace

    def fail(self: Path, target: Path) -> Path:
        if target.name == "settings.json":
            raise OSError("interrupted")
        return real_replace(self, target)

    bench.monkeypatch.setattr(Path, "replace", fail)
    with pytest.raises(OSError, match="interrupted"):
        _setup.add_allow_rules(plan, lambda _line: None)
    assert (folder / "settings.json").read_text(encoding="utf-8") == original


def test_a_scalar_allow_rule_stays_a_rule(bench: Bench) -> None:
    folder = bench.base / "claude-folder"
    folder.mkdir()
    (folder / "settings.json").write_text(json.dumps({"permissions": {"allow": "Bash(mine)"}}), encoding="utf-8")
    bench.apply("claude", folder)
    data = json.loads((folder / "settings.json").read_text(encoding="utf-8"))
    assert data["permissions"]["allow"] == ["Bash(mine)", RULE]


@pytest.mark.parametrize("content", [{"permissions": 5}, {"permissions": {"allow": 5}}, {"permissions": {"allow": {"a": 1}}}])
def test_an_allow_shape_that_cannot_be_kept_stops_the_plan_before_any_record(bench: Bench, content: dict[str, Any]) -> None:
    folder = bench.base / "claude-folder"
    folder.mkdir()
    (folder / "settings.json").write_text(json.dumps(content), encoding="utf-8")
    with pytest.raises(_setup.SetupError, match="cannot read"):
        bench.apply("claude", folder)
    assert not footprint_index(bench.home).exists()


def test_an_explicitly_empty_adoption_folder_is_refused_before_anything_is_written(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--home", str(bench.home), "add", "codex", "", "--yes"]) == 1
    assert _setup.NO_FOLDER in capsys.readouterr().err
    assert not settings_path(bench.home).exists()
