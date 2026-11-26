# One account launch for every caller: the program, its config folder and arguments, against fake CLIs only.
import json
import os
import subprocess
import sys
from pathlib import Path

import pytest
from cli_runner import run
from launcher_fakes import (
    WINDOWS,
    agent,
    fake_cli,
    only_on_path,
    python_cli,
)

from legion.core import _settings_io
from legion.core._settings_models import Agent, PersonalisationSettings
from legion.services.accounts._launch import account_command, run_account
from legion.services.accounts._launchers import LauncherError
from legion.services.foundry._az import AzAccessToken
from legion.core._home import bin_folder
from legion.services.installation._installed_runtime import write_owner_commands

RUNNER = "import sys; from legion import cli as _cli; _cli.main(sys.argv[1:], prog_name='legion')"
ENDPOINT = "https://res-a.cognitiveservices.azure.com"


def save_agents(home: Path, *agents: Agent) -> None:
    _settings_io.save(home, PersonalisationSettings.model_validate({"schemaVersion": 1, "agents": [item.model_dump(by_alias=True, exclude_none=True) for item in agents], "channels": []}))


# The fake CLI prints var=<config folder> and arg=<word> lines; cmd.exe keeps the quotes of echo.
def readout(output: str) -> list[str]:
    return [line.strip('"') for line in output.splitlines()]


