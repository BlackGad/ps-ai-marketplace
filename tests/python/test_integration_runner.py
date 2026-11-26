import importlib.util
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest


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


def test_latest_release_chooses_the_highest_numeric_tag(tmp_path: Path) -> None:
    instance = make_runner(tmp_path)
    remote = "https://example.invalid/marketplace"

    def run(argv: list[str]) -> str:
        assert argv == ["git", "ls-remote", "--tags", "--refs", remote, "v*"]
        return "abc\trefs/tags/v0.9.0\nabc\trefs/tags/v0.17.1\nabc\trefs/tags/v0.17.0\nabc\trefs/tags/v1.0.0-rc.1\nabc\trefs/tags/v2.0.0+build\nabc\trefs/tags/v3.0"

    instance.run = run
    assert instance.latest_release(remote) == (0, 17, 1)


@pytest.mark.parametrize("output", ["", "abc\trefs/tags/v1.0.0-rc.1\nabc\trefs/tags/v2.0"])
def test_latest_release_fails_clearly_without_a_release_tag(tmp_path: Path, output: str) -> None:
    instance = make_runner(tmp_path)
    instance.run = lambda _argv: output
    with pytest.raises(AssertionError, match="No published release tags"):
        instance.latest_release("https://example.invalid/marketplace")


@pytest.mark.parametrize(("release_version", "expected"), [((0, 16, 0), "0.17.1"), ((0, 17, 1), "0.17.2")])
def test_stage_candidate_commits_distinct_versions_only_in_the_fixture(tmp_path: Path, release_version: tuple[int, int, int], expected: str) -> None:
    instance = make_runner(tmp_path)
    source = instance.new_repo("source")
    instance.checkout = source
    manifests = ["plugin.json", ".claude-plugin/plugin.json", ".codex-plugin/plugin.json"]
    for name in manifests:
        path = source / "plugins/legion" / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text('{"name":"legion","version":"0.17.0"}', encoding="utf-8")
    instance.run(["git", "-C", str(source), "add", "."])
    instance.run(["git", "-C", str(source), "commit", "--quiet", "-m", "add manifests"])

    candidate = instance.new_repo("candidate")
    release = instance.run(["git", "-C", str(candidate), "rev-parse", "HEAD"])
    assert instance.stage_candidate(candidate, release_version) == expected
    assert instance.run(["git", "-C", str(candidate), "rev-parse", "HEAD^"]) == release
    for name in manifests:
        relative = f"plugins/legion/{name}"
        assert json.loads(instance.run(["git", "-C", str(candidate), "show", f"HEAD:{relative}"]))["version"] == expected
        assert json.loads((source / relative).read_text(encoding="utf-8"))["version"] == "0.17.0"
    assert not instance.run(["git", "-C", str(source), "status", "--porcelain"])


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
        "update-from-latest-release",
        "purge",
    ]


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


def test_codex_inventory_requires_connected_legion_with_status() -> None:
    listed = {"name": "legion", "runtimeStatus": "connected", "tools": {"status": {}, "limits": {}}}
    assert runner.codex_legion_server([{"name": "other", "runtimeStatus": "connected", "tools": {"status": {}}}, listed]) == listed
    assert runner.codex_legion_server([]) is None
    assert runner.codex_legion_server([{**listed, "tools": {"limits": {}}}]) is None
    assert runner.codex_legion_server([{**listed, "runtimeStatus": "failed"}]) is None
