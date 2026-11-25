import json
import stat
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

import pytest
from cli_runner import run
from filelock import FileLock
from launcher_fakes import WINDOWS, agent, fake_cli, only_on_path, tool

from legion.services.accounts import _accounts, _launchers
from legion.services.repository import _footprints
from legion.core import _generated, _settings_io
from legion.core._home import bin_folder, settings_path, wrapper_command

OLD_FOLDER = "Existing account config folder does not exist."
windows_only = pytest.mark.skipif(not WINDOWS, reason="Windows has two launchers")
posix_only = pytest.mark.skipif(WINDOWS, reason="POSIX file modes")


class World:
    def __init__(self, base: Path) -> None:
        self.base = base
        self.home = base / "home"
        self.home.mkdir()
        self.tools = base / "tools"
        self.custom = fake_cli(base / "custom", "my-codex")

    def agents(self) -> list[dict[str, Any]]:
        return json.loads(settings_path(self.home).read_text(encoding="utf-8"))["agents"]

    def channels(self) -> list[dict[str, Any]]:
        return json.loads(settings_path(self.home).read_text(encoding="utf-8"))["channels"]

    def folder(self, account: str) -> Path:
        return self.home / ".legion" / "agents" / account

    def launchers(self, account: str) -> list[Path]:
        return _launchers.launcher_paths(account, self.home)

    def settings_bytes(self) -> bytes:
        return settings_path(self.home).read_bytes()

    def launcher_bytes(self, account: str) -> list[bytes]:
        return [path.read_bytes() for path in self.launchers(account)]

    # Settings as an older legion wrote them: no command, launchers written by the stock rule.
    def old_account(self, account: str = "codex-a", tool_id: str = "codex") -> None:
        data = {"schemaVersion": 1, "agents": [{"id": account, "tool": tool_id, "configDir": str(self.folder(account))}], "channels": []}
        write_settings(self.home, data)
        self.folder(account).mkdir(parents=True, exist_ok=True)
        _launchers.write_subscription(agent(account, self.folder(account), tool_id), tool(tool_id), self.home)


def write_settings(home: Path, data: dict[str, Any]) -> None:
    path = settings_path(home)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data), encoding="utf-8")


