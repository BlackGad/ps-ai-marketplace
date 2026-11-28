# Exercise the lifecycle through Click, executable CLIs, and the files they leave.

import json
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import pytest
from click.testing import CliRunner, Result

from fake_cli import (
    CONFIG,
    PLUGIN,
    plugin_root,
    write_shim,
)
from launcher_fakes import only_on_path
from legion.cli import main

REPO = Path(__file__).resolve().parents[3]
WAITING = "Waiting for running Legion sessions to exit..."
NO_CLI = "No coding CLI is installed. Run legion setup to install one."
QUESTION = "Apply? [y/N]"
UPDATED = "987.6.5"


def read_json(file: Path) -> dict[str, Any]:
    return json.loads(file.read_text(encoding="utf-8"))


def calls(path: Path) -> list[list[str]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines()]


def ordered(output: str, *parts: str) -> None:
    remaining = output
    for part in parts:
        assert part in remaining, f"Missing {part!r} in order in:\n{output}"
        remaining = remaining.split(part, 1)[1]


@dataclass
class Lifecycle:
    home: Path
    bin_dir: Path
    source: Path
    uv: Path
    version: str

    @property
    def settings(self) -> Path:
        return self.home / ".legion/configuration/personalisation.json"

    def enable(self, *tools: str) -> None:
        for tool in tools:
            write_shim(self.bin_dir, tool, Path(__file__).with_name("fake_cli.py"))

    def invoke(self, *args: str, answer: str | None = None, code: int = 0) -> Result:
        result = CliRunner().invoke(main, ["--home", str(self.home), *args], input=answer)
        assert result.exit_code == code, (result.output, result.exception)
        return result

    def install(self, answer: str = "y\n", code: int = 0) -> Result:
        return self.invoke("install", "--source", str(self.source), answer=answer, code=code)

    def add(self, tool: str) -> Result:
        return self.invoke("add", tool, "--source", str(self.source), "--yes")

    def outlander(self, tool: str) -> Path:
        return self.home / f".{tool}"

    def account(self, tool: str) -> Path:
        return self.home / ".legion/agents" / f"{tool}1"

    def assert_plugin(self, tool: str, folder: Path, version: str) -> None:
        assert read_json(plugin_root(tool, folder) / "plugin.json")["version"] == version
        assert read_json(folder / "fake-cli.json")["plugins"] == [PLUGIN]

    def publish_update(self) -> None:
        manifest_path = self.source / "plugins/legion/plugin.json"
        manifest = read_json(manifest_path)
        manifest["version"] = UPDATED
        manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

    def invoke_in_child(self, *args: str, answer: str, code: int = 0) -> str:
        # The handover waits for its parent to exit, so give CliRunner a short-lived process.
        command = ["--home", str(self.home), *args]
        child = subprocess.run(
            [sys.executable, str(Path(__file__)), json.dumps(command), answer],
            capture_output=True,
            text=True,
            encoding="utf-8",
            check=True,
            timeout=30,
        )
        exit_code, output = json.loads(child.stdout)
        assert exit_code == code, (output, child.stderr)
        return output

    def await_removal(self, *paths: Path) -> None:
        pending = (self.uv, self.home / ".legion/run/stop", *paths)
        deadline = time.monotonic() + 15
        while any(path.exists() for path in pending):
            if time.monotonic() > deadline:
                log = self.home / ".legion/temp/uv-tool.log"
                detail = log.read_text(encoding="utf-8") if log.exists() else ""
                pytest.fail(f"Handover left {[path for path in pending if path.exists()]}\n{detail}")
            time.sleep(0.05)


@pytest.fixture
def lifecycle(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Lifecycle:
    home = tmp_path.resolve() / "home with spaces"
    home.mkdir()
    for name in ("HOME", "USERPROFILE"):
        monkeypatch.setenv(name, str(home))
    for name in (*CONFIG.values(), "FAKE_CLI_FAIL", "FAKE_CLI_FAIL_FOLDER", "FAKE_UV_FAIL", "LEGION_BOOTSTRAP_POWERSHELL"):
        monkeypatch.delenv(name, raising=False)
    bin_dir = tmp_path.resolve() / "bin with spaces"
    write_shim(bin_dir, "uv", Path(__file__).with_name("fake_uv.py"))
    only_on_path(monkeypatch, bin_dir)
    uv = tmp_path / "fake-uv.json"
    monkeypatch.setenv("FAKE_UV_STATE", str(uv))
    monkeypatch.setenv("UV_TOOL_BIN_DIR", str(bin_dir))
    monkeypatch.setenv("PYTHONIOENCODING", "utf-8")
    source = tmp_path.resolve() / "checkout with spaces"
    for relative in (".claude-plugin/marketplace.json", "plugins/legion/tools.json", "plugins/legion/plugin.json"):
        target = source / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REPO / relative, target)
    version = read_json(source / "plugins/legion/plugin.json")["version"]
    return Lifecycle(home, bin_dir, source, uv, version)


