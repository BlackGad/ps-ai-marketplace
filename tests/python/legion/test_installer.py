import io
import json
import os
import shutil
from collections.abc import Callable
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Optional

import httpx
import pytest
from click.testing import CliRunner

from legion.services.installation import _uv_tool, installer as _installer
from legion.services.lifecycle import _plugins
from legion import cli as _cli
from legion.services.repository import _footprints
from legion.core import _http, _stop_event
from legion.core._home import run_folder
from legion.core._http import https_client
from legion.core._run import RunResult
from legion.core._settings_models import ToolsCatalog
from app_fakes import FakeUv, make_link, make_source


CATALOG_PATH = Path(__file__).resolve().parents[3] / "plugins/legion/tools.json"


def catalog() -> ToolsCatalog:
    return ToolsCatalog.model_validate_json(CATALOG_PATH.read_bytes())


def cli_listing(tool: str, arguments: list[str], folder: Path) -> str | None:
    entry = _installer.catalog_tool(catalog(), tool)
    if arguments == entry.plugin.list_command:
        plugin = "legion@ps-legion-marketplace"
        return json.dumps([{"id": plugin, "enabled": True}]) if tool == "claude" else plugin
    if arguments == entry.plugin.marketplace_list:
        rows = [{"name": "ps-legion-marketplace", "root": str(folder)}]
        return json.dumps({"marketplaces": rows} if tool == "codex" else rows)
    return None


def seed_copy(tool: str, folder: Path, version: str) -> Path:
    root = folder / (_installer.catalog_tool(catalog(), tool).plugin.installed_root or "")
    root.mkdir(parents=True, exist_ok=True)
    (root / "plugin.json").write_text(json.dumps({"name": "legion", "version": version}), encoding="utf-8")
    return root


def installed_clis(monkeypatch: pytest.MonkeyPatch, mutate: Callable[[str, list[str], Path], object] | None = None) -> None:
    def run_command(program: str, arguments: list[str], *, env: dict[str, str], **_options: object) -> RunResult:
        folder = Path(env[_installer.catalog_tool(catalog(), program).config_env])
        listing = cli_listing(program, arguments, folder)
        if listing is None and mutate is not None:
            mutate(program, arguments, folder)
        return RunResult(exit_code=0, output=listing or "", error="", timed_out=False)

    monkeypatch.setattr(_plugins, "run_command", run_command)


def test_catalog_parses_tools_json_as_model() -> None:
    tools = _installer.load_catalog(Path(__file__).resolve().parents[3], "release", None)
    assert tools.schema_version == 1
    codex = _installer.catalog_tool(tools, "codex")
    assert codex.plugin.list_command == ["plugin", "list"]
    assert codex.install_hint == "npm install -g @openai/codex"


def test_catalog_rejects_unknown_shape(tmp_path: Path) -> None:
    data = json.loads(CATALOG_PATH.read_bytes())
    data["tools"][0]["unexpected"] = True
    path = tmp_path / "plugins/legion/tools.json"
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(_installer.InstallerError, match="unexpected"):
        _installer.load_catalog(tmp_path, "release", None)


def write_installer_accounts(home: Path, *accounts: tuple[str, Path, Optional[Path]]) -> Path:
    path = home / ".legion/configuration/personalisation.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    agents = []
    for name, folder, command in accounts:
        agent = {"id": name, "tool": "claude", "configDir": str(folder)}
        if command is not None:
            agent["command"] = str(command)
        agents.append(agent)
    path.write_text(json.dumps({"schemaVersion": 1, "agents": agents, "channels": []}), encoding="utf-8")
    return path


@pytest.mark.parametrize("suffix", [".ps1", ".cmd"])
def test_installer_runs_registered_script(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, suffix: str) -> None:
    folder = tmp_path / "account"
    folder.mkdir()
    script = tmp_path / f"claude account{suffix}"
    script.touch()
    write_installer_accounts(tmp_path, ("claude-a", folder, script))
    monkeypatch.setattr(shutil, "which", lambda _name: None)
    calls: list[tuple[str, list[str]]] = []

    def run(program: str, arguments: list[str], **_options: object) -> RunResult:
        calls.append((program, arguments))
        return RunResult(exit_code=0, output="[]", error="", timed_out=False)

    monkeypatch.setattr(_plugins, "run_command", run)
    _installer.install(tmp_path, ["claude"], config_dir=folder, dry_run=True, catalog=catalog())
    program, prefix = ("pwsh", ["-NoProfile", "-File", str(script)]) if suffix == ".ps1" else (str(script), [])
    assert calls == [
        (program, [*prefix, "plugin", "marketplace", "list", "--json"]),
        (program, [*prefix, "plugin", "list", "--json"]),
    ]


