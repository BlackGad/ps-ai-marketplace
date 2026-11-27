import io
import json
from collections.abc import Callable
from pathlib import Path
from types import SimpleNamespace
from typing import Any, Optional

import httpx
import pytest
from click.testing import CliRunner

from legion.services.installation import _uv_tool, installer as _installer
from legion import cli as _cli
from legion.services.repository import _footprints
from legion.core import _http, _run
from legion.core._http import https_client
from legion.core._run import RunResult
from legion.core._settings_models import ToolsCatalog
from app_fakes import FakeUv, make_link, make_source


CATALOG_PATH = Path(__file__).resolve().parents[3] / "plugins/legion/tools.json"


def catalog() -> ToolsCatalog:
    return ToolsCatalog.model_validate_json(CATALOG_PATH.read_bytes())


def test_catalog_parses_tools_json_as_model() -> None:
    tools = _installer._catalog(Path(__file__).resolve().parents[3], "release", None)
    assert tools.schema_version == 1
    codex = _installer._tool(tools, "codex")
    assert codex.plugin.list_command == ["plugin", "list"]
    assert codex.install_hint == "npm install -g @openai/codex"


def test_catalog_rejects_unknown_shape(tmp_path: Path) -> None:
    data = json.loads(CATALOG_PATH.read_bytes())
    data["tools"][0]["unexpected"] = True
    path = tmp_path / "plugins/legion/tools.json"
    path.parent.mkdir(parents=True)
    path.write_text(json.dumps(data), encoding="utf-8")
    with pytest.raises(_installer.InstallerError, match="unexpected"):
        _installer._catalog(tmp_path, "release", None)


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
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: None)
    calls: list[tuple[str, list[str]]] = []

    def run(program: str, arguments: list[str], **_options: object) -> RunResult:
        calls.append((program, arguments))
        return RunResult(exit_code=0, output="[]", error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", run)
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
    monkeypatch.setattr(_installer.shutil, "which", lambda name: stock if name == "claude" else None)
    calls: set[tuple[str, str]] = set()

    def run(program: str, _arguments: list[str], *, env: dict[str, str], **_options: object) -> RunResult:
        calls.add((program, env["CLAUDE_CONFIG_DIR"]))
        return RunResult(exit_code=0, output="[]", error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", run)
    lines = _installer.install(tmp_path, ["claude"], dry_run=True, catalog=catalog(), update=mode == "update", uninstall=mode == "uninstall")
    expected = {(str(registered), str(a))}
    skip_b = f"skip: claude in {b} (no command for this folder)"
    if stock is not None:
        expected.add((stock, str(b)))
        assert skip_b not in lines
    else:
        assert skip_b in lines
    assert calls == expected


def test_missing_registered_command_gives_install_hint(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    write_installer_accounts(tmp_path, ("claude-a", tmp_path / "a", tmp_path / "missing"))
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: None)
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
    monkeypatch.setattr(_installer.shutil, "which", lambda name: "claude" if name == "claude" else None)
    calls: set[tuple[str, str]] = set()

    def run(program: str, _arguments: list[str], *, env: dict[str, str], **_options: object) -> RunResult:
        calls.add((program, env["CLAUDE_CONFIG_DIR"]))
        return RunResult(exit_code=0, output="[]", error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", run)
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
    monkeypatch.setattr(_installer.shutil, "which", lambda name: stock if name == "claude" else None)
    calls: list[str] = []
    installed = [{"id": "legion@ps-legion-marketplace", "enabled": True, "installPath": str(root), "version": "1.0.0"}]

    def run(program: str, arguments: list[str], **options: Any) -> RunResult:
        if options["env"]["CLAUDE_CONFIG_DIR"] == str(target):
            calls.append(program)
        output = json.dumps(installed) if arguments == ["plugin", "list", "--json"] else "[]"
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", run)
    tools = ["claude"] if operation in ("explicit install", "uninstall") else None
    _installer.install(home, tools=tools, config_dir=target, dry_run=True, catalog=catalog(), update=operation in ("update", "linked update"), uninstall=operation == "uninstall")
    assert set(calls) == {str(command)}


def test_no_coding_cli_installs_the_legion_command_through_uv_without_plugin(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    home = tmp_path / "home"
    source = make_source(tmp_path)
    uv = FakeUv(monkeypatch, tmp_path / "uv bin")
    monkeypatch.setattr(_installer, "PLUGIN_ROOT", source)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: "uv" if name == "uv" else None)

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
    monkeypatch.setattr(_installer.shutil, "which", lambda name: "uv" if name == "uv" else None)
    lines = _installer.install(tmp_path / "home", dry_run=True, catalog=catalog())
    assert any("tool install" in line and "--reinstall" in line for line in lines)
    assert uv.installs() == []
    assert uv.detached == []
    assert not (tmp_path / "home").exists()


def test_no_coding_cli_declined_command_install_changes_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: None)
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

    monkeypatch.setattr(_installer, "run_command", fake_run)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    folder = tmp_path / "claude"
    folder.mkdir()
    lines = _installer.install(home=tmp_path, catalog=catalog(), tools=["claude"], config_dir=folder, source=tmp_path, yes=True)
    assert len(calls) >= 2
    assert any("already done" in line for line in lines)
    assert not any("marketplace add" in line and not line.startswith("skip:") for line in lines)


def test_windows_cli_uses_resolved_cmd_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "codex")
    command = str(tmp_path / "codex.cmd")
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: command)
    monkeypatch.setattr(_installer, "run_command", lambda program, _args, **_kw: RunResult(exit_code=0, output=program, error="", timed_out=False))
    assert _installer._execute(entry, ["plugin", "list"], tmp_path) == command