def test_fresh_install_without_a_cli(lifecycle: Lifecycle) -> None:
    result = lifecycle.install()
    ordered(
        result.output,
        NO_CLI,
        *(f"skip: {tool} (not installed)" for tool in CONFIG),
        "Install plan:",
        QUESTION + "\n",
        WAITING,
        f"Preparing locked dependencies for legion {lifecycle.version}...",
        f"Installing legion {lifecycle.version} with uv...",
        f"legion command {lifecycle.version} installed",
    )
    state = read_json(lifecycle.uv)
    assert state["version"] == lifecycle.version
    assert Path(state["source"]) == REPO / "plugins/legion"
    assert calls(lifecycle.uv.with_suffix(".log")).count(["tool", "update-shell"]) == 1
    assert not lifecycle.settings.exists()
    assert not any(lifecycle.outlander(tool).exists() for tool in CONFIG)


def test_uv_install_failure_keeps_the_plugin_copy(lifecycle: Lifecycle, monkeypatch: pytest.MonkeyPatch) -> None:
    lifecycle.enable("claude")
    monkeypatch.setenv("FAKE_UV_FAIL", "install")
    result = lifecycle.install(code=1)
    ordered(result.output, f"claude plugin install {PLUGIN}", WAITING, "Results:", "failed: uv tool install exited 1")
    lifecycle.assert_plugin("claude", lifecycle.outlander("claude"), lifecycle.version)
    assert not lifecycle.uv.exists()
    assert not (lifecycle.home / ".legion/run/stop").exists()


def test_fresh_install_with_clis(lifecycle: Lifecycle) -> None:
    lifecycle.enable(*CONFIG)
    result = lifecycle.install()
    ordered(
        result.output,
        "Install plan:",
        *(f"Install legion for {tool} in {lifecycle.outlander(tool)}" for tool in CONFIG),
        QUESTION + "\n",
        "claude plugin marketplace add",
        f"claude plugin install {PLUGIN}",
        f"codex plugin add {PLUGIN}",
        f"copilot plugin install {PLUGIN}",
        WAITING,
        "Results:",
        *(f"installed legion {lifecycle.version}" for _ in CONFIG),
        f"legion command {lifecycle.version} installed",
    )
    for tool in CONFIG:
        lifecycle.assert_plugin(tool, lifecycle.outlander(tool), lifecycle.version)
    assert read_json(lifecycle.uv) == {"version": lifecycle.version, "source": str(plugin_root("claude", lifecycle.outlander("claude")))}
    assert not lifecycle.settings.exists()


def test_repeat_install_skips_existing_plugins_and_uv(lifecycle: Lifecycle) -> None:
    lifecycle.enable("codex")
    lifecycle.install()
    folder = lifecycle.outlander("codex")
    files = [folder / "fake-cli.json", plugin_root("codex", folder) / "plugin.json", lifecycle.uv]
    before = [path.read_bytes() for path in files]
    cli_log, uv_log = folder / "fake-cli.log", lifecycle.uv.with_suffix(".log")
    cli_count, uv_count = len(calls(cli_log)), len(calls(uv_log))
    result = lifecycle.install()
    ordered(
        result.output,
        "skip: codex plugin marketplace add",
        f"skip: codex plugin add {PLUGIN}",
        f"skip: legion command {lifecycle.version} (already done)",
        "Results:",
    )
    assert [path.read_bytes() for path in files] == before
    assert all("list" in args for args in calls(cli_log)[cli_count:])
    assert all(args[1] in ("list", "dir") for args in calls(uv_log)[uv_count:])
    assert not lifecycle.settings.exists()