@pytest.mark.parametrize("stock", [None, "claude"])
@pytest.mark.parametrize("mode", ["install", "update", "uninstall"])
def test_installer_scopes_registered_command_to_its_folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, stock: Optional[str], mode: str) -> None:
    a, b = tmp_path / "account-a", tmp_path / "account-b"
    a.mkdir()
    b.mkdir()
    registered, missing = tmp_path / "registered-claude", tmp_path / "missing-claude"
    registered.touch()
    write_installer_accounts(tmp_path, ("claude-a", a, registered), ("claude-b", b, missing))
    monkeypatch.setattr(shutil, "which", lambda name: stock if name == "claude" else None)
    calls: set[tuple[str, str]] = set()

    def run(program: str, _arguments: list[str], *, env: dict[str, str], **_options: object) -> RunResult:
        calls.add((program, env["CLAUDE_CONFIG_DIR"]))
        return RunResult(exit_code=0, output="[]", error="", timed_out=False)

    monkeypatch.setattr(_plugins, "run_command", run)
    lines = _installer.install(tmp_path, ["claude"], dry_run=True, catalog=catalog(), update=mode == "update", uninstall=mode == "uninstall")
    expected = {(str(registered), str(a))}
    skip_b = f"skip: claude in {b} (no command for this folder)"
    assert skip_b in lines
    assert calls == expected