@pytest.fixture
def stock(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Path:
    command = fake_cli(tmp_path / "stock bin", "codex")
    only_on_path(monkeypatch, command.parent)
    return command


@pytest.mark.usefixtures("stock")
def test_account_command_uses_custom_command(tmp_path: Path) -> None:
    custom = fake_cli(tmp_path / "custom", "my-codex")
    command = account_command(agent("codex-a", tmp_path / "config", command=str(custom)), tmp_path)
    assert command.program == custom
    assert command.words(["--version"]) == [str(custom), "--version"]
    assert command.set_env == {"CODEX_HOME": str(tmp_path / "config"), "LEGION_HOME": str(tmp_path)}


def test_account_command_stock_when_unset(tmp_path: Path, stock: Path) -> None:
    command = account_command(agent("codex-a", tmp_path / "config"), tmp_path)
    assert command.program == stock
    assert command.prefix == []
    assert command.provider_file is None


@pytest.mark.usefixtures("stock")
def test_account_command_ps1_target_runs_pwsh_file(tmp_path: Path) -> None:
    script = tmp_path / "my codex.ps1"
    script.write_text("exit 0\n", encoding="utf-8")
    command = account_command(agent("codex-a", tmp_path / "config", command=str(script)), tmp_path)
    assert command.words(["a"]) == ["pwsh", "-NoProfile", "-File", str(script), "a"]


def test_account_command_foundry_sets_provider_env(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    claude = fake_cli(tmp_path / "stock bin", "claude", "CLAUDE_CONFIG_DIR")
    only_on_path(monkeypatch, claude.parent)
    provider = {"kind": "foundry", "endpoint": ENDPOINT, "default": "claude-opus-x", "deployments": [{"name": "claude-opus-x", "alias": "opus"}]}
    foundry = Agent.model_validate({"id": "claude-dev", "tool": "claude", "configDir": "~/claude-dev", "provider": provider})
    token = AzAccessToken.model_validate({"accessToken": "fake-token", "expiresOn": "2026-11-18T18:30:00+00:00"})
    command = account_command(foundry, tmp_path, token_check=lambda: token)
    assert command.program == claude
    assert command.set_env["CLAUDE_CODE_USE_FOUNDRY"] == "1"
    assert command.set_env["ANTHROPIC_FOUNDRY_BASE_URL"] == f"{ENDPOINT}/anthropic"
    assert command.set_env["ANTHROPIC_DEFAULT_OPUS_MODEL"] == "claude-opus-x"
    assert Path(command.set_env["CLAUDE_CONFIG_DIR"]) == tmp_path / "claude-dev"
    assert command.set_env["LEGION_HOME"] == str(tmp_path)
    assert "CLAUDE_CODE_USE_BEDROCK" in command.clear_env


def test_account_command_without_any_program_names_the_installer(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    only_on_path(monkeypatch, tmp_path / "empty")
    with pytest.raises(LauncherError, match=r"^codex is not installed; run legion tool install --tool codex$"):
        account_command(agent("codex-a", tmp_path / "config"), tmp_path)


@pytest.mark.usefixtures("stock")
def test_environment_drops_legions_own_virtual_environment_and_keeps_the_callers(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("VIRTUAL_ENV", sys.prefix)
    monkeypatch.setenv("CODEX_HOME", "parent folder")
    command = account_command(agent("codex-a", tmp_path / "config"), tmp_path)
    environment = command.environment()
    assert "VIRTUAL_ENV" not in environment
    assert environment["CODEX_HOME"] == str(tmp_path / "config")
    assert command.environment({"OWN": "1"}) == {"OWN": "1", **command.set_env}


@pytest.mark.usefixtures("stock")
def test_launch_target_with_spaces(tmp_path: Path, capfd: pytest.CaptureFixture[str]) -> None:
    home = tmp_path / "owner home & 100%"
    custom = fake_cli(tmp_path / "program folder", "my codex")
    save_agents(home, agent("codex-a", home / "config folder", command=str(custom)))
    assert run_account("codex-a", ["two words", "a&b"], home) == 3
    assert readout(capfd.readouterr().out) == [f"var={home / 'config folder'}", "arg=two words", "arg=a&b"]


# Every kind of program gets its arguments literally, the config variable set and its exit code passed on.
@pytest.mark.parametrize("kind", ["cli", "exe", "ps1"])
def test_run_account_forwards_arguments_and_exit_code(tmp_path: Path, stock: Path, kind: str, pwsh_path: Path, monkeypatch: pytest.MonkeyPatch, capfd: pytest.CaptureFixture[str]) -> None:
    folder = tmp_path / "account folder"
    arguments = ["first", "two words"]
    if kind == "exe":
        script = python_cli(tmp_path / "py")
        command, arguments = Path(sys.executable), [str(script), *arguments]
    elif kind == "ps1":
        command = tmp_path / "prompt folder" / "worker prompt.ps1"
        command.parent.mkdir()
        command.write_text('Write-Output ("var=" + $env:CODEX_HOME)\nforeach ($word in $args) { Write-Output ("arg=" + $word) }\nexit 3\n', encoding="utf-8")
        only_on_path(monkeypatch, stock.parent, pwsh_path.parent)
        arguments = ["-Worker", "--prompt", str(tmp_path / "prompt folder" / "task prompt.txt"), "--allow-all-tools", *arguments]
    else:
        command = stock
    save_agents(tmp_path, agent("codex-a", folder, command=str(command)))
    assert run_account("codex-a", arguments, tmp_path) == 3
    lines = readout(capfd.readouterr().out)
    assert lines[0] == f"var={folder}"
    expected = arguments[1:] if kind == "exe" else arguments
    assert lines[1:] == [f"arg={word}" for word in expected]


@pytest.mark.usefixtures("stock")
def test_run_account_passes_its_home_to_the_host(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capfd: pytest.CaptureFixture[str]) -> None:
    script = tmp_path / "read_home.py"
    script.write_text('import os\nprint(os.environ["LEGION_HOME"])\n', encoding="utf-8")
    monkeypatch.setenv("LEGION_HOME", str(tmp_path / "other home"))
    home = tmp_path / "home"
    save_agents(home, agent("codex-a", home / "config", command=sys.executable))
    assert run_account("codex-a", [str(script)], home) == 0
    assert Path(capfd.readouterr().out.strip()) == home


@pytest.mark.skipif(not WINDOWS, reason="cmd.exe syntax in a .cmd program's path")
@pytest.mark.usefixtures("stock")
def test_batch_program_keeps_percent_and_bang_paths(tmp_path: Path, capfd: pytest.CaptureFixture[str]) -> None:
    home = tmp_path / "owner! root"
    command = fake_cli(tmp_path / "%TEMP% ! target", "fake")
    folder = home / "%TEMP% ! config"
    save_agents(home, agent("codex-a", folder, command=str(command)))
    assert run_account("codex-a", ["first", "two words"], home) == 3
    assert readout(capfd.readouterr().out) == [f"var={folder}", "arg=first", "arg=two words"]


# Every character cmd.exe treats as syntax reaches a .cmd or .bat program literally, in the arguments as well.
@pytest.mark.skipif(not WINDOWS, reason="batch programs run on Windows only")
@pytest.mark.parametrize("suffix", [".cmd", ".bat"])
def test_batch_program_receives_cmd_syntax_arguments_literally(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, suffix: str) -> None:
    record, out = tmp_path / "record.py", tmp_path / "argv.json"
    record.write_text("import json, os, sys\nopen(os.environ['ARGV_OUT'], 'w', encoding='utf-8').write(json.dumps(sys.argv[1:]))\n", encoding="utf-8")
    program = tmp_path / f"fake{suffix}"
    program.write_text(f'@"{sys.executable}" "{record}" %*\r\n', encoding="utf-8", newline="")
    save_agents(tmp_path, agent("codex-a", tmp_path / "config", command=str(program)))
    monkeypatch.setenv("ARGV_OUT", str(out))
    words = ["100%", "%PATH%", "bang!", "!PATH!", "caret^", "a^^b", 'say "hi"', '"quoted"', "back\\", 'end\\"', "a&b|c<d>e", "two words", ""]
    assert run_account("codex-a", words, tmp_path) == 0
    assert json.loads(out.read_text(encoding="utf-8")) == words


# Two homes can hold the same account id. A member runs the selected home's own owner command; it reaches that
# home's account even with the other home's command first on PATH. A fake uv runs this checkout's legion in its place.
@pytest.mark.parametrize("selected", [0, 1])
def test_two_homes_with_the_same_account_id_each_start_their_own(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, stock: Path, selected: int) -> None:
    homes = [tmp_path / "home a", tmp_path / "home b"]
    for home in homes:
        save_agents(home, agent("codex-a", home / "config"))
        bin_folder(home).mkdir(parents=True)
        write_owner_commands(home / ".legion" / "app" / "1.0.0", home)
    fake_uv = tmp_path / "fake uv"
    fake_uv.mkdir()
    script = fake_uv / "uv.py"
    script.write_text("import sys\nfrom legion import cli\nwords = sys.argv[1:]\ncli.main(words[words.index('legion') + 1 :], prog_name='legion')\n", encoding="utf-8")
    if WINDOWS:
        (fake_uv / "uv.cmd").write_text(f'@"{sys.executable}" "{script}" %*\r\n', encoding="utf-8", newline="")
        system = [str(Path(os.environ["SYSTEMROOT"]) / "System32")]
    else:
        (fake_uv / "uv").write_text(f'#!/bin/sh\nexec "{sys.executable}" "{script}" "$@"\n', encoding="utf-8")
        (fake_uv / "uv").chmod(0o755)
        system = ["/usr/bin", "/bin"]
    other = homes[1 - selected]
    monkeypatch.setenv("PATH", os.pathsep.join([str(bin_folder(other)), str(fake_uv), str(stock.parent), *system]))
    command = bin_folder(homes[selected]) / ("legion.cmd" if WINDOWS else "legion")
    result = subprocess.run([str(command), "run", "--account", "codex-a", "--", "--version"], capture_output=True, text=True, check=False)
    lines = readout(result.stdout)
    assert f"var={homes[selected] / 'config'}" in lines
    assert f"var={other / 'config'}" not in lines


@pytest.mark.usefixtures("stock")
def test_unknown_account_is_refused(tmp_path: Path) -> None:
    save_agents(tmp_path, agent("codex-a", tmp_path / "config"))
    with pytest.raises(LauncherError, match=r"^unknown account 'nobody'$"):
        run_account("nobody", [], tmp_path)


# The command line member dispatch uses: legion run --account <id> -- <tool arguments>, exit code kept.
@pytest.mark.usefixtures("stock")
def test_cli_run_reaches_the_account_program_with_its_folder(tmp_path: Path) -> None:
    home = tmp_path / "home with spaces"
    save_agents(home, agent("codex-a", home / "config"))
    arguments = [sys.executable, "-c", RUNNER, "--home", str(home), "run", "--account", "codex-a", "--", "--version", "two words"]
    result = subprocess.run(arguments, capture_output=True, text=True, check=False)
    assert result.returncode == 3, result.stderr
    assert readout(result.stdout) == [f"var={home / 'config'}", "arg=--version", "arg=two words"]


@pytest.mark.usefixtures("stock")
def test_cli_run_reports_an_unknown_account(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    save_agents(tmp_path, agent("codex-a", tmp_path / "config"))
    assert run(["--home", str(tmp_path), "run", "--account", "nobody", "--", "x"]) == 1
    assert capsys.readouterr().err.strip() == "unknown account 'nobody'"


def test_hidden_run_absent_from_help(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--help"]) == 0
    verbs = [line.split()[0] for line in capsys.readouterr().out.split("Commands:")[1].splitlines() if line.strip()]
    assert "run" not in verbs
    assert "foundry" not in verbs
    assert "account" in verbs