def test_status_and_install_use_stock_default_folders(lifecycle: Lifecycle, monkeypatch: pytest.MonkeyPatch) -> None:
    lifecycle.enable("claude", "codex")
    overrides = {tool: lifecycle.home / f"override-{tool}" for tool in CONFIG}
    for tool, variable in CONFIG.items():
        monkeypatch.setenv(variable, str(overrides[tool]))
    lifecycle.add("claude")
    lifecycle.install()
    account = lifecycle.account("claude")
    claude, codex = (lifecycle.outlander(tool) for tool in ("claude", "codex"))
    logs = [folder / "fake-cli.log" for folder in (account, claude, codex)]
    before = [log.read_bytes() for log in logs]
    result = lifecycle.invoke("status")
    ordered(result.output, "accounts\n", f"claude1  claude  {account}", "outlanders\n", f"claude  {claude}  legion {lifecycle.version}", f"codex  {codex}  legion {lifecycle.version}")
    report = json.loads(lifecycle.invoke("status", "--json").output)
    assert [row["tool"] for row in report["outlanders"]] == ["claude", "codex"]
    assert [log.read_bytes() for log in logs] == before
    assert not any(folder.exists() for folder in overrides.values())
    assert not lifecycle.outlander("copilot").exists()


def test_install_repairs_unregistered_marketplace_with_cached_plugin(lifecycle: Lifecycle) -> None:
    lifecycle.enable("claude")
    lifecycle.install()
    folder = lifecycle.outlander("claude")
    state_file = folder / "fake-cli.json"
    state = read_json(state_file)
    state["marketplaces"] = {}
    state_file.write_text(json.dumps(state), encoding="utf-8")
    assert f"claude  {folder}  legion {lifecycle.version}" in lifecycle.invoke("status").output
    result = lifecycle.install()
    ordered(result.output, "claude plugin marketplace add", f"claude plugin install {PLUGIN}")
    lifecycle.assert_plugin("claude", folder, lifecycle.version)


@pytest.mark.parametrize("tool", CONFIG)
def test_install_enables_a_disabled_plugin_with_a_cached_version(lifecycle: Lifecycle, tool: str) -> None:
    lifecycle.enable(tool)
    lifecycle.install()
    folder = lifecycle.outlander(tool)
    state_file = folder / "fake-cli.json"
    state = read_json(state_file)
    state["disabled"] = [PLUGIN]
    state_file.write_text(json.dumps(state), encoding="utf-8")
    assert f"{tool}  {folder}  legion {lifecycle.version}" in lifecycle.invoke("status").output
    result = lifecycle.install()
    assert f"{tool} plugin {'add' if tool == 'codex' else 'install'} {PLUGIN}" in result.output
    assert "plugin marketplace add" not in result.output
    assert read_json(state_file)["disabled"] == []


def test_account_command_off_path_does_not_create_an_outlander(lifecycle: Lifecycle) -> None:
    folder = lifecycle.account("claude")
    private_bin = lifecycle.home / "registered bin"
    write_shim(private_bin, "claude", Path(__file__).with_name("fake_cli.py"))
    [command] = private_bin.iterdir()
    lifecycle.settings.parent.mkdir(parents=True)
    settings = {"schemaVersion": 1, "agents": [{"id": "claude1", "tool": "claude", "configDir": str(folder), "command": str(command)}], "channels": []}
    lifecycle.settings.write_text(json.dumps(settings), encoding="utf-8")
    lifecycle.install()
    lifecycle.assert_plugin("claude", folder, lifecycle.version)
    report = json.loads(lifecycle.invoke("status", "--json").output)
    assert report["outlanders"] == []
    assert not lifecycle.outlander("claude").exists()


def test_uv_uses_registered_claude_copy_when_a_newer_cache_remains(lifecycle: Lifecycle) -> None:
    lifecycle.enable("claude")
    lifecycle.install()
    folder = lifecycle.outlander("claude")
    active = plugin_root("claude", folder)
    stale = active / "stale/plugin.json"
    stale.parent.mkdir()
    stale.write_text('{"name":"legion","version":"999.0.0"}', encoding="utf-8")
    registration = {"plugins": {PLUGIN: [{"scope": "user", "installPath": str(active)}]}}
    (folder / "plugins/installed_plugins.json").write_text(json.dumps(registration), encoding="utf-8")
    assert f"claude  {folder}  legion {lifecycle.version}" in lifecycle.invoke("status").output
    lifecycle.uv.unlink()
    lifecycle.install()
    assert read_json(lifecycle.uv) == {"version": lifecycle.version, "source": str(active)}