def test_local_source_is_absolute_when_cli_runs_elsewhere(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "claude")
    source = tmp_path / "marketplace"
    source.mkdir()
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: False)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    lines: list[str] = []
    _installer._install_steps(entry, tmp_path, Path("marketplace"), "release", True, lines)
    assert source.as_posix() in lines[0]


def test_install_prompt_discloses_path_edit(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setattr(_installer.shutil, "which", lambda _name: "claude")
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


def test_codex_marketplace_without_root_is_not_ready(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "codex")
    monkeypatch.setattr(_installer, "_listing", lambda *_args: '{"marketplaces":[{"name":"ps-legion-marketplace"}]}')
    assert not _installer._marketplace(entry, tmp_path, require_root=True)


def test_copilot_root_uses_from_line_only_for_legion(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "copilot")
    unrelated = tmp_path / "unrelated"
    expected = tmp_path / "expected"
    for root in (unrelated, expected):
        manifest = root / "plugins/legion/plugin.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
        registry = root / ".claude-plugin/marketplace.json"
        registry.parent.mkdir()
        registry.write_text('{"name":"ps-legion-marketplace","plugins":[{"name":"legion","source":"plugins/legion"}]}', encoding="utf-8")
    listing = f"other@marketplace 1.0.0\n  from {unrelated}\nlegion@ps-legion-marketplace 1.2.3\n  from {expected}"
    monkeypatch.setattr(_installer, "_listing", lambda *_args: listing)
    assert _installer._plugin_root(entry, tmp_path) == expected / "plugins/legion"


def test_copilot_live_local_plugin_resolves_indented_listing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "copilot")
    folder = tmp_path / "copilot"
    folder.mkdir()
    marketplace = tmp_path / "checkout"
    manifest = marketplace / "plugins/legion/plugin.json"
    manifest.parent.mkdir(parents=True)
    manifest.write_text('{"name":"legion","version":"0.16.0"}', encoding="utf-8")
    registry = marketplace / ".claude-plugin/marketplace.json"
    registry.parent.mkdir()
    registry.write_text('{"name":"ps-legion-marketplace","plugins":[{"name":"legion","source":"./plugins/legion"}]}', encoding="utf-8")
    settings = {"extraKnownMarketplaces": {"ps-legion-marketplace": {"source": {"source": "directory", "path": str(marketplace)}}}, "enabledPlugins": {"legion@ps-legion-marketplace": True}}
    (folder / "settings.json").write_text(json.dumps(settings), encoding="utf-8")
    listing = f"Live Plugins (loaded from a local marketplace directory, never copied):\n  • legion@ps-legion-marketplace (v0.16.0) (enabled)\n      from {marketplace}"
    monkeypatch.setattr(_installer, "_listing", lambda *_args: listing)
    assert _installer._plugin_root(entry, folder) == manifest.parent

    settings["enabledPlugins"]["legion@ps-legion-marketplace"] = False
    (folder / "settings.json").write_text(json.dumps(settings), encoding="utf-8")
    monkeypatch.setattr(_installer, "_listing", lambda *_args: listing.replace("(enabled)", "(disabled)"))
    assert _installer._plugin_root(entry, folder) == manifest.parent

    monkeypatch.setattr(_installer, "_listing", lambda *_args: "No plugins installed.")
    assert _installer._plugin_root(entry, folder) is None

    monkeypatch.setattr(_installer, "_listing", lambda *_args: listing)
    settings["extraKnownMarketplaces"]["ps-legion-marketplace"]["source"]["path"] = str(tmp_path / "other")
    (folder / "settings.json").write_text(json.dumps(settings), encoding="utf-8")
    with pytest.raises(_installer.InstallerError, match="could not be identified uniquely"):
        _installer._plugin_root(entry, folder)

    del settings["extraKnownMarketplaces"]["ps-legion-marketplace"]
    (folder / "settings.json").write_text(json.dumps(settings), encoding="utf-8")
    assert _installer._plugin_root(entry, folder) is None

    settings["extraKnownMarketplaces"]["ps-legion-marketplace"] = {"source": {"source": "directory", "path": str(marketplace)}}
    (folder / "settings.json").write_text(json.dumps(settings), encoding="utf-8")
    registry.write_text('{"name":"other-marketplace","plugins":[{"name":"legion","source":"./plugins/legion"}]}', encoding="utf-8")
    with pytest.raises(_installer.InstallerError, match="could not be identified uniquely"):
        _installer._plugin_root(entry, folder)