def test_missing_registered_command_gives_install_hint(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_installer_accounts(tmp_path, ("claude-a", tmp_path / "a", tmp_path / "missing"))
    monkeypatch.setattr(shutil, "which", lambda _name: None)
    lines = _installer.install(tmp_path, ["claude"], dry_run=True, catalog=catalog())
    assert "skip: claude (not installed)" in lines
    assert "irm https://claude.ai/install.ps1 | iex" in lines


def test_install_names_invalid_settings_file(tmp_path: Path) -> None:
    path = write_installer_accounts(tmp_path)
    path.write_text("{}", encoding="utf-8")
    with pytest.raises(_installer.InstallerError) as error:
        _installer.install(tmp_path, ["claude"], dry_run=True, catalog=catalog())
    assert str(path) in str(error.value)


def test_uninstall_with_invalid_settings_uses_stock_and_defaults(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    path = write_installer_accounts(tmp_path)
    path.write_text("{}", encoding="utf-8")
    folder = tmp_path / ".claude"
    folder.mkdir()
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(folder))
    monkeypatch.setattr(shutil, "which", lambda name: "claude" if name == "claude" else None)
    calls: set[tuple[str, str]] = set()

    def run(program: str, _arguments: list[str], *, env: dict[str, str], **_options: object) -> RunResult:
        calls.add((program, env["CLAUDE_CONFIG_DIR"]))
        return RunResult(exit_code=0, output="[]", error="", timed_out=False)

    monkeypatch.setattr(_plugins, "run_command", run)
    lines = _installer.install(tmp_path, ["claude"], uninstall=True, dry_run=True, catalog=catalog())
    assert sum(line.startswith("skip: account folders (settings invalid: ") for line in lines) == 1
    assert calls == {("claude", str(folder))}


@pytest.mark.parametrize(
    ("operation", "stock"),
    [
        ("install", None),
        ("explicit install", None),
        ("update", None),
        ("uninstall", None),
        ("update", "claude"),
        ("linked update", "claude"),
    ],
)
def test_adopted_account_command_off_path_is_installed(operation: str, stock: Optional[str], tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    folder = home / ".legion/agents/claude-a"
    folder.mkdir(parents=True)
    command = home / "adopted-claude"
    command.touch()
    settings = home / ".legion/configuration/personalisation.json"
    settings.parent.mkdir()
    settings.write_text(
        json.dumps({"schemaVersion": 1, "agents": [{"id": "claude-a", "tool": "claude", "configDir": "~/.legion/agents/claude-a", "command": "~/adopted-claude"}], "channels": []}),
        encoding="utf-8",
    )
    root = folder / "legion-plugin"
    root.mkdir()
    (root / "plugin.json").write_text('{"name":"legion","version":"1.0.0"}', encoding="utf-8")
    target = folder
    if operation == "linked update":
        target = home / "linked-account"
        make_link(target, folder)
    monkeypatch.setattr(shutil, "which", lambda name: stock if name == "claude" else None)
    calls: list[str] = []
    installed = [{"id": "legion@ps-legion-marketplace", "enabled": True, "installPath": str(root), "version": "1.0.0"}]

    def run(program: str, arguments: list[str], **options: Any) -> RunResult:
        if options["env"]["CLAUDE_CONFIG_DIR"] == str(target):
            calls.append(program)
        output = json.dumps(installed) if arguments == ["plugin", "list", "--json"] else "[]"
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_plugins, "run_command", run)
    tools = ["claude"] if operation in ("explicit install", "uninstall") else None
    _installer.install(home, tools=tools, config_dir=target, dry_run=True, catalog=catalog(), update=operation in ("update", "linked update"), uninstall=operation == "uninstall")
    assert set(calls) == {str(command)}


def test_no_coding_cli_installs_the_legion_command_through_uv_without_plugin(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    source = make_source(tmp_path)
    uv = FakeUv(monkeypatch, tmp_path / "uv bin")
    monkeypatch.setattr(_installer, "PLUGIN_ROOT", source)
    monkeypatch.setattr(shutil, "which", lambda name: "uv" if name == "uv" else None)

    first = _installer.install(home, yes=True, catalog=catalog())
    assert uv.installs() == [["tool", "install", f"{source}[mcp]", "--constraints", uv.installs()[0][4], "--reinstall"]]
    assert "legion command 1.0.0 installed" in first
    assert "No coding CLI is installed." in "\n".join(first)
    assert "legion setup" in "\n".join(first)
    assert not (home / ".legion/bin").exists()
    assert not (home / ".claude").exists()
    assert not (home / ".codex").exists()
    assert not (home / ".copilot").exists()
    second = _installer.install(home, yes=True, catalog=catalog())
    assert "skip: legion command 1.0.0 (already done)" in second
    assert len(uv.installs()) == 1


def test_a_dry_run_of_an_install_shows_the_uv_command_and_runs_no_install(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    source = make_source(tmp_path)
    uv = FakeUv(monkeypatch, tmp_path / "uv bin")
    monkeypatch.setattr(_installer, "PLUGIN_ROOT", source)
    monkeypatch.setattr(shutil, "which", lambda name: "uv" if name == "uv" else None)
    lines = _installer.install(tmp_path / "home", dry_run=True, catalog=catalog())
    assert any("tool install" in line and "--reinstall" in line for line in lines)
    assert uv.installs() == []
    assert uv.detached == []
    assert not (tmp_path / "home").exists()


def test_no_coding_cli_declined_command_install_changes_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(shutil, "which", lambda _name: None)
    monkeypatch.setattr(_installer, "_confirm", lambda _question, _lines: False)
    lines = _installer.install(tmp_path / "home", catalog=catalog())
    assert "Nothing changed. Run again with --yes to apply." in lines
    assert not (tmp_path / "home").exists()


def test_closed_stdin_listing_and_only_needed_install_steps(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[list[str]] = []

    def fake_run(command: str, arguments: list[str], **kwargs: object) -> RunResult:
        assert kwargs.get("cwd") is not None
        calls.append([command, *arguments])
        if arguments[-2:] == ["list", "--json"] and "marketplace" in arguments:
            return RunResult(exit_code=0, output='[{"name":"ps-legion-marketplace"}]', error="", timed_out=False)
        if arguments[-2:] == ["list", "--json"]:
            return RunResult(exit_code=0, output='[{"id":"legion@ps-legion-marketplace","enabled":true}]', error="", timed_out=False)
        return RunResult(exit_code=0, output="", error="", timed_out=False)

    monkeypatch.setattr(_plugins, "run_command", fake_run)
    monkeypatch.setattr(shutil, "which", lambda name: name)
    folder = tmp_path / "claude"
    folder.mkdir()
    with pytest.raises(_installer.InstallerError, match="commands not refreshed"):
        _installer.install(home=tmp_path, catalog=catalog(), tools=["claude"], config_dir=folder, source=tmp_path, yes=True)
    assert ["claude", "plugin", "install", "legion@ps-legion-marketplace"] in calls
    assert all(args[1:4] != ["plugin", "marketplace", "add"] for args in calls)


def test_install_prompt_discloses_path_edit(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setattr(shutil, "which", lambda _name: "claude")
    questions: list[str] = []
    monkeypatch.setattr(_installer.click, "confirm", lambda question, **_options: questions.append(capsys.readouterr().out + question) or False)
    _installer.install(tmp_path, ["claude"], catalog=catalog())
    assert len(questions) == 1
    assert "PATH" in questions[0]


def test_installer_cli_reports_footprint_error_without_traceback(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer, "install", lambda *_args, **_kwargs: (_ for _ in ()).throw(_footprints.FootprintError("index busy")))
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "install", "--yes"])
    assert result.exit_code == 1
    assert "index busy" in result.output
    assert "Traceback" not in result.output


def test_confirmation_question_is_visible_before_input(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    def answer(question: str, **_options: object) -> bool:
        assert question == "Apply? [y/N]"
        assert capsys.readouterr().out == "plan line\n"
        return True

    monkeypatch.setattr(_installer.click, "confirm", answer)
    assert _installer._confirm("Apply? [y/N]", ["plan line"])


def test_confirmation_reads_yes_no_and_end_of_input(monkeypatch: pytest.MonkeyPatch) -> None:
    for text, expected in (("y\n", True), ("n\n", False), ("\n", False), ("", False)):
        monkeypatch.setattr("sys.stdin", io.StringIO(text))
        assert _installer._confirm("Apply? [y/N]", []) is expected


def test_cli_uninstall_runs_without_pwsh(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "uninstall", "--yes"])
    assert result.exit_code == 0, result.output
    assert "skip: uninstall (already done)" in result.output


@pytest.mark.parametrize("platform", ["win32", "linux", "darwin"])
def test_update_from_a_registered_session(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, platform: str) -> None:
    monkeypatch.setattr(_installer, "sys", SimpleNamespace(platform=platform))
    monkeypatch.setattr(shutil, "which", lambda name: name if name == "claude" else None)
    monkeypatch.setattr(_uv_tool.tempfile, "tempdir", str(tmp_path))
    uv = FakeUv(monkeypatch, tmp_path / "bin")
    monkeypatch.setenv("PATH", str(uv.bin), prepend=os.pathsep)
    uv.installed = "0.9.0"
    source = make_source(tmp_path)
    root = seed_copy("claude", tmp_path / ".claude", "1.0.0")
    (root / "pyproject.toml").write_bytes((source / "pyproject.toml").read_bytes())
    plugin_steps: list[list[str]] = []
    installed_clis(monkeypatch, lambda _tool, words, _folder: plugin_steps.append(words))
    run = run_folder(tmp_path)
    run.mkdir(parents=True)
    parent = run / f"{os.getppid()}.pid"
    parent.write_text(str(os.getppid()), encoding="ascii")
    stale = run / "stale.pid"
    stale.write_text("invalid", encoding="ascii")

    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "update", "--yes"])

    if platform == "win32":
        assert result.exit_code == 1, result.output
        assert result.stderr.splitlines() == ["Close this Legion session, run `legion update` from a terminal, then reopen Legion."]
        assert result.stdout == ""
        assert plugin_steps == []
        assert set(run.iterdir()) == {parent, stale}
        assert uv.calls == []
        assert uv.detached == []
    else:
        assert result.exit_code == 0, result.output
        assert "Restart this session after the legion update." in result.stderr
        assert plugin_steps
        assert not _stop_event.stop_path(tmp_path).exists()
        assert not stale.exists()
        assert uv.detached == []
        (command,) = uv.installs()
        assert "--reinstall" in command
        assert ["tool", "update-shell"] not in uv.calls
        assert result.stdout.splitlines()[-1] == "legion 1.0.0 is installed; restart your sessions."


@pytest.mark.parametrize("words", [("uninstall",), ("install", "--uninstall")])
def test_uninstall_shows_each_command_before_running_it(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], words: tuple[str, ...]) -> None:
    folder = tmp_path / "account"
    folder.mkdir()
    monkeypatch.setattr(shutil, "which", lambda name: name if name == "claude" else None)
    executed: list[list[str]] = []

    def execute(_tool: str, arguments: list[str], account: Path) -> None:
        output = capsys.readouterr().out
        assert str(account) in output
        assert " ".join(arguments) in output
        executed.append(arguments)

    installed_clis(monkeypatch, execute)
    _cli.main.main(["--home", str(tmp_path), *words, "--yes", "--tool", "claude", "--config-dir", str(folder)], standalone_mode=False)
    plugin = _installer.catalog_tool(catalog(), "claude").plugin
    assert executed == [plugin.uninstall, plugin.marketplace_remove]
    assert capsys.readouterr().out.splitlines()[-1] == "done: legion is uninstalled from the selected accounts"