def test_outlander_keeps_a_manually_installed_wiki(lifecycle: Lifecycle) -> None:
    lifecycle.enable("codex")
    lifecycle.install()
    folder = lifecycle.outlander("codex")
    wiki = "wiki@llm-wiki"
    state_file = folder / "fake-cli.json"
    state = read_json(state_file)
    state["marketplaces"]["llm-wiki"] = str(lifecycle.source)
    state["plugins"].append(wiki)
    state_file.write_text(json.dumps(state), encoding="utf-8")
    root = plugin_root("codex", folder, wiki)
    root.mkdir(parents=True)
    (root / "plugin.json").write_text('{"name":"wiki","version":"1.0.0"}', encoding="utf-8")
    lifecycle.settings.parent.mkdir(parents=True, exist_ok=True)
    lifecycle.settings.write_text('{"schemaVersion":1,"agents":[],"channels":[],"knowledgeEnabled":true}', encoding="utf-8")
    lifecycle.invoke("update", "--yes")
    lifecycle.invoke_in_child("uninstall", answer="y\n")
    lifecycle.await_removal()
    assert read_json(state_file) == {"marketplaces": {"llm-wiki": str(lifecycle.source)}, "plugins": [wiki]}
    upgrades = [args for args in calls(folder / "fake-cli.log") if args[:3] == ["plugin", "marketplace", "upgrade"]]
    assert upgrades
    assert all(args[3:] == [] for args in upgrades)


@pytest.mark.parametrize("answer", ["n\n", ""], ids=["no", "eof"])
def test_declined_install_leaves_home_untouched(lifecycle: Lifecycle, answer: str) -> None:
    lifecycle.enable("claude")
    before = list(lifecycle.home.iterdir())
    result = lifecycle.install(answer)
    ordered(result.output, "Install plan:", "Install legion for claude in", QUESTION, "\nNothing changed. Run again with --yes to apply.\n")
    assert list(lifecycle.home.iterdir()) == before
    assert not lifecycle.uv.exists()
    assert not lifecycle.uv.with_suffix(".log").exists()


def test_add_new_account(lifecycle: Lifecycle) -> None:
    lifecycle.enable("claude")
    folder = lifecycle.account("claude")
    result = lifecycle.invoke("add", "claude", "--source", str(lifecycle.source), answer="y\n")
    ordered(
        result.output,
        f"Add claude1 (claude) in {folder}",
        QUESTION + "\n",
        "claude plugin marketplace add",
        f"claude plugin install {PLUGIN}",
        WAITING,
        "Results:",
        f"installed legion {lifecycle.version}",
        "log in:",
        f"legion command {lifecycle.version} installed",
    )
    assert result.output.count(QUESTION) == 1
    assert ["plugin", "marketplace", "add", lifecycle.source.as_posix()] in calls(folder / "fake-cli.log")
    [agent] = read_json(lifecycle.settings)["agents"]
    assert (agent["id"], agent["tool"], Path(agent["configDir"]).expanduser()) == ("claude1", "claude", folder)
    lifecycle.assert_plugin("claude", folder, lifecycle.version)
    assert read_json(lifecycle.uv)["version"] == lifecycle.version
    assert not lifecycle.outlander("claude").exists()


def test_add_reports_plugin_failure_and_exits_one(lifecycle: Lifecycle, monkeypatch: pytest.MonkeyPatch) -> None:
    lifecycle.enable("claude")
    monkeypatch.setenv("FAKE_CLI_FAIL", "plugin install")
    result = lifecycle.invoke("add", "claude", "--source", str(lifecycle.source), "--yes", code=1)
    folder = lifecycle.account("claude")
    ordered(result.output, "fake claude: plugin install failed", "Results:", "claude1", str(folder), "failed: claude exited 1", "Setup failed.")
    assert read_json(lifecycle.settings)["agents"][0]["id"] == "claude1"
    assert not (plugin_root("claude", folder) / "plugin.json").exists()
    assert not lifecycle.uv.exists()


def test_setup_with_nothing_to_do(lifecycle: Lifecycle) -> None:
    lifecycle.enable("claude")
    lifecycle.add("claude")
    folder = lifecycle.account("claude")
    files = [lifecycle.settings, folder / "fake-cli.json", lifecycle.uv]
    before = [path.read_bytes() for path in files]
    result = lifecycle.invoke("setup")
    assert result.output.splitlines() == ["Nothing to do."]
    assert [path.read_bytes() for path in files] == before
    lifecycle.assert_plugin("claude", folder, lifecycle.version)


def test_plain_install_uses_the_newest_copy_once(lifecycle: Lifecycle) -> None:
    lifecycle.enable("claude")
    claude = lifecycle.outlander("claude")
    lifecycle.install()
    lifecycle.enable("codex")
    lifecycle.publish_update()
    lifecycle.uv.unlink()
    log = lifecycle.uv.with_suffix(".log")
    count = len(calls(log))
    lifecycle.install()
    lifecycle.assert_plugin("claude", claude, lifecycle.version)
    lifecycle.assert_plugin("codex", lifecycle.outlander("codex"), UPDATED)
    assert read_json(lifecycle.uv)["version"] == UPDATED
    assert [args[:2] for args in calls(log)[count:]].count(["tool", "install"]) == 1