def test_copilot_live_listing_rejects_ambiguous_legion_sources(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "copilot")
    roots = [tmp_path / "one", tmp_path / "two"]
    for root in roots:
        manifest = root / "plugins/legion/plugin.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
        registry = root / ".claude-plugin/marketplace.json"
        registry.parent.mkdir()
        registry.write_text('{"name":"ps-legion-marketplace","plugins":[{"name":"legion","source":"plugins/legion"}]}', encoding="utf-8")
    listing = "\n".join(f"  • legion@ps-legion-marketplace (v1.2.3) (enabled)\n      from {root}" for root in roots)
    monkeypatch.setattr(_installer, "_listing", lambda *_args: listing)
    with pytest.raises(_installer.InstallerError, match="could not be identified uniquely"):
        _installer._plugin_root(entry, tmp_path)


def test_copilot_copied_plugin_keeps_installed_root_semantics(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "copilot")
    folder = tmp_path / "copilot"
    manifest = folder / "installed-plugins/legion-marketplace/legion/plugin.json"
    manifest.parent.mkdir(parents=True)
    manifest.write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    (folder / "settings.json").write_text('{"extraKnownMarketplaces":{"other":{}}}', encoding="utf-8")
    monkeypatch.setattr(_installer, "_listing", lambda *_args: "legion@ps-legion-marketplace 1.2.3")
    assert _installer._plugin_root(entry, folder) == manifest.parent


def test_partly_installed_target_only_installs_missing_plugin(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "claude")
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: True)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    calls: list[list[str]] = []
    monkeypatch.setattr(_installer, "_step", lambda _entry, arguments, *_args: calls.append(arguments))
    _installer._install_steps(entry, tmp_path, tmp_path, "release", False, [])
    assert entry.plugin.install in calls
    assert not any(arguments[:3] == ["plugin", "marketplace", "add"] for arguments in calls)


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


