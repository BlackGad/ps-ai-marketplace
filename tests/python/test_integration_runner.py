import importlib.util
import json
import os
import queue
import shutil
import subprocess
import sys
from contextlib import nullcontext
from pathlib import Path
from types import SimpleNamespace
from typing import Any

import pytest
from legion.services.installation._installed_runtime import shim_text


RUNNER = Path(__file__).resolve().parents[1] / "integration" / "run.py"
SPEC = importlib.util.spec_from_file_location("integration_runner", RUNNER)
assert SPEC
assert SPEC.loader
runner = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(runner)


def test_listing_parses_json_and_text_with_disabled_entries() -> None:
    json_entry = {"plugin": {"listing": {"format": "json", "idField": "id", "enabledField": "enabled"}}}
    text_entry = {"plugin": {"listing": {"format": "lines", "rejectPattern": "disabled"}}}
    assert runner.listed(json_entry, '[{"id":"legion@ps-legion-marketplace","enabled":false}]', include_disabled=True)
    assert not runner.listed(json_entry, '[{"id":"legion@ps-legion-marketplace","enabled":false}]')
    assert runner.listed(text_entry, "legion@ps-legion-marketplace 0.16.0")
    assert not runner.listed(text_entry, "legion@ps-legion-marketplace disabled")


def test_report_writes_all_evidence_and_omits_failed_benchmark(tmp_path: Path) -> None:
    cases = [runner.Case("install", False, "passed", 1.25, "", "ok"), runner.Case("install", True, "failed", 0.5, "repeat failed", "failure")]
    runner.write_report(tmp_path, "linux", cases, ["git: 2.0"], "claude 1.0")
    assert (tmp_path / "integration-linux.xml").exists()
    assert 'name="install (repeat)"' in (tmp_path / "integration-linux.xml").read_text(encoding="utf-8")
    assert [entry["name"] for entry in json.loads((tmp_path / "integration-bench-linux.json").read_text(encoding="utf-8"))] == ["linux / install"]
    assert "| install | 1.250 | 0.500 | failed |" in (tmp_path / "summary.md").read_text(encoding="utf-8")


def test_pwsh_trap_records_an_attempt(tmp_path: Path) -> None:
    checkout = Path(__file__).resolve().parents[2]
    instance = runner.Runner(checkout, tmp_path / "home", tmp_path / "results", False)
    with pytest.raises(AssertionError, match="a command called pwsh"), instance.without_pwsh():
        subprocess.run([sys.executable, "-c", "import shutil, subprocess; subprocess.run([shutil.which('pwsh')], check=False)"], env=instance.env, capture_output=True, check=False)
    assert (instance.work / "pwsh-trap/called").exists()


def make_runner(tmp_path: Path) -> Any:
    return runner.Runner(Path(__file__).resolve().parents[2], tmp_path / "home", tmp_path / "results", False)


def test_report_accepts_empty_and_control_character_messages(tmp_path: Path) -> None:
    runner.write_report(tmp_path, "linux", [runner.Case("x", False, "failed", 0, "\x1b[31mwrong\x08\x1b[0m", ""), runner.Case("x", True, "skipped", 0, "", "")], [])
    xml = (tmp_path / "integration-linux.xml").read_text(encoding="utf-8")
    assert 'message="wrong"' in xml
    assert "\x08" not in xml
    assert "\x1b" not in xml
    assert "skipped:" in (tmp_path / "summary.md").read_text(encoding="utf-8")