def test_first_run_finishes_safe_steps_once(lifecycle: Lifecycle) -> None:
    lifecycle.enable("claude")
    lifecycle.add("claude")
    notes = lifecycle.settings.with_name("notes.md")
    notes.unlink()
    stamp = lifecycle.home / ".legion/version"
    stamp.write_text("0.0.1\n", encoding="utf-8")
    folder = lifecycle.account("claude")
    (plugin_root("claude", folder) / "plugin.json").unlink()
    result = lifecycle.invoke("status")
    ordered(result.output, "Finish plan", "Create notes", "needs approval", "Results:", "accounts")
    assert QUESTION not in result.output
    assert notes.is_file()
    assert stamp.read_text(encoding="utf-8").strip() == lifecycle.version
    assert not (plugin_root("claude", folder) / "plugin.json").exists()
    assert "Finish plan" not in lifecycle.invoke("status").output


@pytest.mark.parametrize("args", [("validate",), ("status", "--json")])
def test_first_run_preserves_machine_output(lifecycle: Lifecycle, args: tuple[str, ...]) -> None:
    lifecycle.settings.parent.mkdir(parents=True)
    lifecycle.settings.write_text('{"schemaVersion":1,"agents":[],"channels":[]}', encoding="utf-8")
    stamp = lifecycle.home / ".legion/version"
    stamp.write_text("0.0.1\n", encoding="utf-8")
    if args[0] == "validate":
        result = lifecycle.invoke(*args, "--kind", "personalisation", "--path", str(lifecycle.settings))
        assert result.output == ""
    else:
        result = lifecycle.invoke(*args)
        assert json.loads(result.output)["accounts"] == []
    assert stamp.read_text(encoding="utf-8").strip() == "0.0.1"
    assert not lifecycle.settings.with_name("notes.md").exists()


def test_setup_decline_leaves_knowledge_and_settings_untouched(lifecycle: Lifecycle) -> None:
    result = lifecycle.invoke("setup", "--knowledge", answer="")
    ordered(result.output, "Setup plan:", "Turn knowledge on", QUESTION, "\nNothing changed. Run again with --yes to apply.\n")
    assert list(lifecycle.home.iterdir()) == []


def test_first_run_failure_retries_and_runs_the_verb(lifecycle: Lifecycle) -> None:
    lifecycle.enable("claude")
    lifecycle.add("claude")
    notes = lifecycle.settings.with_name("notes.md")
    notes.unlink()
    notes.mkdir()
    stamp = lifecycle.home / ".legion/version"
    stamp.write_text("0.0.1\n", encoding="utf-8")
    result = lifecycle.invoke("status")
    assert "First-run check:" in result.stderr
    assert "accounts" in result.stdout
    assert stamp.read_text(encoding="utf-8").strip() == "0.0.1"
    notes.rmdir()
    assert "Finish plan" in lifecycle.invoke("status").output
    assert stamp.read_text(encoding="utf-8").strip() == lifecycle.version


@pytest.fixture
def installed_accounts(lifecycle: Lifecycle) -> Lifecycle:
    lifecycle.enable("claude", "codex")
    lifecycle.install()
    lifecycle.add("claude")
    lifecycle.add("codex")
    return lifecycle


def test_update_across_accounts_and_outlanders(installed_accounts: Lifecycle) -> None:
    env = installed_accounts
    env.publish_update()
    count = len(calls(env.uv.with_suffix(".log")))
    result = env.invoke("update", answer="y\n")
    targets = [(tool, folder) for tool in ("claude", "codex") for folder in (env.outlander(tool), env.account(tool))]
    ordered(
        result.output,
        "Update plan:",
        *(f"Update legion for {tool} in {folder} ({env.version})" for tool, folder in targets),
        QUESTION + "\n",
        WAITING,
        "Results:",
        *(str(folder) for _, folder in targets),
        f"legion {UPDATED} is installed; restart your sessions.",
    )
    assert result.output.count(f"{env.version} -> {UPDATED}") >= len(targets)
    for tool, folder in targets:
        env.assert_plugin(tool, folder, UPDATED)
    assert read_json(env.uv)["version"] == UPDATED
    assert [args[:2] for args in calls(env.uv.with_suffix(".log"))[count:]].count(["tool", "install"]) == 1
    assert {agent["id"] for agent in read_json(env.settings)["agents"]} == {"claude1", "codex1"}