@pytest.fixture
def world(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> World:
    world = World(tmp_path)
    for name, variable in (("claude", "CLAUDE_CONFIG_DIR"), ("codex", "CODEX_HOME"), ("copilot", "COPILOT_HOME"), ("taken", "TAKEN")):
        fake_cli(world.tools, name, variable)
    only_on_path(monkeypatch, world.tools)
    monkeypatch.chdir(tmp_path)
    return world


def legion(world: World, *words: str) -> int:
    return run(["--home", str(world.home), *words])


def account(world: World, *words: str) -> int:
    return legion(world, "account", *words)


def add(world: World, account_id: str = "codex-a", tool_id: str = "codex", *more: str) -> int:
    return account(world, "add", "--id", account_id, "--tool", tool_id, *more)


def says(capsys: pytest.CaptureFixture[str]) -> tuple[str, str]:
    captured = capsys.readouterr()
    return captured.out, captured.err


def test_new_account_stores_no_command_for_the_stock_cli(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world) == 0
    assert says(capsys) == ("Run 'codex-a' in a terminal and log in once.\n", "")
    assert world.agents() == [{"id": "codex-a", "tool": "codex", "configDir": str(world.folder("codex-a"))}]
    assert world.folder("codex-a").is_dir()
    for path in world.launchers("codex-a"):
        assert _generated.is_owned(path, "account codex-a")
    before = (world.settings_bytes(), world.launcher_bytes("codex-a"))
    assert add(world) == 0
    assert says(capsys) == ("skip: account codex-a (already done)\n", "")
    assert (world.settings_bytes(), world.launcher_bytes("codex-a")) == before


def test_new_account_stores_a_command_that_is_not_the_stock_cli(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a", "codex", "--command", str(world.custom)) == 0
    assert world.agents()[0]["command"] == str(world.custom)
    assert str(world.custom) in world.launchers("codex-a")[-1].read_text(encoding="utf-8")
    assert add(world, "codex-b", "codex", "--command", str(world.tools / ("codex.cmd" if WINDOWS else "codex"))) == 0
    assert "command" not in world.agents()[1]
    capsys.readouterr()


def test_register_sets_the_command_and_rewrites_the_launchers(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    folder = world.base / "existing"
    folder.mkdir()
    assert account(world, "register", "--id", "codex-a", "--tool", "codex", "--command", str(world.custom), "--config-dir", str(folder)) == 0
    assert says(capsys)[0] == f"Existing account folder kept at {folder}; use 'codex-a' to open it.\n"
    assert world.agents() == [{"id": "codex-a", "tool": "codex", "configDir": str(folder), "command": str(world.custom)}]
    # On an existing account it is the repair path: the stock command is replaced by the registered one.
    other = fake_cli(world.base / "other", "other-codex")
    assert account(world, "register", "--id", "codex-a", "--tool", "codex", "--command", str(other), "--config-dir", str(folder)) == 0
    out = says(capsys)[0].splitlines()
    assert out == [*(f"wrote: launcher {path}" for path in world.launchers("codex-a")), "wrote: command of account codex-a"]
    assert world.agents()[0]["command"] == str(other)
    assert str(other) in world.launchers("codex-a")[-1].read_text(encoding="utf-8")


def test_register_with_the_stock_command_clears_the_stored_command(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    folder = world.base / "existing"
    folder.mkdir()
    assert account(world, "register", "--id", "codex-a", "--tool", "codex", "--command", str(world.custom), "--config-dir", str(folder)) == 0
    stock = world.tools / ("codex.cmd" if WINDOWS else "codex")
    assert account(world, "register", "--id", "codex-a", "--tool", "codex", "--command", str(stock), "--config-dir", str(folder)) == 0
    assert "command" not in world.agents()[0]
    assert str(stock) in world.launchers("codex-a")[-1].read_text(encoding="utf-8")
    capsys.readouterr()


@pytest.mark.parametrize("words", [["--command", "x"], ["--config-dir", "x"]], ids=["no folder", "no command"])
def test_register_needs_a_command_and_a_config_dir(world: World, words: list[str]) -> None:
    assert account(world, "register", "--id", "codex-a", "--tool", "codex", *words) == 2
    assert not (world.home / ".legion").exists()


def test_adopting_an_existing_folder_records_its_full_path(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    folder = world.base / "existing account"
    folder.mkdir()
    (folder / "settings.json").write_text('{"theme":"dark"}', encoding="utf-8")
    assert add(world, "claude-existing", "claude", "--config-dir", str(folder)) == 0
    assert says(capsys)[0] == f"Existing account folder kept at {folder}; use 'claude-existing' to open it.\n"
    assert world.agents() == [{"id": "claude-existing", "tool": "claude", "configDir": str(folder)}]
    assert not world.folder("claude-existing").exists()
    assert str(folder) in world.launchers("claude-existing")[-1].read_text(encoding="utf-8")
    assert (folder / "settings.json").read_text(encoding="utf-8") == '{"theme":"dark"}'
    before = (world.settings_bytes(), world.launcher_bytes("claude-existing"))
    assert add(world, "claude-existing", "claude", "--config-dir", str(folder)) == 0
    assert says(capsys) == ("skip: account claude-existing (already done)\n", "")
    assert (world.settings_bytes(), world.launcher_bytes("claude-existing")) == before


def test_a_relative_or_home_config_dir_is_stored_as_a_full_path(world: World) -> None:
    (world.base / "existing account").mkdir()
    (world.home / "from-home").mkdir()
    assert add(world, "codex-a", "codex", "--config-dir", "./existing account") == 0
    assert add(world, "codex-b", "codex", "--config-dir", "~/from-home") == 0
    assert [entry["configDir"] for entry in world.agents()] == [str(world.base / "existing account"), str(world.home / "from-home")]


def test_a_missing_config_dir_and_a_redirected_id_are_refused(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "claude-a", "claude", "--config-dir", "~/missing") == 1
    assert says(capsys) == ("", OLD_FOLDER + "\n")
    assert not settings_path(world.home).exists()
    assert add(world, "claude-a", "claude") == 0
    before = world.settings_bytes()
    capsys.readouterr()
    assert add(world, "claude-a", "claude", "--config-dir", str(world.base)) == 1
    assert says(capsys) == ("", "account 'claude-a' already exists\n")
    assert world.settings_bytes() == before


def test_the_first_add_starts_the_settings(world: World) -> None:
    assert add(world) == 0
    data = json.loads(settings_path(world.home).read_text(encoding="utf-8"))
    assert (data["schemaVersion"], data["channels"], data["agents"][0]["id"]) == (1, [], "codex-a")


@pytest.mark.parametrize("verb", ["add", "register"])
@pytest.mark.parametrize(("account_id", "tool_id", "message"), [("Bad id", "codex", "id 'Bad id' must match ^[a-z][a-z0-9-]*$"), ("codex-a", "unknown-tool", "unknown tool 'unknown-tool'")])
def test_an_invalid_first_add_creates_no_settings_folder(world: World, capsys: pytest.CaptureFixture[str], verb: str, account_id: str, tool_id: str, message: str) -> None:
    words = ["--command", str(world.custom), "--config-dir", str(world.base)] if verb == "register" else []
    assert account(world, verb, "--id", account_id, "--tool", tool_id, *words) == 1
    assert says(capsys) == ("", message + "\n")
    assert not (world.home / ".legion").exists()


@pytest.mark.parametrize("words", [["rename", "--id", "codex-a", "--new-id", "codex-b"], ["remove", "--id", "codex-a"]])
def test_the_other_verbs_need_settings(world: World, capsys: pytest.CaptureFixture[str], words: list[str]) -> None:
    assert account(world, *words) == 1
    assert says(capsys) == ("", "No legion settings yet; add an agent first.\n")
    assert list(world.home.iterdir()) == []


@pytest.mark.parametrize(
    ("account_id", "message"),
    [("legion", "'legion' is reserved for an owner command"), ("Invalid_id", "id 'Invalid_id' must match ^[a-z][a-z0-9-]*$"), ("taken", "'taken' is already a command")],
)
def test_ids_that_cannot_name_an_account_are_refused(world: World, capsys: pytest.CaptureFixture[str], account_id: str, message: str) -> None:
    assert add(world, "claude-a", "claude") == 0
    before = world.settings_bytes()
    capsys.readouterr()
    assert add(world, account_id, "codex") == 1
    assert says(capsys) == ("", message + "\n")
    assert world.settings_bytes() == before


def test_a_foreign_file_at_a_launcher_path_blocks_before_anything_is_written(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    blocked = bin_folder(world.home) / "blocked"
    blocked.parent.mkdir(parents=True)
    blocked.write_text("owner file\n", encoding="utf-8")
    assert add(world, "blocked", "claude") == 1
    assert says(capsys) == ("", f"wrapper collision '{blocked}'\n")
    assert blocked.read_text(encoding="utf-8") == "owner file\n"
    assert not settings_path(world.home).exists()


def test_a_legion_launcher_left_behind_is_rewritten(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    orphan = bin_folder(world.home) / "orphan"
    orphan.parent.mkdir(parents=True)
    orphan.write_text("#!/bin/sh\n# Generated by legion: account orphan\nexit 9\n", encoding="utf-8")
    assert add(world, "orphan", "claude") == 0
    assert "exit 9" not in orphan.read_text(encoding="utf-8")
    capsys.readouterr()


@pytest.mark.parametrize("by", ["path", "bare name"])
def test_a_command_that_is_the_accounts_own_launcher_is_refused(world: World, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], by: str) -> None:
    own = wrapper_command("recursion", world.home)
    own.parent.mkdir(parents=True)
    own.write_text("anything\n", encoding="utf-8")
    monkeypatch.setattr(_accounts, "POSIX", True)
    real_access = _accounts.os.access
    monkeypatch.setattr(_accounts.os, "access", lambda path, mode: False if Path(path) == own and mode == _accounts.os.X_OK else real_access(path, mode))
    command = str(own) if by == "path" else own.name
    assert add(world, "recursion", "claude", "--command", command) == 1
    assert says(capsys) == ("", "wrapper target would recurse\n")
    assert not settings_path(world.home).exists()


def test_a_missing_command_file_is_refused_in_one_line(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a", "codex", "--command", str(world.base / "gone")) == 1
    assert says(capsys)[1].count("\n") == 1
    assert not settings_path(world.home).exists()


def test_an_old_account_with_intact_launchers_is_left_alone(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    world.old_account()
    before = (world.settings_bytes(), world.launcher_bytes("codex-a"))
    assert add(world) == 0
    assert says(capsys) == ("skip: account codex-a (already done)\n", "")
    assert (world.settings_bytes(), world.launcher_bytes("codex-a")) == before


@pytest.mark.parametrize("custom", [False, True])
def test_repeat_recreates_a_missing_managed_config_folder(world: World, capsys: pytest.CaptureFixture[str], custom: bool) -> None:
    more = ["--command", str(world.custom)] if custom else []
    assert add(world, "codex-a", "codex", *more) == 0
    before = (world.settings_bytes(), world.launcher_bytes("codex-a"))
    world.folder("codex-a").rmdir()
    capsys.readouterr()
    assert add(world) == 0
    assert world.folder("codex-a").is_dir()
    assert says(capsys) == (f"created: config folder {world.folder('codex-a')}\n", "")
    assert (world.settings_bytes(), world.launcher_bytes("codex-a")) == before


def test_repeat_recovers_after_config_folder_creation_failed(world: World, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    mkdir = Path.mkdir

    def fail_config(path: Path, *args: Any, **kwargs: Any) -> None:
        if path == world.folder("codex-a"):
            raise OSError("fixture config creation failed")
        mkdir(path, *args, **kwargs)

    with monkeypatch.context() as patch:
        patch.setattr(Path, "mkdir", fail_config)
        assert add(world) == 1
    assert says(capsys)[1] == "fixture config creation failed\n"
    assert add(world) == 0
    assert world.folder("codex-a").is_dir()
    assert "already done" not in says(capsys)[0]


def test_repeat_still_refuses_a_missing_adopted_folder(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    folder = world.base / "adopted"
    folder.mkdir()
    assert add(world, "codex-a", "codex", "--config-dir", str(folder)) == 0
    folder.rmdir()
    before = world.settings_bytes()
    capsys.readouterr()
    assert add(world, "codex-a", "codex", "--config-dir", str(folder)) == 1
    assert says(capsys) == ("", OLD_FOLDER + "\n")
    assert world.settings_bytes() == before


@pytest.mark.parametrize("interpreted", [False, True])
def test_register_requires_executable_native_posix_target(world: World, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], interpreted: bool) -> None:
    command = world.base / ("custom.ps1" if interpreted else "custom-script")
    command.write_text("exit 3\n", encoding="utf-8")
    command.chmod(0o644)
    # Exercise the POSIX decision here too; actual mode enforcement runs on Linux and macOS.
    monkeypatch.setattr(_accounts, "POSIX", True)
    if WINDOWS:
        real_access = _accounts.os.access
        monkeypatch.setattr(_accounts.os, "access", lambda path, mode: False if Path(path) == command and mode == _accounts.os.X_OK else real_access(path, mode))
    words = ("register", "--id", "codex-a", "--tool", "codex", "--command", str(command), "--config-dir", str(world.base))
    if interpreted:
        assert account(world, *words) == 0
    else:
        assert account(world, *words) == 1
        assert "not executable" in says(capsys)[1]
        assert not settings_path(world.home).exists()


@pytest.mark.parametrize("verb", ["rename", "remove"])
@pytest.mark.parametrize("failure", ["footprints", "launcher", "settings"])
def test_failed_account_change_can_be_retried(world: World, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], verb: str, failure: str) -> None:
    assert add(world) == 0
    assert add(world, "codex-b") == 0
    bind(world, "codex-a", "codex-b")
    runtime = world.home / ".legion" / "runtime"
    runtime.mkdir()
    _footprints.add(world.home, "folder", runtime, "account:codex-a")
    before = world.settings_bytes()
    words = [verb, "--id", "codex-a", *(["--new-id", "codex-new"] if verb == "rename" else [])]
    capsys.readouterr()

    def fail(*_args: Any, **_kwargs: Any) -> None:
        raise OSError("fixture operation failed")

    with monkeypatch.context() as patch:
        if failure == "footprints":
            patch.setattr(_footprints, "lock", fail)
        elif failure == "launcher":
            # Fail after one sibling has been changed on Windows; fail the sole write on POSIX.
            operation = Path.unlink if verb == "remove" else _launchers.write_generated
            calls = 0

            def fail_partway(*args: Any, **kwargs: Any) -> Any:
                nonlocal calls
                if args[0] in world.launchers("codex-a") + world.launchers("codex-new"):
                    calls += 1
                    if calls == (2 if WINDOWS else 1):
                        fail()
                return operation(*args, **kwargs)

            if verb == "remove":
                patch.setattr(Path, "unlink", fail_partway)
            else:
                patch.setattr(_launchers, "write_generated", fail_partway)
        else:
            patch.setattr(_settings_io, "save_locked", fail)
        assert account(world, *words) == 1
    assert "fixture operation failed" in says(capsys)[1]
    assert world.settings_bytes() == before
    assert account(world, *words) == 0
    assert says(capsys)[1] == ""
    assert not any(path.exists() for path in world.launchers("codex-a"))
    assert world.channels()[0]["accounts"] == (["codex-new", "codex-b"] if verb == "rename" else ["codex-b"])
    if verb == "rename":
        assert all(path.exists() for path in world.launchers("codex-new"))
        assert _footprints.read(world.home).entries[0].owners == ["account:codex-new"]
    else:
        assert _footprints.read(world.home).entries == []
        assert not runtime.exists()


@pytest.mark.parametrize("point", ["new_only", "both"])
def test_rename_retries_after_first_launcher_step(world: World, point: str) -> None:
    assert add(world) == 0
    old = world.launchers("codex-a")[0]
    new = world.launchers("codex-new")[0]
    text = old.read_bytes().decode("utf-8").replace("account codex-a", "account codex-new", 1)
    _generated.write_generated(new, text, executable=True)
    if point == "new_only":
        old.unlink()
    before = world.settings_bytes()
    assert account(world, "rename", "--id", "codex-a", "--new-id", "codex-new") == 0
    assert world.settings_bytes() != before
    assert [entry["id"] for entry in world.agents()] == ["codex-new"]
    assert not any(path.exists() for path in world.launchers("codex-a"))
    assert all(_generated.is_owned(path, "account codex-new") for path in world.launchers("codex-new"))


def test_remove_retries_after_runtime_is_gone(world: World) -> None:
    assert add(world) == 0
    runtime = world.home / ".legion" / "runtime"
    runtime.mkdir()
    _footprints.add(world.home, "folder", runtime, "account:codex-a")
    runtime.rmdir()
    world.launchers("codex-a")[0].unlink()
    assert account(world, "remove", "--id", "codex-a") == 0
    assert world.agents() == []
    assert _footprints.read(world.home).entries == []
    assert not any(path.exists() for path in world.launchers("codex-a"))


def test_remove_keeps_runtime_when_launcher_removal_fails(world: World, monkeypatch: pytest.MonkeyPatch) -> None:
    assert add(world) == 0
    runtime = world.home / ".legion" / "runtime"
    runtime.mkdir()
    _footprints.add(world.home, "folder", runtime, "account:codex-a")
    before = world.settings_bytes()
    unlink = Path.unlink

    def fail_launcher(path: Path, *args: Any, **kwargs: Any) -> None:
        if path in world.launchers("codex-a"):
            raise OSError("fixture launcher removal failed")
        unlink(path, *args, **kwargs)

    with monkeypatch.context() as patch:
        patch.setattr(Path, "unlink", fail_launcher)
        assert account(world, "remove", "--id", "codex-a") == 1
    assert runtime.is_dir()
    assert world.settings_bytes() == before
    assert account(world, "remove", "--id", "codex-a") == 0


def test_remove_keeps_last_owner_runtime_when_settings_save_fails(world: World, monkeypatch: pytest.MonkeyPatch) -> None:
    assert add(world) == 0
    runtime = world.home / ".legion" / "runtime"
    runtime.mkdir()
    _footprints.add(world.home, "folder", runtime, "account:codex-a")
    before = world.settings_bytes()

    def fail_save(*_args: object) -> None:
        raise OSError("save failed")

    with monkeypatch.context() as patch:
        patch.setattr(_settings_io, "save_locked", fail_save)
        assert account(world, "remove", "--id", "codex-a") == 1

    assert world.settings_bytes() == before
    assert runtime.is_dir()
    assert _footprints.read(world.home).entries[0].owners == ["account:codex-a"]


def test_remove_validates_remaining_settings_before_deleting_footprints(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world) == 0
    bind(world, "codex-a")
    data = json.loads(world.settings_bytes())
    data["channels"][0]["accounts"].append("unknown-account")
    write_settings(world.home, data)
    runtime = world.home / ".legion" / "runtime"
    runtime.mkdir()
    _footprints.add(world.home, "folder", runtime, "account:codex-a")
    before = (world.settings_bytes(), world.launcher_bytes("codex-a"))
    capsys.readouterr()
    assert account(world, "remove", "--id", "codex-a") == 1
    assert "unknown-account" in says(capsys)[1]
    assert (world.settings_bytes(), world.launcher_bytes("codex-a")) == before
    assert runtime.is_dir()
    assert _footprints.read(world.home).entries[0].owners == ["account:codex-a"]


# Windows has two launchers, so one can survive alone; the stock command cannot tell what that launcher ran.
@windows_only
def test_an_old_account_with_one_launcher_left_needs_register(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    world.old_account()
    world.launchers("codex-a")[0].unlink()
    before = world.settings_bytes()
    assert add(world) == 1
    assert says(capsys) == ("", "target needed: codex-a; ask the owner for the registered executable\n")
    assert world.settings_bytes() == before
    # register names the executable once, and the account is repaired and remembers it.
    assert account(world, "register", "--id", "codex-a", "--tool", "codex", "--command", str(world.custom), "--config-dir", str(world.folder("codex-a"))) == 0
    assert world.agents()[0]["command"] == str(world.custom)
    assert world.launcher_bytes("codex-a")
    assert add(world) == 0
    assert says(capsys)[0].splitlines()[-1] == "skip: account codex-a (already done)"


@posix_only
def test_an_old_account_whose_launcher_lost_execute_permission_is_repaired_in_place(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    world.old_account()
    (path,) = world.launchers("codex-a")
    before = (world.settings_bytes(), path.read_bytes())
    path.chmod(path.stat().st_mode & ~stat.S_IXUSR)
    assert add(world) == 0
    assert says(capsys) == (f"wrote: launcher {path}\n", "")
    assert path.stat().st_mode & stat.S_IXUSR
    assert (world.settings_bytes(), path.read_bytes()) == before
    assert add(world) == 0
    assert says(capsys) == ("skip: account codex-a (already done)\n", "")


def test_an_old_account_with_no_launcher_left_gets_the_stock_cli(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    world.old_account()
    for path in world.launchers("codex-a"):
        path.unlink()
    before = world.settings_bytes()
    assert add(world) == 0
    assert says(capsys) == ("".join(f"wrote: launcher {path}\n" for path in world.launchers("codex-a")), "")
    assert world.settings_bytes() == before


def test_an_account_whose_command_file_is_gone_needs_the_owner(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a", "codex", "--command", str(world.custom)) == 0
    world.custom.unlink()
    capsys.readouterr()
    assert add(world) == 1
    assert says(capsys) == ("", "target needed: codex-a; ask the owner for the registered executable\n")


def bind(world: World, *accounts: str) -> None:
    arguments = ["--home", str(world.home), "channel", "add", "--id", "main", "--kind", "telegram", "--target", "123"]
    for name in accounts:
        arguments += ["--account", name]
    assert run(arguments) == 0


def test_rename_moves_launchers_bindings_and_footprint_owners(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a") == 0
    assert add(world, "codex-b") == 0
    bind(world, "codex-a", "codex-b")
    extra = world.home / ".legion" / "extra"
    extra.mkdir()
    _footprints.add(world.home, "folder", extra, "account:codex-a")
    old_text = world.launcher_bytes("codex-a")
    capsys.readouterr()
    assert account(world, "rename", "--id", "codex-a", "--new-id", "codex-new") == 0
    assert says(capsys) == (f"Config folder kept at {world.folder('codex-a')}; rename it yourself only if you want to.\n", "")
    assert [entry["id"] for entry in world.agents()] == ["codex-new", "codex-b"]
    assert world.channels()[0]["accounts"] == ["codex-new", "codex-b"]
    assert not any(path.exists() for path in world.launchers("codex-a"))
    assert [text.replace(b"account codex-a", b"account codex-new") for text in old_text] == world.launcher_bytes("codex-new")
    assert [entry.owners for entry in _footprints.read(world.home).entries if entry.kind == "folder"] == [["account:codex-new"]]


def test_a_repeated_rename_skips(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world) == 0
    assert account(world, "rename", "--id", "codex-a", "--new-id", "codex-new") == 0
    before = world.settings_bytes()
    capsys.readouterr()
    assert account(world, "rename", "--id", "codex-a", "--new-id", "codex-new") == 0
    assert says(capsys) == ("skip: account rename codex-a to codex-new (already done)\n", "")
    assert world.settings_bytes() == before


def test_rename_refusals_change_nothing(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a") == 0
    assert add(world, "codex-b") == 0
    blocked = bin_folder(world.home) / "codex-c"
    blocked.write_text("owner file\n", encoding="utf-8")
    before = (world.settings_bytes(), world.launcher_bytes("codex-a"))
    capsys.readouterr()
    for old, new, message in (
        ("codex-a", "codex-b", "account 'codex-b' already exists"),
        ("codex-a", "codex-c", f"wrapper collision '{blocked}'"),
        ("codex-a", "Bad_id", "id 'Bad_id' must match ^[a-z][a-z0-9-]*$"),
        ("codex-a", "legion", "'legion' is reserved for an owner command"),
        ("nobody", "codex-d", "unknown account 'nobody'"),
    ):
        assert account(world, "rename", "--id", old, "--new-id", new) == 1
        assert says(capsys) == ("", message + "\n")
    assert (world.settings_bytes(), world.launcher_bytes("codex-a")) == before
    assert blocked.read_text(encoding="utf-8") == "owner file\n"


def test_a_foundry_account_rename_requires_a_ready_app(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    provider = {"kind": "foundry", "endpoint": "https://example.cognitiveservices.azure.com", "default": "a", "deployments": [{"name": "a"}]}
    write_settings(world.home, {"schemaVersion": 1, "agents": [{"id": "claude-f", "tool": "claude", "configDir": "~/f", "provider": provider}], "channels": []})
    before = world.settings_bytes()
    assert account(world, "rename", "--id", "claude-f", "--new-id", "claude-g") == 1
    assert says(capsys) == ("", "the legion app is not ready; run legion setup\n")
    assert world.settings_bytes() == before


def test_remove_refuses_the_last_account_of_a_channel(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a") == 0
    bind(world, "codex-a")
    before = (world.settings_bytes(), world.launcher_bytes("codex-a"))
    capsys.readouterr()
    assert account(world, "remove", "--id", "codex-a") == 1
    assert says(capsys) == ("", "channel 'main' would have no accounts; rebind or remove it first\n")
    assert (world.settings_bytes(), world.launcher_bytes("codex-a")) == before


def test_remove_prunes_the_binding_deletes_the_launchers_and_keeps_the_folder(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a") == 0
    assert add(world, "codex-b") == 0
    bind(world, "codex-a", "codex-b")
    capsys.readouterr()
    assert account(world, "remove", "--id", "codex-a") == 0
    assert says(capsys) == (f"Config folder kept at {world.folder('codex-a')}.\n", "")
    assert [entry["id"] for entry in world.agents()] == ["codex-b"]
    assert world.channels()[0]["accounts"] == ["codex-b"]
    assert not any(path.exists() for path in world.launchers("codex-a"))
    assert world.folder("codex-a").is_dir()
    assert account(world, "remove", "--id", "codex-a") == 0
    assert says(capsys) == ("skip: account remove codex-a (already done)\n", "")


def test_remove_ends_the_footprint_owner_and_an_old_runtime_folder(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a") == 0
    runtime = world.home / ".legion" / "bin" / ".runtime"
    (runtime / "bin").mkdir(parents=True)
    (runtime / "bin" / "legion-foundry.ps1").write_text("old runner\n", encoding="utf-8")
    _footprints.add(world.home, "folder", runtime, "account:codex-a")
    capsys.readouterr()
    assert account(world, "remove", "--id", "codex-a") == 0
    assert says(capsys) == (f"Remove folder: {runtime}\nConfig folder kept at {world.folder('codex-a')}.\n", "")
    assert not runtime.exists()
    assert _footprints.read(world.home).entries == []


def test_the_owner_remove_is_the_same_code_and_takes_a_named_id(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a") == 0
    assert add(world, "codex-b") == 0
    capsys.readouterr()
    assert legion(world, "remove", "--id", "codex-a") == 0
    assert says(capsys) == (f"Config folder kept at {world.folder('codex-a')}.\n", "")
    assert account(world, "remove", "--id", "codex-b") == 0
    assert says(capsys) == (f"Config folder kept at {world.folder('codex-b')}.\n", "")
    assert world.agents() == []


def test_a_positional_id_is_a_usage_error(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world) == 0
    before = world.settings_bytes()
    capsys.readouterr()
    for words in (["remove", "codex-a"], ["account", "remove", "codex-a"], ["account", "rename", "codex-a", "codex-b"], ["account", "add", "codex-a", "--tool", "codex"]):
        assert legion(world, *words) == 2
    assert world.settings_bytes() == before
    assert legion(world, "--help") == 0
    assert "Remove an account (its folder is kept)" in says(capsys)[0]


@contextmanager
def watched_lock() -> Iterator[list[str]]:
    events: list[str] = []
    real_lock, real_read, real_save = _settings_io.FileLock, _settings_io._validate.read_text, _settings_io.save_locked
    held = False

    @contextmanager
    def lock(path: str, timeout: int) -> Iterator[None]:
        nonlocal held
        with real_lock(path, timeout=timeout):
            held = True
            try:
                yield
            finally:
                held = False

    def read(path: Path) -> str:
        events.append("read under lock" if held else "read without lock")
        return real_read(path)

    def save(home: Path, settings: Any) -> None:
        events.append("save under lock" if held else "save without lock")
        real_save(home, settings)

    with pytest.MonkeyPatch.context() as patch:
        patch.setattr(_settings_io, "FileLock", lock)
        patch.setattr(_settings_io._validate, "read_text", read)
        patch.setattr(_settings_io, "save_locked", save)
        yield events


@pytest.mark.parametrize("verb", ["add", "rename", "remove"])
def test_every_change_reads_and_writes_the_settings_under_the_writer_lock(world: World, verb: str, capsys: pytest.CaptureFixture[str]) -> None:
    assert add(world, "codex-a") == 0
    words = {"add": ["add", "--id", "codex-b", "--tool", "codex"], "rename": ["rename", "--id", "codex-a", "--new-id", "codex-b"], "remove": ["remove", "--id", "codex-a"]}[verb]
    with watched_lock() as events:
        assert account(world, *words) == 0
    assert events
    assert all(event.endswith("under lock") for event in events)
    assert "save under lock" in events
    capsys.readouterr()


def test_a_busy_settings_lock_is_one_line_and_changes_nothing(world: World, capsys: pytest.CaptureFixture[str], monkeypatch: pytest.MonkeyPatch) -> None:
    assert add(world, "codex-a") == 0
    before = world.settings_bytes()
    real_lock = _settings_io.FileLock
    capsys.readouterr()
    with FileLock(str(settings_path(world.home)) + ".lock", timeout=0):

        def immediate(path: str, timeout: int) -> FileLock:
            assert timeout == 30
            return real_lock(path, timeout=0)

        monkeypatch.setattr(_settings_io, "FileLock", immediate)
        assert add(world, "codex-b") == 1
    assert says(capsys) == ("", "legion settings are busy; another legion command is still running\n")
    assert world.settings_bytes() == before
    assert not any(path.exists() for path in world.launchers("codex-b"))


# Foundry launchers are still written by PowerShell; they carry the same header, so remove deletes them too.
def test_removing_a_foundry_account_deletes_its_launchers_and_keeps_its_folder(world: World, capsys: pytest.CaptureFixture[str]) -> None:
    provider = {"kind": "foundry", "endpoint": "https://example.cognitiveservices.azure.com", "default": "a", "deployments": [{"name": "a"}]}
    write_settings(world.home, {"schemaVersion": 1, "agents": [{"id": "claude-f", "tool": "claude", "configDir": "~/f", "provider": provider}], "channels": []})
    for path in world.launchers("claude-f"):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            f"{_generated.header('account claude-f', True)}\r\n@pwsh -NoProfile -File x %*\r\n" if path.suffix == ".cmd" else f"#!/bin/sh\n{_generated.header('account claude-f', False)}\nexec x\n",
            encoding="utf-8",
            newline="",
        )
    assert account(world, "remove", "--id", "claude-f") == 0
    assert says(capsys) == ("Config folder kept at ~/f.\n", "")
    assert not any(path.exists() for path in world.launchers("claude-f"))
    assert world.agents() == []