def test_command_path_survives_trap(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    folder = instance.home / ".local/bin"
    folder.mkdir(parents=True)
    (folder / ("vendor.cmd" if os.name == "nt" else "vendor")).write_text("@echo off\n" if os.name == "nt" else "#!/bin/sh\n", encoding="utf-8")
    if os.name != "nt":
        (folder / "vendor").chmod(0o755)
    with instance.without_pwsh():
        assert Path(instance.command("vendor")).parent == folder
    with instance.without_pwsh():
        assert Path(instance.command("vendor")).parent == folder


@pytest.mark.skipif(os.name != "nt", reason="Windows cmd shim")
def test_windows_npm_prefix_shim_is_on_child_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(runner, "WINDOWS", True)
    instance = make_runner(tmp_path)
    prefix = instance.home / ".local"
    prefix.mkdir()
    (prefix / "copilot.cmd").write_text("@echo off\r\n", encoding="utf-8")
    assert str(prefix) in instance.env["PATH"].split(os.pathsep)
    instance.env["PATH"] = str(prefix)
    assert Path(instance.command("copilot")).parent == prefix


@pytest.mark.skipif(os.name == "nt", reason="POSIX executable shim")
def test_posix_npm_shim_requires_executable_file(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    prefix = instance.home / ".local/bin"
    prefix.mkdir(parents=True)
    shim = prefix / "copilot"
    shim.write_text("#!/bin/sh\n", encoding="utf-8")
    shim.chmod(0o755)
    instance.env["PATH"] = str(prefix)
    assert Path(instance.command("copilot")) == shim


def test_candidate_version_advances_a_release_checkout() -> None:
    assert runner.next_candidate_version("0.18.0") != "0.18.0"
    assert tuple(map(int, runner.next_candidate_version("0.18.0").split("."))) > (0, 18, 0)


@pytest.mark.skipif(os.name != "nt", reason="Windows cmd launcher")
def test_windows_mcp_missing_child_exits_nonzero(tmp_path: Path) -> None:
    home = tmp_path / "home"
    app = home / ".legion/app/0.18.0"
    app.mkdir(parents=True)
    command = home / ".legion/bin/legion.cmd"
    command.parent.mkdir(parents=True)
    command.write_text(shim_text(app, home, True), encoding="utf-8")
    cmd = shutil.which("cmd.exe")
    assert cmd is not None
    result = subprocess.run([cmd, "/d", "/c", str(command), "mcp"], capture_output=True, text=True, check=False)
    assert result.returncode != 0


@pytest.mark.parametrize(("new_version", "new_command"), [("2.0.0", "old"), ("1.0.0", "new")])
def test_repeat_version_reports_both_values(tmp_path: Path, new_version: str, new_command: str) -> None:
    instance = make_runner(tmp_path)
    instance.versions["claude"] = ("1.0.0", "old")
    instance.install_tool = lambda _tool: "skip: tool (already done)"
    instance.command = lambda _name: new_command
    instance.run = lambda _argv, **_kwargs: new_version
    with pytest.raises(AssertionError, match=f"{new_version}.*{new_command}"):
        instance.install_cli("claude", True)


def test_repeat_snapshot_reports_omitted_count() -> None:
    with pytest.raises(AssertionError, match="5 more paths omitted"):
        runner.unchanged({}, {str(i): "new" for i in range(25)})


def test_windows_zip_retry_uses_exact_exit_code(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    instance = make_runner(tmp_path)
    monkeypatch.setattr(runner, "WINDOWS", True)
    calls = []

    def fail(*args: str) -> str:
        calls.append(args)
        raise RuntimeError("uv exited 20")

    instance.legion = fail
    with pytest.raises(RuntimeError, match="exited 20"):
        instance.install_tool("uv")
    assert len(calls) == 1


def test_steps_keep_first_repeat_order(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    names = [name for name, _ in instance.steps()]
    assert names == [
        "bootstrap",
        "install-cli-claude",
        "install-cli-codex",
        "install-cli-copilot",
        "update-from-0.17.0",
        "install-legion",
        "update-legion",
        "setup",
        "add",
        "remove",
        "repo-private",
        "repo-shared",
        "channel",
        "foundry-launcher",
        "no-pwsh",
        "uninstall",
        "reinstall",
        "restore-launchers",
        "purge",
        "candidate-client-evidence",
    ]


def test_runner_lists_update_from_0_17_0_case(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    assert dict(instance.steps())["update-from-0.17.0"].__self__ is instance
    events = []
    instance.prepare_candidate = lambda: events.append("stage")
    instance.install_old = lambda: events.append("install-0.17.0")
    instance.upgrade_candidate = lambda: events.append("old-launcher-update")
    instance.verify_candidate = lambda: events.append("identity-hook-cli-mcp-clients")
    instance.finish_candidate = lambda: events.append("candidate-repeat-uninstall-fence")
    instance.update_from_0_17_0(False)
    instance.update_from_0_17_0(True)
    assert events == ["stage", "install-0.17.0", "old-launcher-update", "identity-hook-cli-mcp-clients", "candidate-repeat-uninstall-fence"]


def test_candidate_staging_changes_only_disposable_versions(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    before = runner.snapshot(instance.checkout / "plugins/legion")
    candidate = instance.stage_candidate()
    assert candidate.is_relative_to(instance.work)
    for name in ("plugin.json", ".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
        assert json.loads((candidate / "plugins/legion" / name).read_text(encoding="utf-8"))["version"] == instance.candidate_version
    assert runner.snapshot(instance.checkout / "plugins/legion") == before
    assert (candidate / "plugins/legion/src/legion/mcp/server.py").read_bytes() == (instance.checkout / "plugins/legion/src/legion/mcp/server.py").read_bytes()


def test_candidate_environment_drops_wrong_checkout_and_account_context(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    for key in ("PYTHONPATH", "UV_PROJECT_ENVIRONMENT", "LEGION_TASK", "LEGION_ROLE", "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GH_TOKEN"):
        monkeypatch.setenv(key, "outside-sentinel")
    instance = make_runner(tmp_path)
    for key in ("PYTHONPATH", "UV_PROJECT_ENVIRONMENT", "LEGION_TASK", "LEGION_ROLE", "ANTHROPIC_API_KEY", "OPENAI_API_KEY", "GH_TOKEN"):
        assert key not in instance.env
    for key in ("HOME", "USERPROFILE", "APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "CLAUDE_CONFIG_DIR", "CODEX_HOME", "COPILOT_HOME"):
        assert Path(instance.env[key]).resolve().is_relative_to(instance.home.resolve())


@pytest.mark.parametrize("result", ["failed", "skipped"])
def test_incomplete_candidate_cannot_pass(tmp_path: Path, result: str) -> None:
    instance = make_runner(tmp_path)
    cases = [runner.Case("update-from-0.17.0", False, result, 0, "blocked", "")]
    assert not runner.complete(cases, instance.not_tested)
    assert not runner.complete([runner.Case("x", False, "passed", 0, "", "")], {"codex": "local source refused"})


def test_candidate_rejects_old_or_foreign_runtime(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    app = instance.home / ".legion/app" / instance.candidate_version
    app.mkdir(parents=True)
    identity = {"root": str(instance.checkout / "plugins/legion"), "version": instance.candidate_version}
    with pytest.raises(AssertionError, match="runtime"):
        instance.check_runtime_identity(identity, app)


def test_report_exposes_first_failure_even_when_repeat_is_skipped(tmp_path: Path) -> None:
    cases = [runner.Case("upgrade", False, "failed", 1, "wrong checkout", ""), runner.Case("upgrade", True, "skipped", 0, "blocked", "")]
    runner.write_report(tmp_path, "linux", cases, [])
    assert "| failed |" in (tmp_path / "summary.md").read_text(encoding="utf-8")


def test_candidate_rejects_right_version_with_old_launcher_code(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.launcher("legion").parent.mkdir(parents=True)
    instance.launcher("legion").write_text(f"old generator targeting {instance.candidate_version}", encoding="utf-8")
    instance.run = lambda *_args: json.dumps(f"candidate generator targeting {instance.candidate_version}")
    with pytest.raises(AssertionError, match="old runtime code"):
        instance.check_candidate_launchers(instance.home / ".legion/app" / instance.candidate_version)


def test_candidate_names_the_exact_legacy_launcher_and_still_fails(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    (instance.work / "old-seed/plugins/legion/src").mkdir(parents=True)
    for path in instance.owner_shims():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"released generator text\r\n")
    # The old seed's generator is asked second; it reproduces the file byte for byte.
    instance.run = lambda argv: json.dumps("released generator text\n" if "old-seed" in argv[-1] else "candidate generator text\n")
    with pytest.raises(AssertionError, match=r"exact 0\.17\.0 generator output") as raised:
        instance.check_candidate_launchers(instance.home / ".legion/app" / instance.candidate_version)
    assert "old runtime code" not in str(raised.value)
    assert all(path.name in str(raised.value) for path in instance.owner_shims())


def write_owner_launcher(upgrade: Any, lines: list[str], code: int) -> None:
    # Use a real owner command that prints the lines and exits with the requested code.
    for path in upgrade.owner_shims():
        path.parent.mkdir(parents=True, exist_ok=True)
        if path.suffix == ".cmd":
            body = ["@echo off", f"rem candidate {upgrade.candidate_version}", *(f"echo {line}" for line in lines), f"exit /b {code}"]
            path.write_bytes("\r\n".join(body).encode("utf-8") + b"\r\n")
        else:
            body = ["#!/bin/sh", f"# candidate {upgrade.candidate_version}", *(f"echo '{line}'" for line in lines), f"exit {code}"]
            path.write_text("\n".join(body) + "\n", encoding="utf-8")
            path.chmod(0o755)


@pytest.mark.parametrize("outcome", ["timeout", "missing"])
def test_the_old_update_records_a_timeout_or_missing_command_with_its_output(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, outcome: str) -> None:
    instance = make_runner(tmp_path)
    upgrade = make_runner(tmp_path / "upgrade")
    instance.state["candidate"] = upgrade
    name = upgrade.launcher("legion").name
    if outcome == "timeout":

        def hung(argv: list[str], **kwargs: Any) -> Any:
            # POSIX subprocess hands back the partial output as bytes.
            raise subprocess.TimeoutExpired(argv, kwargs["timeout"], output=b"Update legion for claude\n")

        monkeypatch.setattr(runner.subprocess, "run", hung)
        expected = (f"{name} timed out after 300 seconds\nUpdate legion for claude", "Update legion for claude")
    else:
        expected = (f"{name} could not start: ", "")
    instance.run_old_update()
    assert instance.state["update_error"].startswith(expected[0])
    assert instance.state["update_output"] == expected[1]


def test_a_check_that_times_out_is_one_failed_check(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    instance = make_runner(tmp_path)

    def hung(argv: list[str], **kwargs: Any) -> Any:
        raise subprocess.TimeoutExpired(argv, kwargs["timeout"], output="partial")

    monkeypatch.setattr(runner.subprocess, "run", hung)
    failures = instance.collect([("slow", lambda: instance.run(["slow-tool"])), ("next", lambda: None)])
    assert failures == ["slow: slow-tool timed out after 300 seconds\npartial"]
    checks = json.loads((instance.out / "checks.json").read_text(encoding="utf-8"))
    assert [item["result"] for item in checks] == ["failed", "passed"]


def test_a_stale_launcher_does_not_stop_the_other_candidate_checks(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    upgrade = make_runner(tmp_path / "upgrade")
    upgrade.out.mkdir(parents=True)
    instance.state["candidate"] = upgrade
    app = upgrade.home / ".legion/app" / upgrade.candidate_version
    app.mkdir(parents=True)
    (app / ".legion-app-ready").write_text("", encoding="utf-8")
    called: list[str] = []

    def stale(_app: Path) -> None:
        raise AssertionError("legion.cmd: launcher is the exact 0.17.0 generator output for the candidate")

    def without_uv() -> None:
        called.append("without-uv")
        raise AssertionError("MCP without uv did not start or answer (exit 127): uv is missing")

    # The real old command runs through the production runner: it moved two hosts, then exited 1.
    write_owner_launcher(upgrade, ["Update legion for claude", "Update legion for copilot"], 1)
    instance.state["old_shims"] = {path.name: b"old launcher" for path in upgrade.owner_shims()}
    instance.run_old_update()
    upgrade.check_candidate_bytes = lambda _root: called.append("bytes")
    upgrade.check_candidate_launchers = stale
    identity = {"root": str(app), "version": upgrade.candidate_version, "cli": str(app / "cli.py"), "server": str(app / "server.py")}
    hook_runs: list[list[str]] = []

    def run(argv: list[str], **_kwargs: Any) -> str:
        if argv[1:3] == ["-I", "-c"] and "PLUGIN_ROOT" in argv[3]:
            return json.dumps(identity)
        hook_runs.append(argv)
        return "you are a legion member"

    upgrade.run = run
    upgrade.listing = lambda tool, _folder: called.append(f"listing-{tool}") or True
    upgrade.candidate_plugin = lambda _tool: app
    upgrade.legion = lambda *_args, **_kwargs: called.append("owner-version") or f"legion {upgrade.candidate_version}"
    upgrade.prove_mcp = lambda: called.append("mcp")
    upgrade.check_client_command = lambda: called.append("client-command")
    upgrade.prove_mcp_without_uv = without_uv
    upgrade.prove_clients = lambda: called.append("clients") or ["copilot"]
    upgrade.home_snapshot = lambda **_kwargs: {"snapshot": "taken"}
    # Codex stayed on the old version; that too is only one observation among the others.
    upgrade.version = lambda tool, _folder: "0.17.0" if tool == "codex" else upgrade.candidate_version
    assert instance.state["update_output"] == "Update legion for claude\nUpdate legion for copilot"
    with pytest.raises(AssertionError) as raised:
        instance.verify_candidate()
    message = str(raised.value)
    assert message.splitlines()[0] == f"update command: {upgrade.launcher('legion').name} exited 1"
    assert "codex updated: codex: installed version is 0.17.0" in message
    assert "owner launchers: legion.cmd: launcher is the exact 0.17.0" in message
    assert "owner MCP without uv: MCP without uv did not start or answer (exit 127)" in message
    assert {"owner-version", "mcp", "client-command", "without-uv", "clients", "listing-claude", "listing-codex", "listing-copilot"} <= set(called)
    assert instance.state["client_missing"] == ["copilot"]
    assert instance.state["candidate_snapshot"] == {"snapshot": "taken"}
    # The hook observation writes no bytecode into the host plugin caches the repeat compares.
    assert len(hook_runs) == len(runner.TOOLS)
    assert all(argv[1:3] == ["-I", "-B"] for argv in hook_runs)
    checks = json.loads((upgrade.out / "checks.json").read_text(encoding="utf-8"))
    assert [item["check"] for item in checks if item["result"] == "failed"] == ["update command", "codex updated", "owner launchers", "owner MCP without uv"]


def test_the_nested_candidate_runner_expects_the_staged_version(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.prepare_candidate()
    upgrade = instance.state["candidate"]
    staged = json.loads((upgrade.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
    assert staged == instance.candidate_version
    assert upgrade.candidate_version == instance.candidate_version
    app = upgrade.home / ".legion/app" / staged
    upgrade.check_runtime_identity({"root": str(app), "version": staged, "cli": str(app / "cli.py"), "server": str(app / "server.py")}, app)


def test_the_repeat_cleans_up_an_installed_candidate_after_a_failed_first_case(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    upgrade = make_runner(tmp_path / "upgrade")
    events: list[str] = []

    def first(repeat: bool) -> None:
        if repeat:
            events.append("repeat and purge")
            return
        instance.state["candidate"] = upgrade
        upgrade.launcher("legion").parent.mkdir(parents=True)
        upgrade.launcher("legion").write_text("owner command", encoding="utf-8")
        raise AssertionError("owner launchers: legacy")

    instance.steps = lambda: [("update-from-0.17.0", first)]
    assert [case.result for case in instance.execute()] == ["failed", "passed"]
    assert events == ["repeat and purge"]


def test_an_installed_candidate_without_owner_commands_still_reports_repeat_and_purge(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    upgrade = make_runner(tmp_path / "upgrade")

    def update_removed_the_launchers() -> None:
        instance.state["candidate"] = upgrade
        (upgrade.home / ".legion/app" / upgrade.candidate_version).mkdir(parents=True)
        raise AssertionError("update removed the owner commands")

    instance.prepare_candidate = update_removed_the_launchers
    instance.steps = lambda: [("update-from-0.17.0", instance.update_from_0_17_0)]
    cases = instance.execute()
    assert [case.result for case in cases] == ["failed", "failed"]
    # The real runner tried the missing owner command for both, and each outcome is written down.
    name = upgrade.launcher("legion").name
    checks = json.loads((upgrade.out / "repeat-checks.json").read_text(encoding="utf-8"))
    assert [(item["check"], item["result"]) for item in checks] == [("repeat update", "failed"), ("purge", "failed")]
    assert all(item["message"].startswith(f"{name} could not start") for item in checks)


def test_cancellation_is_not_turned_into_a_failed_check(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    upgrade = make_runner(tmp_path / "upgrade")
    upgrade.log.append("old install started")

    def cancelled() -> None:
        raise KeyboardInterrupt

    instance.state["candidate"] = upgrade
    instance.prepare_candidate = lambda: None
    instance.install_old = cancelled
    with pytest.raises(KeyboardInterrupt):
        instance.update_from_0_17_0(False)
    assert instance.log == ["old install started"]


def test_purge_runs_and_is_reported_even_when_the_repeat_update_fails(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    upgrade = make_runner(tmp_path / "upgrade")
    upgrade.out.mkdir(parents=True)
    instance.state.update({"candidate": upgrade, "candidate_snapshot": {"launcher": "legacy"}})
    calls: list[tuple[str, ...]] = []
    upgrade.legion = lambda *args, **_kwargs: calls.append(args) or "already up to date\n" + "\n".join(f"Update legion for {tool}" for tool in runner.TOOLS)
    upgrade.version = lambda *_args: instance.candidate_version
    upgrade.home_snapshot = lambda **_kwargs: {"launcher": "current"}
    upgrade.check_uninstalled = lambda _tool, _folder: None
    with pytest.raises(AssertionError, match="repeat update: the home changed on the repeat run"):
        instance.finish_candidate()
    assert calls[-1] == ("uninstall", "--purge", "--yes")
    checks = json.loads((upgrade.out / "repeat-checks.json").read_text(encoding="utf-8"))
    assert [(item["check"], item["result"]) for item in checks] == [("repeat update", "failed"), ("purge", "passed")]


FAKE_MCP_SERVER = """
import json, shutil, sys
if shutil.which("uv"):
    sys.exit(9)
for line in sys.stdin:
    message = json.loads(line)
    if "id" not in message:
        continue
    result = {"tools": [{"name": "status"}, {"name": "limits"}]} if message["method"] == "tools/list" else {"structuredContent": {}}
    print(json.dumps({"jsonrpc": "2.0", "id": message["id"], "result": result}), flush=True)
"""


@pytest.mark.parametrize("starts", [False, True])
def test_mcp_without_uv_reports_what_the_installed_launcher_does(tmp_path: Path, starts: bool) -> None:
    instance = make_runner(tmp_path)
    instance.out.mkdir()
    uv_folder = tmp_path / "uv-folder"
    uv_folder.mkdir()
    (uv_folder / ("uv.exe" if os.name == "nt" else "uv")).write_bytes(b"")
    instance.env["PATH"] = os.pathsep.join([str(uv_folder), instance.env["PATH"]])
    server = tmp_path / "server.py"
    server.write_text(FAKE_MCP_SERVER, encoding="utf-8")
    launcher = instance.launcher("legion")
    launcher.parent.mkdir(parents=True)
    if os.name == "nt":
        body = f'@"{sys.executable}" -I "{server}"' if starts else "@>&2 echo uv is missing& exit /b 127"
        launcher.write_text(body + "\r\n", encoding="ascii")
    else:
        body = f'exec "{sys.executable}" -I "{server}"' if starts else "echo 'uv is missing' >&2; exit 127"
        launcher.write_text(f"#!/bin/sh\n{body}\n", encoding="ascii")
        launcher.chmod(0o755)
    if starts:
        instance.prove_mcp_without_uv()
        return
    with pytest.raises(AssertionError, match=r"MCP without uv did not start or answer \(exit 127\): uv is missing"):
        instance.prove_mcp_without_uv()


def test_client_probe_attempts_every_host_and_never_calls_listing_launch_proof(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.out.mkdir()
    calls = []

    def probe(tool: str) -> dict[str, Any]:
        calls.append(tool)
        if tool == "codex":
            raise RuntimeError("discovery failed")
        return {"host": tool, "discovered": True, "launched": tool == "claude", "status_called": False}

    instance.probe_client = probe
    assert instance.prove_clients() == ["codex", "copilot"]
    assert calls == list(runner.TOOLS)
    evidence = json.loads((instance.out / "clients.json").read_text(encoding="utf-8"))
    assert not evidence[1]["launched"]
    assert not evidence[2]["launched"]


def test_copilot_listing_is_only_discovery_evidence(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    instance = make_runner(tmp_path)
    instance.cli = lambda *_args: '{"mcpServers":{"legion":{"command":"legion","args":["mcp"]}}}'
    instance.command = lambda name: name

    class BlockedClient:
        def __init__(self, *_args: Any) -> None:
            pass

        def rpc(self, *_args: Any) -> dict[str, Any]:
            raise AssertionError("Authentication required")

        def close(self) -> None:
            pass

    monkeypatch.setattr(runner, "JsonProcess", BlockedClient)
    evidence = instance.probe_client("copilot")
    assert evidence["discovered"]
    assert not evidence["launched"]
    assert not evidence["status_called"]


@pytest.mark.parametrize("session_id", ["current", "another"])
def test_copilot_requires_session_tied_mcp_health(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, session_id: str) -> None:
    instance = make_runner(tmp_path)
    instance.cli = lambda *_args: '{"mcpServers":{"legion":{"command":"legion","enabled":true}}}'
    instance.command = lambda name: name

    class Client:
        def __init__(self, *_args: Any) -> None:
            self.pending = [{"method": "session/update", "params": {"sessionId": "current", "update": {"sessionUpdate": "available_commands_update", "availableCommands": [{"name": "mcp"}]}}}]

        def rpc(self, method: str, params: dict[str, Any], _request: int) -> dict[str, Any]:
            if method == "session/new":
                return {"sessionId": "current"}
            if method == "session/prompt":
                assert params == {"sessionId": "current", "prompt": [{"type": "text", "text": "/mcp list"}]}
                self.pending.append(
                    {"method": "session/update", "params": {"sessionId": session_id, "update": {"sessionUpdate": "agent_message_chunk", "content": {"type": "text", "text": "legion: connected"}}}}
                )
                return {"stopReason": "end_turn"}
            return {}

        def receive(self, key: str, value: str) -> dict[str, Any]:
            assert (key, value) == ("method", "session/update")
            return self.pending.pop(0)

        def close(self) -> None:
            pass

    monkeypatch.setattr(runner, "JsonProcess", Client)
    evidence = instance.probe_client("copilot")
    assert evidence["launched"] is (session_id == "current")


def test_copilot_candidate_root_comes_from_enabled_host_setting(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    folder = instance.folder("copilot")
    folder.mkdir(parents=True)
    live = instance.work / "host-reader"
    (live / "plugins/legion").mkdir(parents=True)
    (live / ".claude-plugin").mkdir()
    (live / ".claude-plugin/marketplace.json").write_text('{"plugins":[{"name":"legion","source":"./plugins/legion"}]}', encoding="utf-8")
    (folder / "settings.json").write_text(
        json.dumps({"enabledPlugins": {"legion@ps-legion-marketplace": True}, "extraKnownMarketplaces": {"ps-legion-marketplace": {"source": {"source": "directory", "path": str(live)}}}}),
        encoding="utf-8",
    )
    assert instance.candidate_plugin("copilot") == live / "plugins/legion"
    assert instance.candidate_plugin("copilot") != instance.checkout / "plugins/legion"


def test_claude_discovery_requires_exact_identity_and_ready_state(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.cli = lambda *_args: "other-legion: legion mcp - √ Connected\nplugin:legion:legion: legion mcp - × Failed to connect"
    evidence = instance.probe_client("claude")
    assert evidence["discovered"]
    assert not evidence["launched"]
    instance.cli = lambda *_args: "Checking MCP server health…\n\nplugin:legion:legion: legion mcp - √ Connected"
    assert instance.probe_client("claude")["launched"]
    # Hosted Claude on 9f6f3fa printed the heavy check mark (U+2714) on all three systems.
    instance.cli = lambda *_args: "Checking MCP server health…\n\nplugin:legion:legion: legion mcp - ✔ Connected"
    assert instance.probe_client("claude")["launched"]


def test_copilot_health_rejects_not_yet_connected(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    assert not instance.copilot_health("legion not yet connected")


def test_codex_inventory_requires_exact_connected_legion() -> None:
    servers = [{"name": "other-legion", "runtimeStatus": "connected", "tools": {"status": {}}}, {"name": "legion", "runtimeStatus": "failed", "tools": {"status": {}}}]
    assert runner.codex_legion_server(servers) is None
    servers[1]["runtimeStatus"] = "connected"
    assert runner.codex_legion_server(servers) == servers[1]


def test_candidate_client_failure_does_not_block_repeat_or_install(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.steps = lambda: [("update-from-0.17.0", lambda _repeat: (_ for _ in ()).throw(AssertionError("first command failed"))), ("install-legion", lambda _repeat: "installed")]
    cases = instance.execute()
    assert [case.result for case in cases] == ["failed", "skipped", "passed", "passed"]


def test_candidate_evidence_is_reported_after_independent_purge_failure(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.state["client_missing"] = ["copilot"]
    instance.steps = lambda: [("purge", lambda _repeat: (_ for _ in ()).throw(AssertionError("purge failed"))), ("candidate-client-evidence", instance.candidate_client_evidence)]
    assert [case.result for case in instance.execute()] == ["failed", "skipped", "failed", "failed"]


def test_client_gap_is_reported_after_independent_candidate_checks(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.out.mkdir()
    instance.probe_client = lambda tool: {"host": tool, "discovered": True, "launched": tool != "copilot", "status_called": False, "limitation": "Authentication required" if tool == "copilot" else ""}
    assert instance.prove_clients() == ["copilot"]
    assert instance.steps()[-1][0] == "candidate-client-evidence"
    with pytest.raises(AssertionError, match="copilot"):
        instance.candidate_client_evidence(False)


@pytest.mark.parametrize("relative", ["src/legion/mcp/server.py", "hooks/session_start.py"])
def test_same_version_wrong_hook_or_server_bytes_are_rejected(tmp_path: Path, relative: str) -> None:
    instance = make_runner(tmp_path)
    root = instance.work / "foreign"
    source = instance.checkout / "plugins/legion"
    shutil.copytree(source, root)
    (root / relative).write_text("foreign source", encoding="utf-8")
    with pytest.raises(AssertionError, match="checkout mismatch"):
        instance.check_candidate_bytes(root)


def test_candidate_bytes_use_independent_staging(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    staged = instance.work / "candidate/plugins/legion"
    shutil.copytree(instance.checkout / "plugins/legion", staged)
    reader = instance.work / "reader"
    shutil.copytree(staged, reader)
    (reader / "hooks/session_start.py").write_text("wrong reader", encoding="utf-8")
    instance.state["candidate_source"] = staged
    instance.checkout = reader
    with pytest.raises(AssertionError, match="checkout mismatch"):
        instance.check_candidate_bytes(reader)


def test_supported_git_source_rewrites_to_disposable_origin_and_fetches(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    seed = instance.work / "seed"
    seed.mkdir()
    instance.run(["git", "-C", str(seed), "init", "--quiet"])
    instance.run(["git", "-C", str(seed), "config", "user.name", "fixture"])
    instance.run(["git", "-C", str(seed), "config", "user.email", "fixture@example.invalid"])
    (seed / "sentinel").write_text("old", encoding="utf-8")
    instance.run(["git", "-C", str(seed), "add", "sentinel"])
    instance.run(["git", "-C", str(seed), "commit", "--quiet", "-m", "old"])
    origin = instance.work / "origin.git"
    instance.run(["git", "init", "--bare", "--quiet", str(origin)])
    instance.run(["git", "--git-dir", str(origin), "fetch", str(seed), "HEAD:refs/heads/stable"])
    instance.configure_disposable_origin(origin)
    result = instance.run(["git", "ls-remote", "https://github.com/BlackGad/ps-legion-marketplace.git", "refs/heads/stable"])
    assert result.endswith("refs/heads/stable")
    reader = instance.work / "reader"
    instance.run(["git", "clone", "--quiet", "--branch", "stable", "https://github.com/BlackGad/ps-legion-marketplace.git", str(reader)])
    assert (reader / "sentinel").read_text(encoding="utf-8") == "old"
    (seed / "sentinel").write_text("new", encoding="utf-8")
    instance.run(["git", "-C", str(seed), "commit", "--quiet", "-am", "new"])
    instance.run(["git", "--git-dir", str(origin), "fetch", str(seed), "+HEAD:refs/heads/stable"])
    instance.run(["git", "-C", str(reader), "fetch", "origin", "stable"])
    assert instance.run(["git", "-C", str(reader), "show", "FETCH_HEAD:sentinel"]) == "new"


def test_client_readiness_notifications_are_not_lost_while_awaiting_rpc() -> None:
    connection = runner.JsonProcess.__new__(runner.JsonProcess)
    connection.messages = queue.Queue()
    connection.pending = []
    notification = {"method": "mcpServer/startupStatus/updated", "params": {"name": "legion", "status": "ready"}}
    connection.messages.put(notification)
    connection.messages.put({"id": 2, "result": {}})
    assert connection.receive("id", 2) == {"id": 2, "result": {}}
    connection.mcp_ready("legion")
    assert not connection.pending


@pytest.mark.parametrize("repeat", [False, True])
def test_candidate_fence_is_checked_even_after_a_failed_action(tmp_path: Path, repeat: bool) -> None:
    instance = make_runner(tmp_path)
    outside = instance.work / "fake-real"
    outside.mkdir()
    sentinel = outside / "keep.txt"
    sentinel.write_text("owner sentinel", encoding="utf-8")
    instance.state.update({"outside": outside, "outside_snapshot": runner.snapshot(outside)})

    def damage() -> None:
        sentinel.write_text("changed", encoding="utf-8")
        raise RuntimeError("action failed")

    instance.prepare_candidate = lambda: None
    instance.install_old = damage
    instance.finish_candidate = damage
    with pytest.raises(AssertionError, match=r"changed: keep\.txt") as raised:
        instance.update_from_0_17_0(repeat)
    assert str(raised.value).startswith("action failed\noutside the disposable home:")


def test_candidate_fence_read_error_preserves_the_failed_action(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    instance = make_runner(tmp_path)
    outside = instance.work / "fake-real"
    outside.mkdir()
    sentinel = outside / "keep.txt"
    sentinel.write_text("owner sentinel", encoding="utf-8")
    instance.state.update({"outside": outside, "outside_snapshot": runner.snapshot(outside)})
    read_bytes = Path.read_bytes

    def read_with_denied_sentinel(path: Path) -> bytes:
        if path == sentinel:
            raise PermissionError("cannot read keep.txt")
        return read_bytes(path)

    def failed_update() -> None:
        monkeypatch.setattr(Path, "read_bytes", read_with_denied_sentinel)
        raise RuntimeError("action failed")

    instance.prepare_candidate = lambda: None
    instance.install_old = failed_update
    with pytest.raises(AssertionError, match=r"^action failed\noutside the disposable home: cannot read keep\.txt$"):
        instance.update_from_0_17_0(repeat=False)


def test_upgrade_advances_origin_without_changing_reader(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    candidate = instance.work / "candidate"
    candidate.mkdir()
    (candidate / "new.py").write_text("candidate source", encoding="utf-8")
    upgrade = runner.Runner(instance.checkout, instance.work / "upgrade/home", instance.out / "candidate", False)
    origin = upgrade.work / "origin.git"
    seed = upgrade.work / "seed"
    seed.mkdir()
    instance.run(["git", "-C", str(seed), "init", "--quiet"])
    instance.run(["git", "-C", str(seed), "config", "core.longpaths", "true"])
    instance.run(["git", "-C", str(seed), "config", "user.name", "fixture"])
    instance.run(["git", "-C", str(seed), "config", "user.email", "fixture@example.invalid"])
    (seed / "old.py").write_text("old source", encoding="utf-8")
    instance.run(["git", "-C", str(seed), "add", "."])
    instance.run(["git", "-C", str(seed), "commit", "--quiet", "-m", "old"])
    instance.run(["git", "init", "--bare", "--quiet", str(origin)])
    instance.run(["git", "--git-dir", str(origin), "config", "core.longpaths", "true"])
    instance.run(["git", "--git-dir", str(origin), "fetch", "--quiet", str(seed), "HEAD:refs/heads/stable"])
    reader = upgrade.work / "old-source"
    instance.run(["git", "clone", "--quiet", "--branch", "stable", str(origin), str(reader)])
    upgrade.checkout = reader
    upgrade.configure_disposable_origin(origin)
    instance.state["origin"] = origin
    upgrade.launcher("legion").parent.mkdir(parents=True)
    for path in upgrade.owner_shims():
        path.write_text("old launcher", encoding="utf-8")
    instance.state["candidate"] = upgrade
    instance.state["old_shims"] = {path.name: path.read_bytes() for path in upgrade.owner_shims()}
    upgrade.version = lambda *_args: instance.candidate_version
    calls = []

    def owner(*args: str, **kwargs: bool) -> str:
        calls.append((args, kwargs))
        assert (reader / "old.py").read_text(encoding="utf-8") == "old source"
        assert not (reader / "new.py").exists()
        for path in upgrade.owner_shims():
            path.write_text("candidate launcher " + instance.candidate_version, encoding="utf-8")
        return "\n".join(f"Update legion for {tool}" for tool in runner.TOOLS)

    upgrade.legion = owner
    instance.upgrade_candidate()
    assert calls == [(("update", "--yes"), {"owner": True})]
    assert instance.run(["git", "--git-dir", str(origin), "show", "stable:new.py"]) == "candidate source"


def test_old_install_runs_from_seed_checkout(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    candidate = instance.checkout
    upgrade = runner.Runner(candidate, instance.work / "upgrade/home", instance.out / "candidate", False)
    instance.state["candidate"] = upgrade
    seed = upgrade.work / "old-seed"
    app = upgrade.home / ".legion/app/0.17.0"
    projects = []

    def fixture_git(argv: list[str], **_kwargs: Any) -> str:
        if argv[:2] == ["git", "clone"]:
            (seed / "plugins/legion").mkdir(parents=True)
        return "old-revision\trefs/heads/stable" if "ls-remote" in argv else ""

    def fixture_cli(argv: list[str], **_kwargs: Any) -> str:
        if "--project" in argv:
            projects.append(Path(argv[argv.index("--project") + 1]))
            (app / ".legion-app-ready").parent.mkdir(parents=True, exist_ok=True)
            (app / ".legion-app-ready").touch()
            return "installed"
        if "ls-remote" in argv:
            return "old-revision\trefs/heads/stable"
        if "-I" in argv:
            return json.dumps({"root": str(app)})
        return "Install legion"

    instance.run = fixture_git
    upgrade.run = fixture_cli
    upgrade.command = lambda _name: "uv"
    upgrade.listing = lambda *_args: True
    upgrade.version = lambda *_args: "0.17.0"
    upgrade.owner_shims = list
    instance.install_old()

    assert projects == [seed / "plugins/legion"] * len(runner.TOOLS)
    assert upgrade.checkout == candidate


def test_client_command_rejects_another_installed_home(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    outside = instance.work / "another-home/bin"
    outside.mkdir(parents=True)
    command = outside / instance.launcher("legion").name
    command.write_text("@echo off\n" if os.name == "nt" else "#!/bin/sh\n", encoding="utf-8")
    command.chmod(0o755)
    instance.env["PATH"] = str(outside)
    with pytest.raises(AssertionError, match="outside the candidate home"):
        instance.check_client_command()
    own = instance.launcher("legion")
    own.parent.mkdir(parents=True)
    shutil.copy2(command, own)
    instance.env["PATH"] = os.pathsep.join((str(own.parent), str(outside)))
    instance.check_client_command()


@pytest.mark.parametrize("missing_host", [False, True])
def test_main_fails_for_one_skipped_case_or_one_untested_host(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, missing_host: bool) -> None:
    cases = [runner.Case("update-from-0.17.0", False, "passed" if missing_host else "skipped", 0, "", "")]
    fake = SimpleNamespace(execute=lambda: cases, not_tested={"codex": "local source refused"} if missing_host else {}, versions={})
    monkeypatch.setenv("CI", "true")
    monkeypatch.setattr(sys, "argv", [str(RUNNER), "--out", str(tmp_path / "out"), "--home-root", str(tmp_path / "home")])
    monkeypatch.setattr(runner, "Runner", lambda *_args: fake)
    monkeypatch.setattr(runner.shutil, "which", lambda _name: None)
    monkeypatch.setattr(runner, "restore_user_path", nullcontext)
    monkeypatch.setattr(runner, "write_report", lambda *_args: None)
    assert runner.main() == 1


def test_repeat_and_purge_use_candidate_owner_command(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    upgrade = runner.Runner(instance.checkout, instance.work / "upgrade/home", instance.out / "candidate", False)
    outside = instance.work / "fake-real"
    outside.mkdir()
    instance.state.update({"candidate": upgrade, "candidate_snapshot": {}, "outside": outside, "outside_snapshot": {}})
    calls = []
    checked = []
    upgrade.legion = lambda *args, **kwargs: calls.append((args, kwargs)) or "already up to date\n" + "\n".join(f"Update legion for {tool}" for tool in runner.TOOLS)
    upgrade.version = lambda *_args: instance.candidate_version
    upgrade.home_snapshot = lambda **_kwargs: {}
    upgrade.check_uninstalled = lambda tool, _folder: checked.append(tool)
    instance.finish_candidate()
    assert calls == [(("update", "--yes"), {"owner": True}), (("uninstall", "--purge", "--yes"), {"owner": True})]
    assert checked == list(runner.TOOLS)


def test_update_first_reinstalls_a_tool_then_repeat_is_stable(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    expected = json.loads((instance.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
    calls = []
    owner_calls = []
    instance.active = lambda: ["codex"]
    instance.targets["codex"] = (str(instance.checkout), "release")
    instance.cli = lambda tool, args, _folder=None: calls.append((tool, tuple(args))) or ""
    instance.listing = lambda *_args, **_kwargs: False

    def legion(*args: str, **kwargs: bool) -> str:
        calls.append((args, kwargs))
        owner_calls.append(args)
        if len(owner_calls) == 1:
            return f"Update legion for codex\nlegion not installed -> {expected}"
        return f"Update legion for codex\nskip: legion {expected} (already up to date)"

    instance.legion = legion
    instance.version = lambda _tool, _folder: expected
    instance.installed_source_matches = lambda _tool, _folder: True
    instance.home_snapshot = dict
    instance.update(False)
    instance.update(True)
    assert calls[:2] == [("codex", tuple(instance.catalog["codex"]["plugin"][name])) for name in ("uninstall", "marketplaceRemove")]
    assert calls[2:] == [(("install", "--update", "--source", str(instance.checkout), "--yes"), {"owner": True}), (("update", "--yes"), {"owner": True})]


def test_update_rejects_a_release_instead_of_the_checkout(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    expected = json.loads((instance.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
    instance.active = lambda: ["codex"]
    instance.targets["codex"] = (str(instance.checkout), "release")
    instance.cli = lambda *_args, **_kwargs: ""
    instance.listing = lambda *_args, **_kwargs: False
    instance.legion = lambda *_args, **_kwargs: f"Update legion for codex\nlegion not installed -> {expected}"
    instance.version = lambda _tool, _folder: expected
    instance.installed_source_matches = lambda _tool, _folder: False
    with pytest.raises(AssertionError, match="checkout"):
        instance.update(False)


def test_published_source_repeat_uses_documented_owner_command(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    expected = json.loads((instance.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
    instance.active = lambda: ["claude"]
    instance.targets["claude"] = (runner.MARKETPLACE, "main")
    instance.cli = lambda *_args, **_kwargs: ""
    instance.listing = lambda *_args, **_kwargs: False
    calls = []
    instance.legion = lambda *args, **kwargs: (
        calls.append((args, kwargs))
        or (f"Update legion for claude\nlegion not installed -> {expected}" if len(calls) == 1 else f"Update legion for claude\nskip: legion {expected} (already up to date)")
    )
    instance.version = lambda _tool, _folder: expected
    instance.installed_source_matches = lambda _tool, _folder: True
    instance.home_snapshot = dict
    instance.update(False)
    instance.update(True)
    assert calls == [(("install", "--update", "--source", runner.MARKETPLACE, "--ref", "main", "--yes"), {"owner": True}), (("update", "--yes"), {"owner": True})]


def test_installed_source_check_rejects_different_plugin_bytes(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    root = instance.folder("codex") / instance.catalog["codex"]["plugin"]["installedRoot"] / "1.2.3"
    source = root / "src/legion/services/installation/_installed_runtime.py"
    source.parent.mkdir(parents=True)
    (root / "plugin.json").write_text('{"name":"legion","version":"1.2.3"}', encoding="utf-8")
    source.write_bytes((instance.checkout / "plugins/legion/src/legion/services/installation/_installed_runtime.py").read_bytes())
    for metadata in (".codex-plugin", ".claude-plugin"):
        sibling = root / metadata
        sibling.mkdir()
        (sibling / "plugin.json").write_text('{"name":"legion"}', encoding="utf-8")
    assert instance.installed_source_matches("codex", instance.folder("codex"))
    source.write_text("release copy", encoding="utf-8")
    assert not instance.installed_source_matches("codex", instance.folder("codex"))


def test_first_purge_uses_owner_command_repeat_uses_bootstrap(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.targets_for_uninstall = lambda **_kwargs: []
    instance.legion = lambda *args, **kwargs: "done: purge" if args == ("uninstall", "--purge", "--yes") and kwargs == {"owner": True} else pytest.fail("wrong first purge")
    instance.run = lambda argv, **_kwargs: "skip: purge (already done)" if "--purge" in argv or "-Purge" in argv else pytest.fail("wrong repeat purge")
    instance.profile_count = lambda: 0
    instance.cli = lambda *_args, **_kwargs: ""
    instance.purge(False)
    instance.purge(True)


def test_no_ci_writes_nothing(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("CI", raising=False)
    monkeypatch.setattr(sys, "argv", [str(RUNNER), "--out", str(tmp_path / "out"), "--home-root", str(tmp_path / "home")])
    with pytest.raises(SystemExit):
        runner.main()
    assert not (tmp_path / "out").exists()


@pytest.mark.parametrize(("tool", "runtime"), [("codex", "tmp/arg0-linux/codex-arg0-test/file"), ("copilot", "logs/process-123-456.log")])
def test_snapshot_excludes_cli_runtime_files(tmp_path: Path, tool: str, runtime: str) -> None:
    instance = make_runner(tmp_path)
    path = instance.folder(tool) / runtime
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("one", encoding="utf-8")
    first = instance.home_snapshot()
    path.write_text("two", encoding="utf-8")
    assert instance.home_snapshot() == first


@pytest.mark.parametrize(("tool", "runtime"), [("codex", "tmp/arg0-linux/codex-arg0-test/apply_patch"), ("copilot", "logs/process-123-456.log")])
def test_snapshot_excludes_account_runtime_but_detects_account_changes(tmp_path: Path, tool: str, runtime: str) -> None:
    instance = make_runner(tmp_path)
    account = instance.home / ".legion/agents" / f"{tool}1"
    settings = instance.home / ".legion/configuration/personalisation.json"
    settings.parent.mkdir(parents=True)
    settings.write_text(json.dumps({"agents": [{"id": f"{tool}1", "tool": tool, "configDir": str(account)}]}), encoding="utf-8")
    runtime_path = account / runtime
    stable = account / "config.toml"
    runtime_path.parent.mkdir(parents=True)
    runtime_path.write_text("one", encoding="utf-8")
    stable.write_text("one", encoding="utf-8")
    first = instance.home_snapshot()
    runtime_path.write_text("two", encoding="utf-8")
    assert instance.home_snapshot() == first
    stable.write_text("two", encoding="utf-8")
    with pytest.raises(AssertionError, match=rf"changed: .legion/agents/{tool}1/config.toml"):
        runner.unchanged(first, instance.home_snapshot())


def test_first_uninstall_runs_installed_owner_command(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    for name in ("configuration", "agents"):
        (instance.home / ".legion" / name).mkdir(parents=True)
    seen: list[bool] = []
    instance.targets_for_uninstall = list
    instance.active = list
    instance.check_launchers = lambda: None
    instance.legion = lambda *_args, owner=False: seen.append(owner) or "removed"
    instance.uninstall(False)
    assert seen == [True]


@pytest.mark.parametrize("text", ["codex exited 1\nlocal directory source is not supported", "claude exited 1\nlocal directory source is not supported"])
def test_local_refusal_only_skips_its_cli(tmp_path: Path, text: str) -> None:
    instance = make_runner(tmp_path)

    def install(tool: str) -> str:
        if tool == "codex":
            raise RuntimeError(text)
        return "installed"

    instance.install_legion = install
    instance.listing = lambda _tool, folder, *_args, **_kwargs: not str(folder).startswith(str(instance.work / "control-"))
    instance.version = lambda *_args: json.loads((instance.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
    instance.home_snapshot = dict
    if text.startswith("codex"):
        instance.install_first()
        assert list(instance.not_tested) == ["codex"]
    else:
        with pytest.raises(AssertionError, match=r"codex:.*claude exited"):
            instance.install_first()
        assert not instance.not_tested


@pytest.mark.parametrize("moved", [False, True])
def test_source_fallback_rejects_other_or_moving_main(tmp_path: Path, moved: bool) -> None:
    instance = make_runner(tmp_path)
    instance.fallback = True

    def install(tool: str) -> str:
        if tool == "codex" and tool not in instance.targets:
            raise RuntimeError("codex exited 1\nlocal directory source is not supported")
        return "installed"

    instance.install_legion = install
    hashes = iter(["a", "a" if moved else "b", "b"])
    instance.run = lambda _argv, **_kwargs: next(hashes)
    with pytest.raises(AssertionError, match=r"main differs|main moved"):
        instance.install_first()


@pytest.mark.parametrize("leftover", ["setting", "path", "marketplace"])
def test_purge_rejects_each_leftover(tmp_path: Path, leftover: str) -> None:
    instance = make_runner(tmp_path)
    instance.home_snapshot = dict
    instance.legion = lambda *_args, **_kwargs: "skip: purge (already done)"
    instance.run = lambda *_args, **_kwargs: "skip: purge (already done)"
    instance.profile_count = lambda: 0
    instance.check_uninstalled = lambda *_args: None
    instance.listing = lambda _tool, _folder, kind="plugin", **_kwargs: leftover == "marketplace" and kind == "marketplace"
    instance.cli = lambda *_args: ""
    folder = instance.folder("copilot")
    folder.mkdir(parents=True)
    if leftover == "setting":
        setting = instance.catalog["copilot"]["plugin"]["purge"]["settings"][0]["path"]
        target = folder / setting
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text("Legion", encoding="utf-8")
    elif leftover == "path":
        (folder / instance.catalog["copilot"]["plugin"]["purge"]["paths"][0]).mkdir(parents=True)
    instance.state["purge_targets"] = [("copilot", folder)]
    with pytest.raises(AssertionError, match={"setting": "legion remains", "path": "purge path remains", "marketplace": "marketplace remains"}[leftover]):
        instance.purge(True)


def test_repeat_purge_uses_bootstrap_after_owned_uv_was_removed(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.state["purge_targets"] = []
    instance.state["purge_snapshot"] = instance.home_snapshot()
    instance.profile_count = lambda: 0
    instance.cli = lambda *_args: ""
    calls: list[list[str]] = []

    def run(argv: list[str], **_kwargs: Any) -> str:
        calls.append(argv)
        return "skip: purge (already done)"

    instance.run = run
    instance.legion = lambda *_args, **_kwargs: pytest.fail("repeat purge used missing uv")
    instance.purge(True)
    assert len(calls) == 1
    bootstrap = calls[0]
    assert bootstrap[-2:] == (["-Purge", "-Yes"] if os.name == "nt" else ["--purge", "--yes"])
    assert Path(bootstrap[0]).name in ("powershell.exe", "sh")


@pytest.mark.skipif(os.name != "nt", reason="Windows cannot delete a running uv.exe")
def test_first_windows_purge_uses_owner_command(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    instance.targets_for_uninstall = lambda **_kwargs: []
    instance.profile_count = lambda: 0
    instance.cli = lambda *_args: ""
    calls: list[list[str]] = []
    instance.run = lambda *_args, **_kwargs: pytest.fail("first purge ran bootstrap")
    instance.legion = lambda *args, **kwargs: calls.append([*args, str(kwargs)]) or "done: purge"
    instance.purge(False)
    assert len(calls) == 1
    assert calls[0] == ["uninstall", "--purge", "--yes", "{'owner': True}"]


def test_version_orders_semantic_parts(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    root = instance.folder("claude") / instance.catalog["claude"]["plugin"]["installedRoot"]
    for name in ("0.9.0", "0.10.0"):
        path = root / name / "plugin.json"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps({"name": "legion", "version": name}), encoding="utf-8")
    assert instance.version("claude", instance.folder("claude")) == "0.10.0"


@pytest.mark.parametrize("kind", ["disabled", "remote"])
def test_copilot_version_requires_enabled_local_marketplace(tmp_path: Path, kind: str) -> None:
    instance = make_runner(tmp_path)
    folder = instance.folder("copilot")
    checkout = instance.checkout
    folder.mkdir(parents=True)
    (folder / "settings.json").write_text(
        json.dumps(
            {
                "enabledPlugins": {"legion@ps-legion-marketplace": kind != "disabled"},
                "extraKnownMarketplaces": {"ps-legion-marketplace": {"source": {"source": "remote" if kind == "remote" else "directory", "path": str(checkout)}}},
            }
        ),
        encoding="utf-8",
    )
    assert instance.version("copilot", folder) is None


def test_copilot_published_fallback_reads_installed_manifest(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    folder = instance.folder("copilot")
    folder.mkdir(parents=True)
    (folder / "settings.json").write_text(
        json.dumps(
            {"enabledPlugins": {"legion@ps-legion-marketplace": True}, "extraKnownMarketplaces": {"ps-legion-marketplace": {"source": {"source": "remote", "path": "BlackGad/ps-legion-marketplace"}}}}
        ),
        encoding="utf-8",
    )
    manifest = folder / "installed-plugins/legion-marketplace/legion/plugin.json"
    manifest.parent.mkdir(parents=True)
    manifest.write_text('{"name":"legion","version":"0.16.0"}', encoding="utf-8")
    assert instance.version("copilot", folder) == "0.16.0"


def test_listing_runs_outside_checkout(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    seen = []
    instance.command = lambda name: name
    instance.run = lambda _argv, **kwargs: seen.append(kwargs.get("cwd")) or ""
    instance.cli("claude", ["plugin", "list"])
    assert seen == [instance.work]


def test_private_repeat_needs_exact_skip(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    repo = instance.work / "repo-a"
    repo.mkdir()
    for name in ("configuration/project.json", "configuration/workflow.md", "scripts/index.md", "scripts/check-task.ps1", "state/handoff.md"):
        path = repo / ".legion" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.touch()
    instance.legion = lambda *_args, **_kwargs: "skip: unrelated"
    instance.commit_count = lambda _path: 1
    instance.run = lambda *_args, **_kwargs: ""
    instance.state["inner_commits"] = 1
    with pytest.raises(AssertionError, match="Private orchestration"):
        instance.repository("private", True)


@pytest.mark.skipif(sys.platform != "win32", reason="winget changes the Windows saved PATH")
def test_command_finds_winget_alias_on_saved_path(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    checkout = Path(__file__).resolve().parents[2]
    instance = runner.Runner(checkout, tmp_path / "home", tmp_path / "results", False)
    folder = tmp_path / "winget-links"
    folder.mkdir()
    (folder / "claude.cmd").write_text("@echo off\r\necho fixture-version\r\n", encoding="utf-8")
    instance.env["PATH"] = str(tmp_path / "empty")
    monkeypatch.setattr(runner, "windows_saved_path_folders", lambda: [folder])
    assert Path(instance.command("claude")).parent == folder


MARKETPLACES = ".claude/plugins/known_marketplaces.json"


def marketplaces(source: str = "/repo", stamp: str = "2026-11-25T11:42:18.839Z", **extra: Any) -> str:
    entry = {"source": {"source": "directory", "path": source}, "installLocation": source, "lastUpdated": stamp, **extra}
    return json.dumps({"ps-legion-marketplace": entry, "other": {"source": {"source": "github"}, "lastUpdated": "a"}})


def update_snapshot(tmp_path: Path, content: str) -> dict[str, str]:
    instance = make_runner(tmp_path)
    path = instance.home / MARKETPLACES
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return instance.home_snapshot(update=True)


def test_update_snapshot_ignores_only_the_marketplace_last_updated_timestamp(tmp_path: Path) -> None:
    first = update_snapshot(tmp_path, marketplaces())
    assert update_snapshot(tmp_path, marketplaces(stamp="2026-11-25T11:43:00.000Z")) == first
    # The original snapshot keeps seeing the timestamp.
    instance = make_runner(tmp_path)
    assert instance.home_snapshot() != first


@pytest.mark.parametrize(
    "content",
    [
        marketplaces(source="/other"),
        marketplaces(installLocation="/elsewhere"),
        marketplaces(extra="new"),
        json.dumps({"renamed": {"source": {"source": "github"}}}),
        marketplaces().replace('"other"', '"other2"'),
    ],
)
def test_update_snapshot_still_detects_other_marketplace_changes(tmp_path: Path, content: str) -> None:
    first = update_snapshot(tmp_path, marketplaces())
    with pytest.raises(AssertionError, match=rf"changed: {MARKETPLACES}"):
        runner.unchanged(first, update_snapshot(tmp_path, content))


def test_update_snapshot_keeps_malformed_marketplaces_visible(tmp_path: Path) -> None:
    first = update_snapshot(tmp_path, "{not json")
    assert update_snapshot(tmp_path, "{not json") == first
    with pytest.raises(AssertionError, match=rf"changed: {MARKETPLACES}"):
        runner.unchanged(first, update_snapshot(tmp_path, "{not json!"))
    with pytest.raises(AssertionError, match=rf"changed: {MARKETPLACES}"):
        runner.unchanged(update_snapshot(tmp_path, marketplaces()), update_snapshot(tmp_path, "[1]"))


def test_update_snapshot_still_detects_other_claude_config_changes(tmp_path: Path) -> None:
    first = update_snapshot(tmp_path, marketplaces())
    instance = make_runner(tmp_path)
    (instance.home / ".claude/plugins/installed_plugins.json").write_text("{}", encoding="utf-8")
    with pytest.raises(AssertionError, match=r"added: .claude/plugins/installed_plugins.json"):
        runner.unchanged(first, instance.home_snapshot(update=True))


def copilot_config(**changes: Any) -> str:
    # Match the format that Copilot CLI 1.0.114 wrote in a disposable home.
    plugin = {
        "name": "legion",
        "marketplace": "ps-legion-marketplace",
        "version": "0.18.0",
        "installed_at": "2026-11-25T22:52:45.5283579Z",
        "cache_path": "/home/user/.copilot/installed-plugins/ps-legion-marketplace/legion",
        "installed_source": {"source": "github", "repo": "BlackGad/ps-legion-marketplace"},
        "source_sha": "6a7ff7919624c665cd48e6444e7076e421bd0ef620f2b61321435d22fb5581fb",
        "enabled": True,
    }
    extra = changes.pop("extra", {})
    plugin.update(changes)
    body = json.dumps({"installedPlugins": [plugin], "firstLaunchAt": "2026-03-11T00:00:00.000Z", **extra}, indent=2)
    return "// User settings belong in settings.json.\n// This file is managed automatically.\n" + body + "\n"


def copilot_snapshot(tmp_path: Path, content: str) -> dict[str, str]:
    instance = make_runner(tmp_path)
    path = instance.home / ".copilot/config.json"
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return instance.home_snapshot(update=True)


def test_update_snapshot_ignores_only_copilots_restamped_install_time(tmp_path: Path) -> None:
    # Copilot restamps installed_at on every `plugin update` of a Git-sourced plugin, even "already at latest".
    first = copilot_snapshot(tmp_path, copilot_config())
    assert copilot_snapshot(tmp_path, copilot_config(installed_at="2026-11-25T22:52:48.3198594Z")) == first


# Changes outside the Legion install timestamp must still be visible.
@pytest.mark.parametrize(
    "changes",
    [
        {"version": "0.19.0"},
        {"source_sha": "0" * 64},
        {"enabled": False},
        {"cache_path": "/elsewhere"},
        {"extra": {"trusted_folders": ["/repo"]}},
        {"extra": {"firstLaunchAt": "2026-03-12T00:00:00.000Z"}},
    ],
    ids=["version", "source", "enabled", "cache", "new-key", "first-launch"],
)
def test_update_snapshot_still_detects_every_other_copilot_config_change(tmp_path: Path, changes: dict[str, Any]) -> None:
    first = copilot_snapshot(tmp_path, copilot_config())
    with pytest.raises(AssertionError, match=r"changed: .copilot/config.json"):
        runner.unchanged(first, copilot_snapshot(tmp_path, copilot_config(**changes)))


def test_update_snapshot_keeps_unreadable_copilot_config_raw(tmp_path: Path) -> None:
    first = copilot_snapshot(tmp_path, "{not json")
    with pytest.raises(AssertionError, match=r"changed: .copilot/config.json"):
        runner.unchanged(first, copilot_snapshot(tmp_path, "{not json!"))


def test_update_snapshot_keeps_other_plugins_install_times(tmp_path: Path) -> None:
    first = copilot_snapshot(tmp_path, copilot_config(name="other"))
    with pytest.raises(AssertionError, match=r"changed: .copilot/config.json"):
        runner.unchanged(first, copilot_snapshot(tmp_path, copilot_config(name="other", installed_at="2026-11-25T22:52:48.3198594Z")))


def test_only_the_deletion_of_codex_finished_staging_is_expected() -> None:
    staging = runner.CODEX_STAGING + "marketplace-linux-abc123"
    unrelated = runner.CODEX_STAGING + "keep.txt"
    persistent = {".codex/config.toml": "c", unrelated: "sentinel"}
    before = {**persistent, staging: "directory", staging + "/checkout/plugin.json": "a"}
    runner.unchanged(runner.without_finished_codex_staging(before, persistent), persistent)
    # Keep checking staging additions, edits, and partial deletions, plus everything outside the checkout.
    for after in (
        {**before, runner.CODEX_STAGING + "marketplace-linux-new": "directory"},
        {**before, staging + "/checkout/plugin.json": "b"},
        {**persistent, staging: "directory"},
        {".codex/config.toml": "c"},
        {unrelated: "sentinel"},
    ):
        with pytest.raises(AssertionError, match="the home changed"):
            runner.unchanged(runner.without_finished_codex_staging(before, after), after)


def test_repeat_writes_every_change_and_the_config_values_on_both_sides(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    upgrade = make_runner(tmp_path / "upgrade")
    config = upgrade.home / ".copilot/config.json"
    config.parent.mkdir(parents=True)
    config.write_text(copilot_config(), encoding="utf-8")
    instance.state.update({"candidate": upgrade, "candidate_snapshot": upgrade.home_snapshot(update=True), "candidate_configs": upgrade.host_configs()})

    def repeat_update(*args: str, **_kwargs: Any) -> str:
        if args[0] == "update":
            config.write_text(copilot_config(installed_at="2026-11-25T22:52:48.3198594Z", extra={"trusted_folders": ["/repo"]}), encoding="utf-8")
        return "already up to date\n" + "\n".join(f"Update legion for {tool}" for tool in runner.TOOLS)

    upgrade.legion = repeat_update
    upgrade.version = lambda *_args: instance.candidate_version
    upgrade.check_uninstalled = lambda _tool, _folder: None
    with pytest.raises(AssertionError, match=r"repeat update: the home changed on the repeat run:\nchanged: .copilot/config.json"):
        instance.finish_candidate()
    evidence = json.loads((upgrade.out / "repeat-changes.json").read_text(encoding="utf-8"))
    assert evidence["changes"] == ["changed: .copilot/config.json"]
    values = evidence["configs"][".copilot/config.json"]
    assert '"trusted_folders"' not in values["before"]
    assert '"trusted_folders"' in values["after"]
    assert "22:52:48.3198594Z" in values["after"]