def test_update_with_a_failed_target(installed_accounts: Lifecycle, monkeypatch: pytest.MonkeyPatch) -> None:
    env = installed_accounts
    env.publish_update()
    monkeypatch.setenv("FAKE_CLI_FAIL", "plugin update")
    monkeypatch.setenv("FAKE_CLI_FAIL_FOLDER", str(env.account("claude")))
    result = env.invoke("update", answer="y\n", code=1)
    ordered(result.output, QUESTION + "\n", "fake claude: plugin update failed", "codex plugin marketplace upgrade", WAITING, "Results:", "failed: claude exited 1", "Update failed.")
    env.assert_plugin("claude", env.outlander("claude"), UPDATED)
    env.assert_plugin("claude", env.account("claude"), env.version)
    for folder in (env.outlander("codex"), env.account("codex")):
        env.assert_plugin("codex", folder, UPDATED)
    assert read_json(env.uv) == {"version": UPDATED, "source": str(plugin_root("claude", env.outlander("claude")))}


@pytest.mark.skipif(sys.platform != "win32", reason="Only Windows refuses updates from a registered session")
def test_windows_update_refuses_a_registered_ancestor(lifecycle: Lifecycle) -> None:
    lifecycle.install()
    run = lifecycle.home / ".legion/run"
    registration = run / f"{os.getpid()}.pid"
    registration.write_text(str(os.getpid()), encoding="ascii")
    before = lifecycle.uv.read_bytes()
    output = lifecycle.invoke_in_child("update", answer="y\n", code=1)
    assert output.splitlines() == ["Close this Legion session, run `legion update` from a terminal, then reopen Legion."]
    assert registration.is_file()
    assert lifecycle.uv.read_bytes() == before
    assert not (run / "stop").exists()


def test_uninstall_and_repeat_keep_accounts_and_settings(lifecycle: Lifecycle) -> None:
    lifecycle.enable("codex")
    lifecycle.install()
    lifecycle.add("codex")
    account, outlander = lifecycle.account("codex"), lifecycle.outlander("codex")
    login = account / "login.json"
    login.write_text('{"fixture":true}', encoding="utf-8")
    settings = lifecycle.settings.read_bytes()
    result = lifecycle.invoke_in_child("uninstall", answer="y\n")
    ordered(result, "Uninstall plan:", QUESTION, WAITING, f"codex plugin remove {PLUGIN}", "Results:", "legion command removal scheduled.")
    assert result.count(QUESTION) == 1
    lifecycle.await_removal()
    for folder in (account, outlander):
        assert not (plugin_root("codex", folder) / "plugin.json").exists()
        assert read_json(folder / "fake-cli.json") == {"marketplaces": {}, "plugins": []}
        ordered("\n".join(" ".join(args) for args in calls(folder / "fake-cli.log")), f"plugin remove {PLUGIN}", "plugin marketplace remove ps-legion-marketplace")
    assert lifecycle.settings.read_bytes() == settings
    assert login.read_text(encoding="utf-8") == '{"fixture":true}'
    repeat = lifecycle.invoke_in_child("uninstall", answer="")
    assert "skip: uninstall (already done)" in repeat
    assert QUESTION not in repeat
    assert calls(lifecycle.uv.with_suffix(".log")).count(["tool", "uninstall", "legion"]) == 1
    assert lifecycle.settings.read_bytes() == settings
    assert login.is_file()


@pytest.mark.parametrize("answer", ["y\n", "n\n", ""], ids=["delete-hub", "keep-hub", "hub-eof"])
def test_purge_asks_about_the_hub_separately(lifecycle: Lifecycle, answer: str) -> None:
    lifecycle.enable("claude")
    lifecycle.install()
    lifecycle.add("claude")
    legion = lifecycle.home / ".legion"
    hub = legion / "knowledge"
    hub.mkdir()
    (hub / "keep.md").write_text("hub fixture", encoding="utf-8")
    pointer = lifecycle.home / ".config/llm-wiki/config.json"
    pointer.parent.mkdir(parents=True)
    pointer.write_text('{"hub_path":"~/.legion/knowledge"}', encoding="utf-8")
    other_children = [child for child in legion.iterdir() if child != hub]
    result = lifecycle.invoke_in_child("uninstall", "--purge", answer="y\n" + answer)
    ordered(
        result,
        f"Remove folder: {legion}",
        "Asked separately: the knowledge hub",
        QUESTION,
        WAITING,
        f"claude plugin uninstall {PLUGIN}",
        "Also delete the knowledge hub in ~/.legion/knowledge? [y/N] ",
        "Results:",
        "Legion folder removal scheduled.",
        "legion command removal scheduled.",
    )
    if answer == "y\n":
        lifecycle.await_removal(legion)
        assert not pointer.exists()
    else:
        lifecycle.await_removal(*other_children)
        assert list(legion.iterdir()) == [hub]
        assert (hub / "keep.md").read_text(encoding="utf-8") == "hub fixture"
        assert read_json(pointer) == {"hub_path": "~/.legion/knowledge"}
    outlander = lifecycle.outlander("claude")
    assert outlander.is_dir()
    assert read_json(outlander / "fake-cli.json") == {"marketplaces": {}, "plugins": []}


