import json
import shutil
from collections.abc import Callable
from pathlib import Path
from typing import Optional

import httpx
import pytest
from click.testing import CliRunner

from legion.services.installation import installer as _installer
from legion.services.lifecycle import _plugins
from legion import cli as _cli
from legion.core import _http
from legion.core._http import https_client
from legion.core._run import RunResult
from legion.core._settings_models import ToolsCatalog


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
def test_uninstall_runs_registered_script(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, suffix: str) -> None:
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
    _installer.uninstall(tmp_path, ["claude"], config_dir=folder, dry_run=True, catalog=catalog())
    program, prefix = ("pwsh", ["-NoProfile", "-File", str(script)]) if suffix == ".ps1" else (str(script), [])
    assert calls == [
        (program, [*prefix, "plugin", "list", "--json"]),
        (program, [*prefix, "plugin", "marketplace", "list", "--json"]),
    ]


@pytest.mark.parametrize("stock", [None, "claude"])
def test_uninstall_scopes_registered_command_to_its_folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, stock: Optional[str]) -> None:
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
    lines = _installer.uninstall(tmp_path, ["claude"], dry_run=True, catalog=catalog())
    expected = {(str(registered), str(a))}
    skip_b = f"skip: claude in {b} (no command for this folder)"
    assert skip_b in lines
    assert calls == expected


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
    lines = _installer.uninstall(tmp_path, ["claude"], dry_run=True, catalog=catalog())
    assert sum(line.startswith("skip: account folders (settings invalid: ") for line in lines) == 1
    assert calls == {("claude", str(folder))}


def test_cli_uninstall_runs_without_pwsh(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    result = CliRunner().invoke(_cli.main, ["--home", str(tmp_path), "uninstall", "--yes"])
    assert result.exit_code == 0, result.output
    assert "skip: uninstall (already done)" in result.output


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


def catalog_not_found(_request: httpx.Request) -> httpx.Response:
    return httpx.Response(404)


def catalog_times_out(request: httpx.Request) -> httpx.Response:
    raise httpx.ReadTimeout("timed out", request=request)


@pytest.mark.parametrize("handler", [catalog_not_found, catalog_times_out])
def test_a_catalog_that_cannot_be_read_is_a_plain_installer_error(monkeypatch: pytest.MonkeyPatch, handler: Callable[[httpx.Request], httpx.Response]) -> None:
    monkeypatch.setattr(_http, "https_client", lambda timeout: https_client(timeout, httpx.MockTransport(handler)))
    with pytest.raises(_installer.InstallerError, match="could not read the tools catalog"):
        _installer.load_catalog("example/marketplace", "main", None)