def _update_two_targets(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, failing: frozenset[str] = frozenset(), versions: Optional[dict[str, str]] = None) -> tuple[list[str], list[tuple[Path, bool]]]:
    versions = versions or {}
    for tool_id in ("claude", "codex"):
        seed_copy(tool_id, tmp_path / f".{tool_id}", versions.get(tool_id, "1.2.3"))
    monkeypatch.setattr(shutil, "which", lambda name: name)
    installed_clis(monkeypatch)
    installs: list[tuple[Path, bool]] = []

    def install_tool(source: Path, _home: Path, detached: bool = False, **_options: object) -> list[str]:
        installs.append((source, detached))
        if failing:
            raise RuntimeError("broken install")
        return ["legion command is installed when this command ends"]

    monkeypatch.setattr(_uv_tool, "install", install_tool)
    if failing:
        with pytest.raises(_installer.InstallerError, match="commands not refreshed") as failed:
            _installer.install(tmp_path, ["claude", "codex"], update=True, yes=True, catalog=catalog())
        return [*failed.value.lines, str(failed.value)], installs
    lines = _installer.install(tmp_path, ["claude", "codex"], update=True, yes=True, catalog=catalog())
    return lines, installs


def test_update_installs_the_command_once_from_the_highest_plugin_version(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    lines, installs = _update_two_targets(tmp_path, monkeypatch, versions={"claude": "1.2.3", "codex": "1.10.0"})
    assert installs == [(tmp_path / ".codex/plugins/cache/ps-legion-marketplace/legion", False)]
    assert lines.count("legion command is installed when this command ends") == 1


def test_update_never_runs_uv_tool_update_shell(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    seen: list[dict[str, object]] = []
    monkeypatch.setattr(shutil, "which", lambda name: name if name == "claude" else None)
    monkeypatch.setattr(_uv_tool, "install", lambda _source, _home, **options: seen.append(options) or [])
    seed_copy("claude", tmp_path / "config", "1.2.3")
    installed_clis(monkeypatch)
    _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", update=True, yes=True, catalog=catalog())
    assert seen == [{"dry_run": False, "update_shell": False, "updating": True, "progress": None}]


def test_update_reconciles_knowledge_before_handing_over(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    events: list[str] = []
    monkeypatch.setattr(_installer, "_personalisation", lambda *_args: SimpleNamespace(agents=[], knowledge_enabled=True))
    monkeypatch.setattr(_installer, "reconcile_knowledge", lambda *_args: events.append("knowledge"))
    monkeypatch.setattr(_uv_tool, "install", lambda *_args, **_options: events.append("handover") or [])
    monkeypatch.setattr(shutil, "which", lambda name: name)
    seed_copy("claude", tmp_path / "config", "1.2.3")
    installed_clis(monkeypatch)
    _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", update=True, yes=True, catalog=catalog())
    assert events == ["knowledge", "handover"]


def test_update_reports_a_failed_uv_install_once_with_a_row(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    lines, installs = _update_two_targets(tmp_path, monkeypatch, failing=frozenset({"claude"}))
    assert len(installs) == 1
    assert lines.count("commands not refreshed: broken install; run legion setup") == 1
    assert any(line.startswith("legion") and line.endswith("commands not refreshed: broken install") for line in lines)


def test_update_dry_run_shows_the_uv_command_and_hands_nothing_over(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    uv = FakeUv(monkeypatch, tmp_path / "uv bin")
    seed_copy("claude", tmp_path / "config", "2.0.0")
    monkeypatch.setattr(shutil, "which", lambda name: name)
    installed_clis(monkeypatch)
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", update=True, dry_run=True, catalog=catalog())
    assert any("tool install" in line and "--reinstall" in line for line in lines)
    assert uv.installs() == []
    assert uv.detached == []


def _two_update_targets(monkeypatch: pytest.MonkeyPatch, home: Path, failure: BaseException) -> Path:
    monkeypatch.setattr(shutil, "which", lambda name: name if name in ("claude", "codex") else None)
    first = seed_copy("claude", home / ".claude", "2.0.0")
    seed_copy("codex", home / ".codex", "2.0.0")

    def mutate(tool: str, _arguments: list[str], _folder: Path) -> None:
        if tool == "codex":
            raise failure

    installed_clis(monkeypatch, mutate)
    return first


def test_update_installs_the_updated_plugin_when_a_later_account_is_interrupted(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    first = _two_update_targets(monkeypatch, tmp_path, KeyboardInterrupt())
    installs: list[Path] = []
    monkeypatch.setattr(_uv_tool, "install", lambda source, _home, **_options: installs.append(source) or [])
    with pytest.raises(KeyboardInterrupt):
        _installer.install(tmp_path, update=True, yes=True, catalog=catalog())
    assert installs == [first]


def test_update_shows_both_failures_and_keeps_the_exit_status_when_the_uv_install_fails_too(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def install_tool(_source: Path, _home: Path, **_options: object) -> list[str]:
        raise _uv_tool.UvToolError("uv tool install exited 2")

    _two_update_targets(monkeypatch, tmp_path, OSError("second account update failed"))
    monkeypatch.setattr(_uv_tool, "install", install_tool)
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "update", "--yes"])
    assert result.exit_code == 1
    assert "commands not refreshed: uv tool install exited 2; run legion setup" in result.output
    assert "second account update failed" in result.output


def test_other_marketplace_source_loads_its_catalog_for_selected_ref(monkeypatch: pytest.MonkeyPatch) -> None:
    urls: list[str] = []

    def fake_get(url: str, _timeout: float) -> bytes:
        urls.append(url)
        return CATALOG_PATH.read_bytes()

    monkeypatch.setattr(_installer, "get_bytes", fake_get)
    assert _installer.load_catalog("example/marketplace", "main", None).schema_version == 1
    assert urls == ["https://raw.githubusercontent.com/example/marketplace/main/plugins/legion/tools.json"]


def test_confirmation_prints_target_preview_before_asking(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    lines = ["Target: codex in selected folder", "codex plugin remove legion@ps-legion-marketplace"]

    def answer(_question: str, **_options: object) -> bool:
        assert "Target: codex in selected folder" in capsys.readouterr().out
        return False

    monkeypatch.setattr(_installer.click, "confirm", answer)
    assert not _installer._confirm("Uninstall? [y/N]", lines)
    assert lines == []


def test_plain_install_entry_accepts_bootstrap_lifecycle_options(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    calls: list[dict[str, object]] = []

    def fake_install(_home: Path, *_args: object, **options: Any) -> list[str]:
        calls.append(options)
        return ["ready"]

    monkeypatch.setattr(_installer, "install", fake_install)
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "install", "--tool", "codex", "--source", "example/marketplace", "--ref", "main", "--uninstall", "--purge", "--yes"])
    assert result.exit_code == 0, result.output
    assert calls[0]["uninstall"] is True
    assert calls[0]["purge"] is True


def _fake_targets(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(shutil, "which", lambda name: name if name in ("claude", "codex") else None)
    installed_clis(monkeypatch, lambda tool, _arguments, folder: seed_copy(tool, folder, "1.2.3"))
    monkeypatch.setattr(_uv_tool, "install", lambda *_args, **_options: [])


def test_install_from_the_uv_tool_hands_over_only_after_installing_all_targets(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(monkeypatch)
    events: list[str] = []
    monkeypatch.setattr(_uv_tool, "find_uv", lambda: "uv")
    monkeypatch.setattr(_uv_tool, "running_from_tool", lambda _uv: True)

    def mutate(tool: str, arguments: list[str], folder: Path) -> None:
        if arguments == _installer.catalog_tool(catalog(), tool).plugin.install:
            events.append(tool)
            seed_copy(tool, folder, "1.2.3")

    installed_clis(monkeypatch, mutate)
    monkeypatch.setattr(_uv_tool, "install", lambda *_args, **_options: events.append("handover") or [])
    _installer.install(tmp_path, ["claude", "codex"], yes=True, catalog=catalog())
    assert events == ["claude", "codex", "handover"]


def test_a_dry_run_prints_no_results_table(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(monkeypatch)
    assert "Results:" not in _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", dry_run=True, catalog=catalog())


def test_ref_main_with_the_default_source_reads_the_remote_catalog_not_the_local_one(monkeypatch: pytest.MonkeyPatch) -> None:
    urls: list[str] = []
    remote = json.loads(CATALOG_PATH.read_bytes())
    remote["tools"][0]["installHint"] = "remote main catalog"

    def fake_get(url: str, _timeout: float) -> bytes:
        urls.append(url)
        return json.dumps(remote).encode("utf-8")

    monkeypatch.setattr(_installer, "get_bytes", fake_get)
    assert _installer.load_catalog("BlackGad/ps-legion-marketplace", "main", None).tools[0].install_hint == "remote main catalog"
    assert urls == ["https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/tools.json"]
    urls.clear()
    monkeypatch.setattr(_installer, "get_bytes", lambda *_a, **_k: pytest.fail("the release track reads the shipped catalog"))
    assert _installer.load_catalog("BlackGad/ps-legion-marketplace", "release", None).schema_version == 1


# Consent and next steps, ported from the PowerShell installer tests that went with it.
@pytest.mark.parametrize("update", [False, True])
@pytest.mark.parametrize(("powershell_bootstrap", "flag"), [(False, "--yes"), (True, "-Yes")])
def test_install_without_consent_changes_nothing_and_says_how_to_apply(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, update: bool, powershell_bootstrap: bool, flag: str) -> None:
    _fake_targets(monkeypatch)

    if powershell_bootstrap:
        monkeypatch.setenv("LEGION_BOOTSTRAP_POWERSHELL", "1")
    else:
        monkeypatch.delenv("LEGION_BOOTSTRAP_POWERSHELL", raising=False)
    monkeypatch.setattr("sys.stdin", io.StringIO(""))
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", update=update, catalog=catalog())
    assert lines[-1] == f"Nothing changed. Run again with {flag} to apply."
    assert not (tmp_path / "config").exists()
    assert not (tmp_path / ".legion").exists()


def test_the_owner_can_say_yes_at_the_install_prompt(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(monkeypatch)
    monkeypatch.setattr(_installer.click, "confirm", lambda *_args, **_options: True)
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", catalog=catalog())
    assert (tmp_path / "config/plugins/cache/ps-legion-marketplace/legion/plugin.json").is_file()
    assert "Nothing changed. Run again with --yes to apply." not in lines


def test_a_dry_run_never_prompts_and_changes_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(monkeypatch)
    monkeypatch.setattr(_installer.click, "confirm", lambda *_args, **_options: pytest.fail("a dry run asked"))
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", dry_run=True, catalog=catalog())
    assert not (tmp_path / "config").exists()
    assert not (tmp_path / ".legion").exists()
    assert lines[0] == "Install legion for claude"


def test_install_names_the_installed_version_track_and_next_step(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(monkeypatch)
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", ref="main", yes=True, catalog=catalog())
    assert "installed: legion 1.2.3 (main)" in lines
    assert "next: legion add claude (or legion in a repository)" in lines


def test_install_prints_the_tool_hook_hint(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(monkeypatch)
    hint = next(tool for tool in catalog().tools if tool.id == "codex").hooks.hint
    assert hint
    assert hint in _installer.install(tmp_path, ["codex"], config_dir=tmp_path / "config", yes=True, catalog=catalog())


def test_update_asks_once_across_folders(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    _fake_targets(monkeypatch)
    questions: list[str] = []
    monkeypatch.setattr(_installer.click, "confirm", lambda question, **_options: questions.append(capsys.readouterr().out + question) or True)
    _installer.install(tmp_path, ["claude", "codex"], config_dir=tmp_path / "config", update=True, catalog=catalog())
    assert len(questions) == 1
    assert questions[0].endswith("Update legion? [y/N]")


def catalog_not_found(_request: httpx.Request) -> httpx.Response:
    return httpx.Response(404)


def catalog_times_out(request: httpx.Request) -> httpx.Response:
    raise httpx.ReadTimeout("timed out", request=request)


@pytest.mark.parametrize("handler", [catalog_not_found, catalog_times_out])
def test_a_catalog_that_cannot_be_read_is_a_plain_installer_error(monkeypatch: pytest.MonkeyPatch, handler: Callable[[httpx.Request], httpx.Response]) -> None:
    monkeypatch.setattr(_http, "https_client", lambda timeout: https_client(timeout, httpx.MockTransport(handler)))
    with pytest.raises(_installer.InstallerError, match="could not read the tools catalog"):
        _installer.load_catalog("example/marketplace", "main", None)