@pytest.mark.parametrize("tool_id", ["claude", "codex", "copilot"])
def test_install_and_uninstall_target_use_fake_cli_and_refresh(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, tool_id: str) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == tool_id)
    command = entry.command
    folder = tmp_path / "config"
    root = folder / "installed-legion"
    installed = {"marketplace": False, "plugin": False}
    calls: list[list[str]] = []

    def fake_run(program: str, arguments: list[str], **kwargs: object) -> RunResult:
        assert program == command
        assert kwargs["cwd"] is not None
        calls.append(arguments)
        if arguments == entry.plugin.marketplace_list:
            found = [{"name": "ps-legion-marketplace", "root": str(folder)}] if installed["marketplace"] else []
            output = json.dumps({"marketplaces": found} if tool_id == "codex" else found)
        elif arguments == entry.plugin.list_command:
            if tool_id == "claude":
                output = json.dumps([{"id": "legion@ps-legion-marketplace", "enabled": True, "installPath": str(root)}] if installed["plugin"] else [])
            else:
                output = f"legion@ps-legion-marketplace 1.2.3 {root}" if installed["plugin"] else ""
        else:
            output = ""
            if arguments == entry.plugin.install:
                installed["plugin"] = True
                root.mkdir(parents=True, exist_ok=True)
                (root / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
            elif arguments == entry.plugin.uninstall:
                installed["plugin"] = False
            elif arguments == entry.plugin.marketplace_remove:
                installed["marketplace"] = False
            elif arguments[:3] == ["plugin", "marketplace", "add"]:
                installed["marketplace"] = True
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", fake_run)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(tmp_path / "saved-path.txt"))
    monkeypatch.setenv("PATH", "fixture-only")
    (tmp_path / "saved-path.txt").write_text("", encoding="utf-8")
    refreshed: list[Path] = []
    options_seen: list[dict[str, object]] = []
    monkeypatch.setattr(_installer._refresh, "refresh", lambda _home, source, **options: refreshed.append(source) or options_seen.append(options) or [])
    first = _installer.install(tmp_path, [tool_id], source=tmp_path, config_dir=folder, yes=True, catalog=catalog())
    assert installed == {"marketplace": True, "plugin": True}
    assert refreshed == [root]
    # The owner's yes to the install also covers uv tool update-shell.
    assert options_seen == [{"update_shell": True}]
    assert "installed: legion 1.2.3 (release)" in first
    assert any(arguments[:3] == ["plugin", "marketplace", "add"] for arguments in calls)
    assert entry.plugin.install in calls
    calls.clear()
    repeat = _installer.install(tmp_path, [tool_id], source=tmp_path, config_dir=folder, yes=True, catalog=catalog())
    assert any("already done" in line for line in repeat)
    assert entry.plugin.install not in calls
    _installer.install(tmp_path, [tool_id], config_dir=folder, yes=True, uninstall=True, catalog=catalog())
    assert installed == {"marketplace": False, "plugin": False}


def test_update_refreshes_new_installed_copy_and_reports_version(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "claude")
    folder = tmp_path / "config"
    root = folder / "plugin"
    root.mkdir(parents=True)
    manifest = root / "plugin.json"
    manifest.write_text('{"name":"legion","version":"1.0.0"}', encoding="utf-8")
    calls: list[list[str]] = []

    def fake_run(_command: str, arguments: list[str], **_kwargs: object) -> RunResult:
        calls.append(arguments)
        if arguments == entry.plugin.marketplace_list:
            output = '[{"name":"ps-legion-marketplace"}]'
        elif arguments == entry.plugin.list_command:
            version = json.loads(manifest.read_text(encoding="utf-8"))["version"]
            output = json.dumps([{"id": "legion@ps-legion-marketplace", "enabled": False, "installPath": str(root), "version": version}])
        else:
            output = ""
            if arguments == entry.plugin.update:
                manifest.write_text('{"name":"legion","version":"1.1.0"}', encoding="utf-8")
        return RunResult(exit_code=0, output=output, error="", timed_out=False)

    monkeypatch.setattr(_installer, "run_command", fake_run)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    refreshed: list[Path] = []
    monkeypatch.setattr(_installer._refresh, "refresh", lambda _home, source, **_options: refreshed.append(source) or [])
    lines = _installer.install(tmp_path, ["claude"], config_dir=folder, update=True, yes=True, catalog=catalog())
    assert refreshed == [root]
    assert "legion 1.0.0 -> 1.1.0" in lines
    assert entry.plugin.marketplace_update in calls
    assert entry.plugin.update in calls


def _update_two_targets(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, failing: frozenset[str] = frozenset(), versions: Optional[dict[str, str]] = None) -> tuple[list[str], list[tuple[Path, bool]]]:
    versions = versions or {}
    roots: dict[str, Path] = {}
    for tool_id in ("claude", "codex"):
        roots[tool_id] = tmp_path / f"plugin-{tool_id}"
        roots[tool_id].mkdir(exist_ok=True)
        (roots[tool_id] / "plugin.json").write_text(json.dumps({"name": "legion", "version": versions.get(tool_id, "1.2.3")}), encoding="utf-8")
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    monkeypatch.setattr(_installer, "_plugin_root", lambda entry, _folder: roots[entry.id])
    monkeypatch.setattr(_installer, "_step", lambda *_args: None)
    installs: list[tuple[Path, bool]] = []

    def refresh(_home: Path, source: Path, detached: bool = False) -> list[str]:
        installs.append((source, detached))
        if failing:
            raise RuntimeError("broken install")
        return ["legion command is installed when this command ends"]

    monkeypatch.setattr(_installer._refresh, "refresh", refresh)
    lines = _installer.install(tmp_path, ["claude", "codex"], config_dir=tmp_path / "config", update=True, yes=True, catalog=catalog())
    return lines, installs


def test_update_hands_one_uv_install_to_the_helper_for_the_highest_plugin_version(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    lines, installs = _update_two_targets(tmp_path, monkeypatch, versions={"claude": "1.2.3", "codex": "1.10.0"})
    assert installs == [(tmp_path / "plugin-codex", True)]
    assert lines.count("legion command is installed when this command ends") == 1


def test_update_never_runs_uv_tool_update_shell(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    seen: list[dict[str, object]] = []
    monkeypatch.setattr(_installer._refresh, "refresh", lambda _home, **options: seen.append({name: value for name, value in options.items() if name != "source"}) or [])
    monkeypatch.setattr(_installer, "_step", lambda *_args: None)
    monkeypatch.setattr(_installer, "_plugin_root", lambda *_args: tmp_path / "plugin")
    monkeypatch.setattr(_installer, "_manifest", lambda _root: SimpleNamespace(version="1.2.3"))
    _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", update=True, yes=True, catalog=catalog())
    assert seen == [{"detached": True}]


def test_update_reports_a_failed_uv_install_once_with_a_row(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    lines, installs = _update_two_targets(tmp_path, monkeypatch, failing=frozenset({"claude"}))
    assert len(installs) == 1
    assert lines.count("commands not refreshed: broken install; run legion setup") == 1
    assert any(line.startswith("legion") and line.endswith("commands not refreshed: broken install") for line in lines)


def test_update_dry_run_shows_the_uv_command_and_hands_nothing_over(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    uv = FakeUv(monkeypatch, tmp_path / "uv bin")
    root = tmp_path / "plugin"
    root.mkdir()
    (root / "plugin.json").write_text('{"name":"legion","version":"2.0.0"}', encoding="utf-8")
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    monkeypatch.setattr(_installer, "_plugin_root", lambda *_args: root)
    monkeypatch.setattr(_installer, "_step", lambda *_args: None)
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", update=True, dry_run=True, catalog=catalog())
    assert any("tool install" in line and "--reinstall" in line for line in lines)
    assert uv.installs() == []
    assert uv.detached == []


def _update_with_second_account_failing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, failure: BaseException = _installer.InstallerError("second account update failed")) -> list[Path]:
    steps = {"count": 0}

    def step(*_args: object) -> None:
        steps["count"] += 1
        if steps["count"] > 2:
            raise failure

    root = tmp_path / "plugin"
    root.mkdir()
    (root / "plugin.json").write_text('{"name":"legion","version":"2.0.0"}', encoding="utf-8")
    installs: list[Path] = []
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    monkeypatch.setattr(_installer, "_plugin_root", lambda *_args: root)
    monkeypatch.setattr(_installer, "_step", step)
    monkeypatch.setattr(_installer._refresh, "refresh", lambda _home, source, **_options: installs.append(source) or [])
    with pytest.raises(type(failure)):
        _installer.install(tmp_path, ["claude", "codex"], config_dir=tmp_path / "config", update=True, yes=True, catalog=catalog())
    return installs


def test_update_installs_the_updated_plugin_when_a_later_account_fails(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    assert _update_with_second_account_failing(tmp_path, monkeypatch) == [tmp_path / "plugin"]


def test_update_installs_the_updated_plugin_when_a_later_account_is_interrupted(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    assert _update_with_second_account_failing(tmp_path, monkeypatch, KeyboardInterrupt()) == [tmp_path / "plugin"]


def test_update_shows_both_failures_and_keeps_the_exit_status_when_the_uv_install_fails_too(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    def refresh(_home: Path, **_options: object) -> list[str]:
        raise _uv_tool.UvToolError("uv tool install exited 2")

    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)
    root = tmp_path / "plugin"
    root.mkdir()
    (root / "plugin.json").write_text('{"name":"legion","version":"2.0.0"}', encoding="utf-8")
    steps = {"count": 0}

    def step(*_args: object) -> None:
        steps["count"] += 1
        if steps["count"] > 2:
            raise _installer.InstallerError("second account update failed")

    monkeypatch.setattr(_installer, "_plugin_root", lambda *_args: root)
    monkeypatch.setattr(_installer, "_step", step)
    monkeypatch.setattr(_installer._refresh, "refresh", refresh)
    monkeypatch.setattr(_installer, "_catalog", lambda *_args: catalog())
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
    assert _installer._catalog("example/marketplace", "main", None).schema_version == 1
    assert urls == ["https://raw.githubusercontent.com/example/marketplace/main/plugins/legion/tools.json"]


def test_copilot_directory_marketplace_listing_finds_plugin_root(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "copilot")
    folder = tmp_path / "config"
    folder.mkdir()
    marketplace = tmp_path / "marketplace"
    manifest = marketplace / "plugins/legion/plugin.json"
    manifest.parent.mkdir(parents=True)
    manifest.write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    registry = marketplace / ".claude-plugin/marketplace.json"
    registry.parent.mkdir()
    registry.write_text('{"name":"ps-legion-marketplace","plugins":[{"name":"legion","source":"plugins/legion"}]}', encoding="utf-8")
    monkeypatch.setattr(_installer, "_listing", lambda *_: f"legion@ps-legion-marketplace 1.2.3\n  from {marketplace}")
    assert _installer._plugin_root(entry, folder) == manifest.parent


def test_missing_marketplace_reinstalls_plugin_even_when_stale_listing_is_enabled(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "claude")
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: False)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (True, True, [], "1.0.0"))
    lines: list[str] = []
    _installer._install_steps(entry, tmp_path, tmp_path, "release", True, lines)
    assert any("plugin install legion@ps-legion-marketplace" in line for line in lines)


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


def _fake_targets(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, failing: str = "") -> None:
    root = tmp_path / "plugin"
    root.mkdir()
    (root / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    monkeypatch.setattr(_installer.shutil, "which", lambda name: None if name == "copilot" else name)
    monkeypatch.setattr(_installer, "_install_steps", lambda *_args: None)
    monkeypatch.setattr(_installer, "_step", lambda *_args: None)
    monkeypatch.setattr(_installer, "_plugin_root", lambda *_args: root)
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(tmp_path / "saved-path.txt"))
    (tmp_path / "saved-path.txt").write_text("", encoding="utf-8")

    calls: list[Path] = []

    def refresh(_home: Path, source: Path, **_options: object) -> list[str]:
        calls.append(source)
        if failing and len(calls) == ["claude", "codex"].index(failing) + 1:
            raise RuntimeError("broken refresh")
        return ["refreshed later target"] if failing else []

    monkeypatch.setattr(_installer._refresh, "refresh", refresh)


def _table_rows(lines: list[str], count: int) -> list[list[str]]:
    start = lines.index("Results:")
    return [line.split() for line in lines[start + 2 : start + 2 + count]]


def test_install_ends_with_one_result_row_per_tool(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch, failing="claude")
    lines = _installer.install(tmp_path, ["claude", "codex", "copilot"], config_dir=tmp_path / "config", yes=True, catalog=catalog())
    assert lines[lines.index("Results:") + 1].split() == ["Tool", "Folder", "Result"]
    rows = _table_rows(lines, 3)
    assert [row[0] for row in rows] == ["claude", "codex", "copilot"]
    assert "not refreshed" in " ".join(rows[0][2:])
    assert rows[1][2:] == ["installed", "legion", "1.2.3"]
    assert any("claude" in line and "broken refresh" in line for line in lines)
    assert "refreshed later target" in lines
    assert rows[2][2:] == ["skipped", "(not", "installed)"]


def test_update_ends_with_one_result_row_per_target(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch, failing="claude")
    lines = _installer.install(tmp_path, ["claude", "codex"], config_dir=tmp_path / "config", update=True, yes=True, catalog=catalog())
    rows = _table_rows(lines, 3)
    assert [row[0] for row in rows] == ["claude", "codex", "legion"]
    assert [" ".join(row[2:]) for row in rows[:2]] == ["already up to date (1.2.3)"] * 2
    assert "not refreshed" in " ".join(rows[2][2:])
    assert any("commands not refreshed" in line and "broken refresh" in line for line in lines)


def test_a_dry_run_prints_no_results_table(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch)
    assert "Results:" not in _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", dry_run=True, catalog=catalog())


def test_ref_main_with_the_default_source_reads_the_remote_catalog_not_the_local_one(monkeypatch: pytest.MonkeyPatch) -> None:
    urls: list[str] = []
    remote = json.loads(CATALOG_PATH.read_bytes())
    remote["tools"][0]["installHint"] = "remote main catalog"

    def fake_get(url: str, _timeout: float) -> bytes:
        urls.append(url)
        return json.dumps(remote).encode("utf-8")

    monkeypatch.setattr(_installer, "get_bytes", fake_get)
    assert _installer._catalog("BlackGad/ps-legion-marketplace", "main", None).tools[0].install_hint == "remote main catalog"
    assert urls == ["https://raw.githubusercontent.com/BlackGad/ps-legion-marketplace/main/plugins/legion/tools.json"]
    urls.clear()
    monkeypatch.setattr(_installer, "get_bytes", lambda *_a, **_k: pytest.fail("the release track reads the shipped catalog"))
    assert _installer._catalog("BlackGad/ps-legion-marketplace", "release", None).schema_version == 1


# Consent and next steps, ported from the PowerShell installer tests that went with it.
def _steps_run(monkeypatch: pytest.MonkeyPatch) -> list[str]:
    ran: list[str] = []
    monkeypatch.setattr(_installer, "_install_steps", lambda entry, *_args: ran.append(entry.id))
    return ran


def test_install_without_consent_changes_nothing_and_says_how_to_apply(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch)
    ran = _steps_run(monkeypatch)

    monkeypatch.setattr("sys.stdin", io.StringIO(""))
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", catalog=catalog())
    assert lines[-1] == "Nothing changed. Run again with --yes to apply."
    assert ran == []
    assert not (tmp_path / "config").exists()
    assert not (tmp_path / ".legion").exists()


def test_the_owner_can_say_yes_at_the_install_prompt(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch)
    ran = _steps_run(monkeypatch)
    monkeypatch.setattr(_installer.click, "confirm", lambda *_args, **_options: True)
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", catalog=catalog())
    assert ran == ["claude"]
    assert "Nothing changed. Run again with --yes to apply." not in lines


def test_a_dry_run_never_prompts_and_changes_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch)
    monkeypatch.setattr(_installer.click, "confirm", lambda *_args, **_options: pytest.fail("a dry run asked"))
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", dry_run=True, catalog=catalog())
    assert not (tmp_path / "config").exists()
    assert not (tmp_path / ".legion").exists()
    assert lines[0] == "Install legion for claude"


@pytest.mark.parametrize(("platform", "quote"), [("win32", '"'), ("linux", "'")])
def test_install_preview_quotes_paths_with_spaces(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, platform: str, quote: str) -> None:
    monkeypatch.setattr(_run, "sys", SimpleNamespace(platform=platform))
    entry = catalog().tools[0]
    folder = tmp_path / "account folder"
    source = tmp_path / "local checkout"
    source.mkdir()
    command = f"claude plugin marketplace add {quote}{source.resolve().as_posix()}{quote}"
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: False)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    lines: list[str] = []
    _installer._install_steps(entry, folder, source, "main", True, lines)
    assert lines[0] == f"CLAUDE_CONFIG_DIR={quote}{folder}{quote} {command}"

    monkeypatch.setattr(_installer, "_marketplace", lambda *_args, **_kwargs: True)
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (True, True, [], ""))
    lines.clear()
    _installer._install_steps(entry, folder, source, "main", True, lines)
    assert lines[0] == f"skip: {command} (already done)"


def test_install_names_the_installed_version_track_and_next_step(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch)
    lines = _installer.install(tmp_path, ["claude"], config_dir=tmp_path / "config", ref="main", yes=True, catalog=catalog())
    assert "installed: legion 1.2.3 (main)" in lines
    assert "next: legion add claude (or legion in a repository)" in lines


def test_install_prints_the_tool_hook_hint(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    _fake_targets(tmp_path, monkeypatch)
    hint = next(tool for tool in catalog().tools if tool.id == "codex").hooks.hint
    assert hint
    assert hint in _installer.install(tmp_path, ["codex"], config_dir=tmp_path / "config", yes=True, catalog=catalog())


def test_update_asks_once_across_folders(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    _fake_targets(tmp_path, monkeypatch)
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
        _installer._catalog("example/marketplace", "main", None)


def test_plugin_listing_matches_whole_plugin_id(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "codex")
    for line in ("extra-legion@ps-legion-marketplace 1.2.3", "legion@ps-legion-marketplace-extra 1.2.3"):
        monkeypatch.setattr(_installer, "_listing", lambda *_args, line=line: line)
        assert _installer._plugin_state(entry, tmp_path)[0] is False


def test_plugin_rows_compare_the_whole_id_and_ignore_continuation_paths(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "copilot")
    rows = {
        "  • other@marketplace (v1.0.0) (enabled)\n      from /x/legion@ps-legion-marketplace": False,
        "other@marketplace 1.0.0\n  from /x/legion@ps-legion-marketplace": False,
        "  • extra-legion@ps-legion-marketplace (v1.0.0) (enabled)": False,
        "  • legion@ps-legion-marketplace-extra (v1.0.0) (enabled)": False,
        "  • legion@ps-legion-marketplace (v1.0.0) (enabled)\n      from /x/checkout": True,
        "legion@ps-legion-marketplace 1.2.3": True,
    }
    for listing, expected in rows.items():
        monkeypatch.setattr(_installer, "_listing", lambda *_args, listing=listing: listing)
        assert _installer._plugin_state(entry, tmp_path)[0] is expected, listing


@pytest.mark.parametrize("bullet", ["•", "ΓÇó", "?", "*", ""])
def test_plugin_row_id_ignores_whatever_bullet_the_listing_prints(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, bullet: str) -> None:
    entry = next(tool for tool in catalog().tools if tool.id == "copilot")
    prefix = f"  {bullet} " if bullet else "  "
    cases = {
        f"{prefix}legion@ps-legion-marketplace (v1.0.0) (enabled)\n      from /x/checkout": True,
        f"{prefix}other@marketplace (v1.0.0)\n      from /x/legion@ps-legion-marketplace": False,
        f"{prefix}extra-legion@ps-legion-marketplace (v1.0.0)": False,
        f"{prefix}legion@ps-legion-marketplace-extra (v1.0.0)": False,
    }
    for listing, expected in cases.items():
        monkeypatch.setattr(_installer, "_listing", lambda *_args, listing=listing: listing)
        assert _installer._plugin_state(entry, tmp_path)[0] is expected, listing
