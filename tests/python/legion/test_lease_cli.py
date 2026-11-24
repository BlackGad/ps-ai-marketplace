import json
import os
import socket
from pathlib import Path

import pytest

from cli_runner import run
from legion import _lease
from legion._lease import lease_path

DEAD_PID = 99_999_999


def lease_file(repo: Path) -> dict[str, object]:
    return json.loads(lease_path(repo).read_text(encoding="utf-8"))


def test_help_lists_lease_and_its_actions(capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--help"]) == 0
    assert "  lease " in capsys.readouterr().out
    assert run(["lease", "--help"]) == 0
    output = capsys.readouterr().out
    for action in ("take", "status", "release"):
        assert f"  {action} " in output
    assert run(["lease", "take", "--help"]) == 0
    output = capsys.readouterr().out
    for option in ("--repo", "--tool", "--account", "--process-id"):
        assert option in output


def test_status_defaults_to_the_current_folder(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.chdir(tmp_path)
    assert run(["lease", "status"]) == 0
    assert capsys.readouterr().out == "free\n"
    _lease.take(tmp_path, "codex", "codex-a", process_id=os.getpid())
    assert run(["lease", "status"]) == 0
    assert capsys.readouterr().out == "held\n"


def test_take_status_release_round_trip(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    repo = ["--repo", str(tmp_path)]
    owner = ["--process-id", str(os.getpid())]
    assert run(["lease", "take", *repo, "--tool", "codex", "--account", "codex-a", *owner]) == 0
    assert capsys.readouterr().out == "lease taken\n"
    assert lease_file(tmp_path)["account"] == "codex-a"
    assert run(["lease", "take", *repo, "--tool", "codex", "--account", "codex-a", *owner]) == 0
    assert capsys.readouterr().out == "skip: lease take (already done)\n"
    assert run(["lease", "status", *repo]) == 0
    assert capsys.readouterr().out == "held\n"
    assert run(["lease", "release", *repo, *owner]) == 0
    assert capsys.readouterr().out == "lease released\n"
    assert run(["lease", "release", *repo, *owner]) == 0
    assert capsys.readouterr().out == "skip: lease release (already done)\n"
    assert run(["lease", "status", *repo]) == 0
    assert capsys.readouterr().out == "free\n"


def test_take_without_process_id_uses_the_owner_session(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["lease", "take", "--repo", str(tmp_path), "--tool", "claude", "--account", "claude-a"]) == 0
    assert capsys.readouterr().out == "lease taken\n"
    assert lease_file(tmp_path)["pid"] != os.getpid()
    assert run(["lease", "release", "--repo", str(tmp_path)]) == 0
    assert capsys.readouterr().out == "lease released\n"


def test_release_without_a_lock_skips_even_without_an_owner(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    def no_owner() -> None:
        raise LookupError("cannot find the agent session process; pass --process-id explicitly")

    monkeypatch.setattr(_lease, "owner_process", no_owner)
    assert run(["lease", "release", "--repo", str(tmp_path)]) == 0
    assert capsys.readouterr().out == "skip: lease release (already done)\n"


@pytest.mark.parametrize(
    "arguments",
    [
        ["lease"],
        ["lease", "borrow"],
        ["lease", "take"],
        ["lease", "take", "--tool", "codex"],
        ["lease", "take", "--account", "codex-a"],
        ["lease", "take", "--tool", "codex", "--account", "codex-a", "--process-id", "abc"],
        ["lease", "status", "--tool", "codex"],
        ["lease", "status", "--process-id", "1"],
        ["lease", "release", "--process-id", "abc"],
        ["lease", "release", "--tool", "codex"],
        ["lease", "release", "--account", "codex-a"],
    ],
)
def test_invalid_combinations_are_usage_errors(tmp_path: Path, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str], arguments: list[str]) -> None:
    monkeypatch.chdir(tmp_path)
    assert run(arguments) == 2
    output = capsys.readouterr()
    assert output.out == "" or output.out.startswith("Usage:")
    assert not lease_path(tmp_path).exists()


def test_refusals_go_to_stderr_with_exit_1(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    repo = ["--repo", str(tmp_path)]
    assert run(["lease", "take", *repo, "--tool", "codex", "--account", "codex-a", "--process-id", str(DEAD_PID)]) == 1
    assert capsys.readouterr().err == "lease owner process is not running\n"
    assert not lease_path(tmp_path).exists()
    _lease.take(tmp_path, "claude", "claude-a", process_id=os.getpid())
    started = lease_file(tmp_path)["startedAt"]
    assert run(["lease", "take", *repo, "--tool", "codex", "--account", "codex-a", "--process-id", str(os.getppid())]) == 1
    assert capsys.readouterr().err == f"lease held by claude claude-a since {started}\n"
    assert run(["lease", "release", *repo, "--process-id", str(DEAD_PID)]) == 1
    output = capsys.readouterr()
    assert (output.out, output.err) == ("", "lease belongs to another session; cannot release it\n")
    assert lease_path(tmp_path).exists()


# A lock that is not valid UTF-8 is treated like any record that is not a lease: held while young, stale when old.
def test_status_of_a_lock_with_invalid_bytes(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    path = lease_path(tmp_path)
    path.parent.mkdir(parents=True)
    path.write_bytes(b"\x80\xff not utf-8")
    assert run(["lease", "status", "--repo", str(tmp_path)]) == 0
    assert capsys.readouterr().out == "held\n"
    os.utime(path, (0, 0))
    assert run(["lease", "status", "--repo", str(tmp_path)]) == 0
    assert capsys.readouterr().out == "stale\n"
    assert run(["lease", "take", "--repo", str(tmp_path), "--tool", "codex", "--account", "codex-a", "--process-id", str(os.getpid())]) == 0
    assert lease_file(tmp_path)["account"] == "codex-a"


def test_foreign_lease_is_reported_and_kept(tmp_path: Path, capsys: pytest.CaptureFixture[str]) -> None:
    _lease.take(tmp_path, "codex", "codex-a", process_id=os.getpid())
    data = lease_file(tmp_path) | {"host": "fixture-foreign-host"}
    lease_path(tmp_path).write_text(json.dumps(data), encoding="utf-8")
    assert run(["lease", "status", "--repo", str(tmp_path)]) == 0
    assert capsys.readouterr().out == "foreign\n"
    assert run(["lease", "take", "--repo", str(tmp_path), "--tool", "codex", "--account", "codex-a", "--process-id", str(os.getpid())]) == 1
    assert capsys.readouterr().err == "lease from host fixture-foreign-host; ask the owner\n"
    assert socket.gethostname() != "fixture-foreign-host"