@pytest.mark.parametrize("answer", ["n\n", ""], ids=["no", "eof"])
def test_uninstall_decline_keeps_installations(installed_accounts: Lifecycle, answer: str) -> None:
    env = installed_accounts
    result = env.invoke("uninstall", answer=answer)
    ordered(result.output, "Uninstall plan:", QUESTION, "Nothing changed. Run again with --yes to apply.")
    assert f"\n{WAITING}\n" not in result.output
    assert env.uv.exists()
    env.assert_plugin("codex", env.account("codex"), env.version)


def test_uninstall_continues_after_a_failed_target(installed_accounts: Lifecycle, monkeypatch: pytest.MonkeyPatch) -> None:
    env = installed_accounts
    monkeypatch.setenv("FAKE_CLI_FAIL", "plugin uninstall")
    monkeypatch.setenv("FAKE_CLI_FAIL_FOLDER", str(env.account("claude")))
    output = env.invoke_in_child("uninstall", answer="y\n", code=1)
    ordered(output, WAITING, "fake claude: plugin uninstall failed", f"codex plugin remove {PLUGIN}", "Results:", "failed: claude exited 1", "Uninstall failed.")
    env.await_removal()
    env.assert_plugin("claude", env.account("claude"), env.version)
    for folder in (env.outlander("codex"), env.account("codex")):
        assert read_json(folder / "fake-cli.json") == {"marketplaces": {}, "plugins": []}


def test_uninstall_dry_run_previews_without_removal(lifecycle: Lifecycle) -> None:
    lifecycle.enable("copilot")
    lifecycle.install()
    output = lifecycle.invoke("uninstall", "--purge", "--dry-run", answer="y\ny\n").output
    ordered(output, "Purge plan:", "Remove folder:", f"copilot plugin uninstall {PLUGIN}", "plugin marketplace remove")
    assert QUESTION not in output
    assert lifecycle.uv.is_file()
    assert not (lifecycle.home / ".legion/run/stop").exists()
    lifecycle.assert_plugin("copilot", lifecycle.outlander("copilot"), lifecycle.version)


def test_uninstall_stops_a_registered_session_before_removing_plugins(lifecycle: Lifecycle) -> None:
    lifecycle.enable("codex")
    lifecycle.install()
    folder = lifecycle.outlander("codex")
    cli_log = folder / "fake-cli.log"
    run = lifecycle.home / ".legion/run"
    observed = run / "session-stopped"
    code = """
import os, sys, time
from pathlib import Path
run, cli_log, observed = map(Path, sys.argv[1:])
registration = run / f"{os.getpid()}.pid"
registration.write_text(str(os.getpid()), encoding="ascii")
while not (run / "stop").exists():
    time.sleep(0.02)
removed = any('["plugin", "remove"' in line for line in cli_log.read_text(encoding="utf-8").splitlines())
observed.write_text(str(removed), encoding="ascii")
registration.unlink()
"""
    with subprocess.Popen([sys.executable, "-c", code, str(run), str(cli_log), str(observed)]) as child:
        try:
            deadline = time.monotonic() + 10
            while not any(registration.stat().st_size for registration in run.glob("*.pid")):
                assert child.poll() is None, "Session exited before registering"
                assert time.monotonic() < deadline, "Session did not register"
                time.sleep(0.02)
            output = lifecycle.invoke_in_child("uninstall", "--yes", answer="")
            ordered(output, f"\n{WAITING}\n", f"codex plugin remove {PLUGIN}", "Results:", "legion command removal scheduled.")
            assert child.wait(timeout=5) == 0
            assert observed.read_text(encoding="ascii") == "False"
            lifecycle.await_removal()
        finally:
            if child.poll() is None:
                child.kill()


