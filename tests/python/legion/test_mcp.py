import builtins
import json
import os
import shutil
import subprocess
import sys
import time
from collections.abc import Iterator
from pathlib import Path
from typing import Any, Optional

import anyio
import pytest
from click.testing import CliRunner
from cli_runner import run
from launcher_fakes import only_on_path
from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client
from mcp.shared.memory import create_connected_server_and_client_session
from mcp_protocol_fake import Connection
from test_limits import (
    ACCOUNTS,
    FIXTURES,
    Bench,
    write_executable,
    write_settings,
)

from legion import cli
from legion.core._process import process_started_at
from legion.core._run import RunResult
from legion.mcp import server as mcp_server
from legion.mcp.server import build
from legion.services.installation import _installed_runtime
from legion.services.limits.limit_probes import _ping

pytest_plugins = ["status_parity"]


@pytest.fixture
def bench(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Bench:
    result = Bench(tmp_path, monkeypatch)
    write_settings(result.home, ACCOUNTS)
    return result


@pytest.fixture
def connection(bench: Bench) -> Iterator[Connection]:
    result = Connection(bench.home)
    try:
        result.ready()
        yield result
    finally:
        result.close()


def wait_pid(path: Path) -> int:
    # The writer signals after closing the PID file, so Windows can open it for reading.
    ready = path.with_suffix(".ready")
    deadline = time.monotonic() + 30
    while not ready.is_file():
        assert time.monotonic() < deadline, f"no readiness file: {ready}"
        time.sleep(0.01)
    return int(path.read_text(encoding="utf-8"))


def assert_dead(pid: int) -> None:
    deadline = time.monotonic() + 5
    while process_started_at(pid) is not None:
        assert time.monotonic() < deadline, f"process {pid} survived disconnect"
        time.sleep(0.01)


def test_mcp_lists_exactly_status_and_limits(connection: Connection) -> None:
    connection.send("tools/list", request=3)
    tools = connection.receive(3)["result"]["tools"]
    assert {tool["name"] for tool in tools} == {"status", "limits"}
    assert all(tool["description"] and "\n" not in tool["description"] for tool in tools)
    assert all(tool["outputSchema"] for tool in tools)
    limits = next(tool for tool in tools if tool["name"] == "limits")
    status = next(tool for tool in tools if tool["name"] == "status")
    assert "accounts" in limits["inputSchema"]["required"]
    assert limits["annotations"]["readOnlyHint"] is False
    assert limits["annotations"]["idempotentHint"] is False
    assert limits["annotations"]["openWorldHint"] is True
    assert status["annotations"]["readOnlyHint"] is True


def test_all_hosts_register_same_installed_command() -> None:
    root = Path(__file__).resolve().parents[3] / "plugins/legion"
    config = json.loads((root / ".mcp.json").read_text(encoding="utf-8"))
    assert config["mcpServers"] == {"legion": {"type": "stdio", "command": "legion", "args": ["mcp"], "tools": ["status", "limits"]}}
    assert json.loads((root / "plugin.json").read_text(encoding="utf-8"))["mcpServers"] == "./.mcp.json"
    # Codex silently drops a server that carries Copilot's tools list, so it reads its own file with the same command.
    assert json.loads((root / ".codex-plugin/plugin.json").read_text(encoding="utf-8"))["mcpServers"] == "./.codex-plugin/mcp.json"
    codex = json.loads((root / ".codex-plugin/mcp.json").read_text(encoding="utf-8"))
    shared = config["mcpServers"]["legion"]
    assert codex["mcpServers"] == {"legion": {"command": shared["command"], "args": shared["args"]}}
    # Claude discovers the root .mcp.json automatically. No host user configuration is written.
    assert (root / ".claude-plugin/plugin.json").is_file()
    member = (root / "skills/legion-member/SKILL.md").read_text(encoding="utf-8")
    assert "Never use Legion's MCP tools" in member
    claude_run = (root / "skills/legion-claude/references/run.md").read_text(encoding="utf-8")
    assert "--strict-mcp-config" in claude_run


def test_mcp_status_equals_cli_and_writes_nothing(parity_home: tuple[Path, Path], tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    repo, home = parity_home
    git = shutil.which("git")
    assert git is not None
    only_on_path(monkeypatch, tmp_path, Path(git).parent)
    assert run(["--home", str(home), "status", "--json"]) == 0
    expected = json.loads(capsys.readouterr().out)
    assert expected["repository"]["mode"] == "Shared"
    assert expected["repository"]["lease"] == "free"
    assert expected["repository"]["handoff"] is True
    before = {str(path): path.read_bytes() for path in home.rglob("*") if path.is_file()}

    async def check() -> None:
        async with create_connected_server_and_client_session(build(home)) as session:
            for arguments in ({}, {"repo": str(repo)}):
                result = await session.call_tool("status", arguments)
                assert not result.isError
                assert result.structuredContent == expected
        params = StdioServerParameters(command=sys.executable, args=["-m", "legion.cli", "--home", str(home), "mcp"], env=dict(os.environ))
        async with stdio_client(params) as (read, write), ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("status", {"repo": str(repo)})
            assert not result.isError
            assert result.structuredContent == expected

    anyio.run(check)
    assert before == {str(path): path.read_bytes() for path in home.rglob("*") if path.is_file()}


def test_stdio_limits_equals_cli_explicit_accounts(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--home", str(bench.home), "limits", "--id", "copilot-a", "--id", "claude-a", "--timeout", "5", "--json"]) == 0
    expected = json.loads(capsys.readouterr().out)

    async def check() -> None:
        params = StdioServerParameters(command=sys.executable, args=["-m", "legion.cli", "--home", str(bench.home), "mcp"], env=dict(os.environ))
        async with stdio_client(params) as (read, write), ClientSession(read, write) as session:
            await session.initialize()
            result = await session.call_tool("limits", {"accounts": ["copilot-a", "claude-a"], "timeout": 5})
            assert not result.isError
            # MCP structured output requires an object; the SDK wraps array results.
            assert result.structuredContent == {"result": expected}

    anyio.run(check)
    assert len(bench.calls("copilot")) == len(bench.calls("claude")) == 2
    # Both interfaces start the stock CLI with the account's own config folder.
    assert {Path(call["config"]["CLAUDE_CONFIG_DIR"]) for call in bench.calls("claude")} == {bench.config("claude-a")}


@pytest.mark.parametrize(
    ("arguments", "message"),
    [
        ({}, "accounts"),
        ({"accounts": []}, "name at least one account"),
        ({"accounts": ["claude-a", "unknown"], "timeout": 1}, "unknown account"),
        ({"accounts": "claude-a"}, "array"),
        ({"accounts": '["claude-a"]'}, "array"),
        ({"accounts": '["codex-a"]'}, "array"),
        ({"accounts": {"0": "claude-a"}}, "array"),
        ({"accounts": [42]}, "string"),
        ({"accounts": ["claude-a"], "timeout": "1"}, "number"),
        ({"accounts": ["claude-a"], "timeout": True}, "number"),
        ({"accounts": ["claude-a"], "timeout": 0}, "minimum"),
        ({"accounts": ["claude-a"], "timeout": -1}, "minimum"),
        ({"accounts": ["claude-a"], "timeout": None}, "number"),
        ({"accounts": ["claude-a"], "timeout": float("inf")}, "number"),
    ],
)
def test_invalid_limits_never_start_probes(connection: Connection, bench: Bench, arguments: dict[str, Any], message: str) -> None:
    connection.send("tools/call", {"name": "limits", "arguments": arguments}, 3)
    result = connection.receive(3)["result"]
    assert result["isError"]
    assert message in str(result["content"])
    assert not list(bench.logs.iterdir())


def test_default_single_account_is_usable(connection: Connection, bench: Bench) -> None:
    connection.send("tools/call", {"name": "limits", "arguments": {"accounts": ["copilot-a"]}}, 3)
    result = connection.receive(3)["result"]
    assert not result.get("isError", False)
    assert result["structuredContent"]["result"][0]["account"] == "copilot-a"
    assert len(bench.calls("copilot")) == 1


def test_default_multi_account_call_returns_results_in_selection_order(connection: Connection, bench: Bench) -> None:
    connection.send("tools/call", {"name": "limits", "arguments": {"accounts": ["copilot-a", "claude-a"]}}, 3)
    result = connection.receive(3)["result"]
    assert not result.get("isError", False), result
    assert [entry["account"] for entry in result["structuredContent"]["result"]] == ["copilot-a", "claude-a"]
    assert len(bench.calls("copilot")) == len(bench.calls("claude")) == 1


@pytest.mark.parametrize("stop", ["eof", "cancel"])
def test_interrupting_multi_account_call_cleans_all_probes(connection: Connection, bench: Bench, stop: str) -> None:
    tools = ("claude", "copilot")
    for tool in tools:
        log = bench.logs / tool
        log.mkdir()
        write_executable(bench.path, tool, {"LEGION_FAKE_LOG": str(log), f"LEGION_FAKE_{tool.upper()}_SLEEP": "60"})

    connection.send("tools/call", {"name": "limits", "arguments": {"accounts": ["claude-a", "copilot-a"]}}, 3)
    probes = []
    for tool in tools:
        log = bench.logs / tool
        grandchild = wait_pid(log / "grandchild.pid")
        call = json.loads((log / f"{tool}.jsonl").read_text(encoding="utf-8"))
        probes.append((grandchild, call["pid"], Path(call["folder"])))

    if stop == "eof":
        connection.eof()
        assert connection.process.wait(timeout=5) == 0
    else:
        connection.send("notifications/cancelled", {"requestId": 3})

    for grandchild, pid, ping_folder in probes:
        assert_dead(grandchild)
        assert_dead(pid)
        deadline = time.monotonic() + 5
        while ping_folder.exists():
            assert time.monotonic() < deadline, "ping folder survived interruption"
            time.sleep(0.01)


@pytest.mark.parametrize("stop", ["eof", "cancel"])
@pytest.mark.parametrize("target", ["claude", "codex", "copilot", "az", "git"])
def test_interrupted_limits_kills_tree_and_removes_folder(connection: Connection, bench: Bench, stop: str, target: str) -> None:
    # The subprocess inherited its environment at startup; put the sleep setting in the fake executable.
    account = "foundry-a" if target == "az" else "codex-a" if target == "git" else f"{target}-a"
    write_executable(bench.path, target, {f"LEGION_FAKE_{target.upper()}_SLEEP": "60"})
    connection.send("tools/call", {"name": "limits", "arguments": {"accounts": [account]}}, 3)
    pid = wait_pid(bench.logs / "grandchild.pid")
    call = bench.calls(target)[0]
    ping_folder = Path(call["arguments"][1] if target == "git" else call["folder"])
    if stop == "eof":
        connection.eof()
        assert connection.process.wait(timeout=5) == 0
    else:
        connection.send("notifications/cancelled", {"requestId": 3, "reason": "fake host cancelled"})
        connection.send("tools/list", request=4)
        assert "result" in connection.receive(4)
    assert_dead(pid)
    assert_dead(call["pid"])
    if target != "az":
        deadline = time.monotonic() + 5
        while ping_folder.exists():
            assert time.monotonic() < deadline, "ping folder survived cancellation"
            time.sleep(0.01)


@pytest.mark.skipif(sys.platform == "win32", reason="Unix process sessions")
@pytest.mark.parametrize("stop", ["eof", "cancel"])
@pytest.mark.parametrize("target", ["claude", "codex", "copilot", "az", "git"])
def test_detached_descendant_is_stopped(connection: Connection, bench: Bench, stop: str, target: str) -> None:
    account = "foundry-a" if target == "az" else "codex-a" if target == "git" else f"{target}-a"
    write_executable(bench.path, target, {f"LEGION_FAKE_{target.upper()}_SLEEP": "60", f"LEGION_FAKE_{target.upper()}_DETACH": "1"})
    connection.send("tools/call", {"name": "limits", "arguments": {"accounts": [account]}}, 3)
    pid = wait_pid(bench.logs / "grandchild.pid")
    call = bench.calls(target)[0]
    # Establish that the fixture really left the probe's process group and session.
    if sys.platform != "win32":
        assert os.getpgid(pid) == os.getsid(pid) == pid
        assert os.getpgid(call["pid"]) != os.getpgid(pid)
    if stop == "eof":
        connection.eof()
        assert connection.process.wait(timeout=5) == 0
    else:
        connection.send("notifications/cancelled", {"requestId": 3})
    assert_dead(pid)
    assert_dead(call["pid"])
    if target != "az":
        deadline = time.monotonic() + 5
        while Path(call["arguments"][1] if target == "git" else call["folder"]).exists():
            assert time.monotonic() < deadline
            time.sleep(0.01)
    if stop != "eof":
        connection.send("tools/call", {"name": "limits", "arguments": {"accounts": ["copilot-a" if target != "copilot" else "claude-a"], "timeout": 1}}, 4)
        assert not connection.receive(4)["result"].get("isError", False)


@pytest.mark.parametrize("timeout", ["nan", "NaN", "inf", "+inf", "-inf"])
def test_cli_rejects_nonfinite_timeout_without_probes(bench: Bench, timeout: str) -> None:
    result = subprocess.run([sys.executable, "-m", "legion.cli", "--home", str(bench.home), "limits", "--id", "claude-a", "--timeout", timeout], capture_output=True, text=True, check=False)
    assert result.returncode == 2
    assert "--timeout" in result.stderr
    assert not list(bench.logs.iterdir())


def test_limits_bounds_single_account_default(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    observed = []

    async def run_cli(arguments: list[str], home: Optional[Path], cwd: Optional[Path] = None) -> bytes:
        del home, cwd
        observed.append(arguments)
        return b"[]"

    monkeypatch.setattr(mcp_server, "_run_cli", run_cli)

    async def check() -> None:
        async with create_connected_server_and_client_session(build(bench.home)) as session:
            assert not (await session.call_tool("limits", {"accounts": ["claude-a"]})).isError

    anyio.run(check)
    assert observed == [["limits", "--json", "--timeout", str(mcp_server.PROBE_BUDGET), "--id", "claude-a"]]


def test_probe_timeout_cleans_tree_and_allows_next_call(connection: Connection, bench: Bench) -> None:
    write_executable(bench.path, "claude", {"LEGION_FAKE_CLAUDE_SLEEP": "60"})
    connection.send("tools/call", {"name": "limits", "arguments": {"accounts": ["claude-a"], "timeout": 5}}, 3)
    pid = wait_pid(bench.logs / "grandchild.pid")
    assert "ping timed out" in str(connection.receive(3))
    assert_dead(pid)
    assert not Path(bench.calls("claude")[0]["folder"]).exists()
    connection.send("tools/call", {"name": "limits", "arguments": {"accounts": ["copilot-a"]}}, 4)
    assert not connection.receive(4)["result"].get("isError", False)


def test_limits_returns_timeout_and_fast_rows_in_one_call(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    # Keep the CLI's probe handling and JSON output while controlling the process results.
    results = {
        "copilot": RunResult(exit_code=-1, output="", error="", timed_out=True),
        "claude": RunResult(exit_code=0, output=(FIXTURES / "claude-stream.jsonl").read_text(encoding="utf-8"), error="", timed_out=False),
    }

    def run_probe(command: str, *_args: object, **_kwargs: object) -> RunResult:
        return results[Path(command).stem]

    async def run_cli(arguments: list[str], home: Optional[Path]) -> bytes:
        result = CliRunner().invoke(cli.main, ["--home", str(home), *arguments], catch_exceptions=False)
        assert result.exit_code == 0, result.output
        return result.stdout_bytes

    monkeypatch.setattr(_ping, "run_command", run_probe)
    monkeypatch.setattr(mcp_server, "_run_cli", run_cli)

    async def check() -> None:
        async with create_connected_server_and_client_session(build(bench.home)) as session:
            result = await session.call_tool("limits", {"accounts": ["copilot-a", "claude-a"]})
            assert not result.isError, result.content
            assert result.structuredContent is not None
            timed_out, fast = result.structuredContent["result"]
            assert timed_out["account"] == "copilot-a"
            assert [row["status"] for row in timed_out["rows"]] == ["ping timed out"]
            assert fast["account"] == "claude-a"
            assert [(row["window"], row["used"]) for row in fast["rows"]] == [("five_hour", "69%"), ("seven_day", "55%")]

    anyio.run(check)


def test_mcp_deadline_ends_the_child_tree_and_allows_next_call(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    write_executable(bench.path, "claude", {"LEGION_FAKE_CLAUDE_SLEEP": "60"})
    # The CLI's own probe timeout equals the budget but starts after the child's startup, so the MCP deadline comes first.
    monkeypatch.setattr(mcp_server, "CALL_BUDGET", 6.0)
    monkeypatch.setattr(mcp_server, "PROBE_BUDGET", 6.0)

    async def check() -> None:
        async with create_connected_server_and_client_session(build(bench.home)) as session:
            result = await session.call_tool("limits", {"accounts": ["claude-a"]})
            assert result.isError
            assert "MCP call deadline exceeded" in str(result.content)
            assert_dead(int((bench.logs / "grandchild.pid").read_text(encoding="utf-8")))
            assert_dead(bench.calls("claude")[0]["pid"])
            assert not (await session.call_tool("limits", {"accounts": ["copilot-a"]})).isError

    anyio.run(check)
    assert not Path(bench.calls("claude")[0]["folder"]).exists()


def test_status_does_not_import_modules_from_the_repository(bench: Bench, tmp_path: Path) -> None:
    repo = tmp_path / "repository"
    (repo / "legion").mkdir(parents=True)
    marker = tmp_path / "shadow-imported"
    (repo / "legion/__init__.py").write_text(f"from pathlib import Path\nPath({str(marker)!r}).write_text('x')\n", encoding="utf-8")

    async def check() -> None:
        async with create_connected_server_and_client_session(build(bench.home)) as session:
            result = await session.call_tool("status", {"repo": str(repo)})
            assert not result.isError

    anyio.run(check)
    assert not marker.exists()


def test_cancelling_one_request_leaves_the_other_probe_alive(connection: Connection, bench: Bench) -> None:
    probes = []
    for request, tool in ((3, "claude"), (4, "copilot")):
        log = bench.logs / tool
        log.mkdir()
        write_executable(bench.path, tool, {"LEGION_FAKE_LOG": str(log), f"LEGION_FAKE_{tool.upper()}_SLEEP": "60"})
        connection.send("tools/call", {"name": "limits", "arguments": {"accounts": [f"{tool}-a"]}}, request)
        probes.append(wait_pid(log / "grandchild.pid"))
    connection.send("notifications/cancelled", {"requestId": 3})
    assert_dead(probes[0])
    assert process_started_at(probes[1]) is not None
    connection.send("notifications/cancelled", {"requestId": 4})
    assert_dead(probes[1])
    connection.send("tools/list", request=5)
    assert "result" in connection.receive(5)


def test_eof_during_status_cleans_git_probe(connection: Connection, bench: Bench, tmp_path: Path) -> None:
    repo = tmp_path / "repository"
    for name in ("configuration/project.json", "configuration/workflow.md", "scripts/index.md"):
        path = repo / ".legion" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("fixture", encoding="utf-8")
    write_executable(bench.path, "git", {"LEGION_FAKE_GIT_SLEEP": "60"})
    connection.send("tools/call", {"name": "status", "arguments": {"repo": str(repo)}}, 3)
    pid = wait_pid(bench.logs / "grandchild.pid")
    parent = bench.calls("git")[0]["pid"]
    connection.eof()
    assert connection.process.wait(timeout=5) == 0
    assert_dead(pid)
    assert_dead(parent)


def test_abrupt_host_loss_cleans_probe_and_reconnects(bench: Bench) -> None:
    bench.fake(CLAUDE_SLEEP="60")
    marker = bench.logs / "server.pid"
    host = subprocess.Popen([sys.executable, str(Path(__file__).with_name("mcp_protocol_fake.py")), str(bench.home), str(marker)], stdin=subprocess.PIPE)
    try:
        server_pid = wait_pid(marker)
        probe_pid = wait_pid(bench.logs / "grandchild.pid")
        host.kill()
        host.wait(timeout=5)
        assert_dead(probe_pid)
        assert_dead(server_pid)
        reconnect = Connection(bench.home)
        try:
            reconnect.ready()
            assert reconnect.process.pid != server_pid
            reconnect.eof()
            assert reconnect.process.wait(timeout=5) == 0
        finally:
            reconnect.close()
    finally:
        if host.poll() is None:
            host.kill()
            host.wait(timeout=5)
        assert host.stdin is not None
        host.stdin.close()


@pytest.mark.parametrize("tool", ["status", "limits"])
def test_member_connection_is_harmless(bench: Bench, monkeypatch: pytest.MonkeyPatch, tool: str) -> None:
    monkeypatch.setenv("LEGION_ROLE", "member")

    async def check() -> None:
        async with create_connected_server_and_client_session(build(bench.home)) as session:
            result = await session.call_tool(tool, {"accounts": ["claude-a"]} if tool == "limits" else {})
            assert result.isError
            assert "members do not use" in str(result.content)

    anyio.run(check)
    assert not list(bench.logs.iterdir())


def test_mcp_command_without_extra_says_run_setup(monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    original = builtins.__import__

    def missing(name: str, *args: Any, **kwargs: Any) -> Any:
        if name == "legion.mcp.server":
            raise ModuleNotFoundError("missing SDK", name="mcp")
        return original(name, *args, **kwargs)

    monkeypatch.setattr(builtins, "__import__", missing)
    assert run(["mcp"]) == 1
    assert capsys.readouterr().err == "MCP dependencies are missing; run legion setup.\n"


def test_installed_command_discovers_offline_without_uv(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    app = bench.home / ".legion/app/1.0.0"
    app.mkdir(parents=True)
    environment = _installed_runtime.python_environment(app, bench.home)
    relative = "Scripts/legion.exe" if sys.platform == "win32" else "bin/legion"
    program = environment / relative
    program.parent.mkdir(parents=True)
    development_program = Path(sys.executable).with_name("legion.exe" if sys.platform == "win32" else "legion")
    shutil.copy2(development_program, program)
    _installed_runtime.write_owner_commands(app, bench.home)
    only_on_path(monkeypatch, bench.home / ".legion/bin")
    assert shutil.which("uv") is None

    async def check() -> None:
        params = StdioServerParameters(command="legion", args=["mcp"], env=dict(os.environ))
        async with stdio_client(params) as (read, write), ClientSession(read, write) as session:
            await session.initialize()
            assert {tool.name for tool in (await session.list_tools()).tools} == {"status", "limits"}
            result = await session.call_tool("status", {})
            assert not result.isError
            assert result.structuredContent is not None
            assert result.structuredContent["settings"]["state"] == "ok"

    anyio.run(check)