def test_uninstall_stops_when_it_cannot_raise_the_stop_event(lifecycle: Lifecycle) -> None:
    lifecycle.enable("codex")
    lifecycle.install()
    stop = lifecycle.home / ".legion/run/stop"
    stop.mkdir()
    result = lifecycle.invoke("uninstall", "--yes", code=1)
    ordered(result.output, f"\n{WAITING}\n", "Results:", "sessions", "failed:", "Uninstall failed.")
    assert "plugin remove" not in result.output
    lifecycle.assert_plugin("codex", lifecycle.outlander("codex"), lifecycle.version)
    assert lifecycle.uv.is_file()


def test_uninstall_removes_managed_wiki_and_keeps_the_hub(lifecycle: Lifecycle) -> None:
    lifecycle.enable("codex")
    lifecycle.add("codex")
    folder = lifecycle.account("codex")
    state_file = folder / "fake-cli.json"
    state = read_json(state_file)
    wiki = "wiki@llm-wiki"
    state["marketplaces"]["llm-wiki"] = str(lifecycle.source)
    state["plugins"].append(wiki)
    state_file.write_text(json.dumps(state), encoding="utf-8")
    root = plugin_root("codex", folder, wiki)
    root.mkdir(parents=True)
    (root / "plugin.json").write_text('{"name":"wiki","version":"1.0.0"}', encoding="utf-8")
    settings = read_json(lifecycle.settings)
    settings["knowledgeEnabled"] = True
    lifecycle.settings.write_text(json.dumps(settings), encoding="utf-8")
    hub = lifecycle.home / ".legion/knowledge"
    hub.mkdir()
    output = lifecycle.invoke_in_child("uninstall", "--yes", answer="")
    ordered(output, f"plugin remove {PLUGIN}", "marketplace remove ps-legion-marketplace", f"plugin remove {wiki}", "marketplace remove llm-wiki", "Results:")
    lifecycle.await_removal()
    assert read_json(state_file) == {"marketplaces": {}, "plugins": []}
    assert hub.is_dir()


def test_uninstall_with_invalid_settings_uses_outlanders(lifecycle: Lifecycle) -> None:
    lifecycle.enable("codex")
    lifecycle.install()
    lifecycle.settings.parent.mkdir(parents=True, exist_ok=True)
    lifecycle.settings.write_text("{broken", encoding="utf-8")
    output = lifecycle.invoke_in_child("uninstall", "--yes", answer="")
    ordered(output, "skip: account folders (settings invalid:", "Uninstall plan:", f"plugin remove {PLUGIN}", "Results:")
    lifecycle.await_removal()
    assert lifecycle.settings.read_text(encoding="utf-8") == "{broken"


def test_purge_keeps_legion_files_after_uv_failure(lifecycle: Lifecycle, monkeypatch: pytest.MonkeyPatch) -> None:
    lifecycle.enable("claude")
    lifecycle.install()
    lifecycle.add("claude")
    monkeypatch.setenv("FAKE_UV_FAIL", "uninstall")
    output = lifecycle.invoke_in_child("uninstall", "--purge", answer="y\n")
    ordered(output, "Purge plan:", QUESTION, WAITING, f"claude plugin uninstall {PLUGIN}", "Results:", "legion command removal scheduled.")
    log = lifecycle.home / ".legion/temp/uv-tool.log"
    stop = lifecycle.home / ".legion/run/stop"
    deadline = time.monotonic() + 15
    while not log.is_file() or "uv tool command exited 1" not in log.read_text(encoding="utf-8") or stop.exists():
        assert time.monotonic() < deadline, "Failed handover did not finish"
        time.sleep(0.05)
    assert lifecycle.uv.is_file()
    assert lifecycle.settings.is_file()
    monkeypatch.delenv("FAKE_UV_FAIL")
    lifecycle.invoke_in_child("uninstall", "--purge", "--yes", answer="")
    lifecycle.await_removal(lifecycle.home / ".legion")


@pytest.mark.parametrize(
    ("verb", "flag"),
    [("install", flag) for flag in ("--tool", "--config-dir", "--update", "--uninstall", "--purge")] + [("uninstall", flag) for flag in ("--tool", "--config-dir")],
)
def test_lifecycle_rejects_removed_options(lifecycle: Lifecycle, verb: str, flag: str) -> None:
    assert f"No such option '{flag}'" in lifecycle.invoke(verb, flag, code=2).output


if __name__ == "__main__":
    result = CliRunner().invoke(main, json.loads(sys.argv[1]), input=sys.argv[2])
    print(json.dumps([result.exit_code, result.output]))
