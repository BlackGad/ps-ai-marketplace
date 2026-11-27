# Uninstall and purge: the tools' own commands run, legion's folders go to a shell, nothing in a tool's files is written.
import sys
from pathlib import Path
from typing import Any

import pytest

from legion.core import _stop_event
from legion.core._settings_models import CatalogTool, ToolsCatalog
from legion.services.installation import (
    _handover,
    _user_path,
    _uv_tool,
    installer as _installer,
)
from app_fakes import FakeUv, make_link
from legion.services.repository import _footprints

CATALOG = ToolsCatalog.model_validate_json((Path(__file__).resolve().parents[3] / "plugins/legion/tools.json").read_bytes())
TOOL_FOLDERS = (".claude", ".codex", ".copilot")


class Recorder:
    def __init__(self) -> None:
        self.steps: list[tuple[str, list[str]]] = []
        self.handed: list[list[Path]] = []
        self.questions: list[str] = []
        self.events: list[str] = []
        self.uv: FakeUv


@pytest.fixture
def recorder(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> Recorder:
    recorder = Recorder()
    # The legion tool is not installed unless a test sets `recorder.uv.installed`; no test reaches the real uv.
    recorder.uv = FakeUv(monkeypatch, tmp_path / "uv bin")
    for entry in CATALOG.tools:
        monkeypatch.delenv(entry.config_env, raising=False)
    monkeypatch.setattr(_installer.shutil, "which", lambda name: name)

    def plugin_state(_entry: CatalogTool, _folder: Path, plugin_id: str = _installer.LEGION_PLUGIN) -> tuple[bool, bool, list[Path], str]:
        installed = plugin_id == _installer.LEGION_PLUGIN
        return installed, installed, [], ""

    monkeypatch.setattr(_installer, "_plugin_state", plugin_state)
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args: True)
    monkeypatch.setattr(_installer, "_marketplace_item", lambda *_args: {})

    def step(entry: CatalogTool, arguments: list[str], _folder: Path, _dry_run: bool, _lines: list[str]) -> None:
        recorder.steps.append((entry.id, arguments))

    def hand_over(folders: list[Path]) -> None:
        recorder.events.append("handover")
        recorder.handed.append(folders)

    monkeypatch.setattr(_installer, "_step", step)
    monkeypatch.setattr(_handover, "start", hand_over)
    return recorder


@pytest.fixture
def answers(monkeypatch: pytest.MonkeyPatch, recorder: Recorder) -> list[bool]:
    given: list[bool] = []

    def confirm(question: str, *_args: Any, **_options: Any) -> bool:
        recorder.questions.append(question)
        return given.pop(0)

    monkeypatch.setattr(_installer.click, "confirm", confirm)
    return given


@pytest.fixture
def home(tmp_path: Path) -> Path:
    for name in TOOL_FOLDERS:
        (tmp_path / name).mkdir()
        (tmp_path / name / "settings.json").write_text('{"enabledPlugins": {"legion@ps-legion-marketplace": true}}', encoding="utf-8")
    for name in ("configuration", "agents"):
        (tmp_path / ".legion" / name).mkdir(parents=True)
    return tmp_path


def run(home: Path, tools: Any = None, **options: Any) -> list[str]:
    return _installer.install(home, tools, uninstall=True, catalog=CATALOG, **options)


def tool_files(home: Path) -> dict[Path, bytes]:
    return {path: path.read_bytes() for name in TOOL_FOLDERS for path in (home / name).iterdir()}


def test_uninstall_runs_each_tools_own_commands_and_writes_no_tool_file(home: Path, recorder: Recorder) -> None:
    before = tool_files(home)
    run(home, yes=True)
    assert recorder.steps == [(entry.id, arguments) for entry in CATALOG.tools for arguments in (entry.plugin.uninstall, entry.plugin.marketplace_remove)]
    assert tool_files(home) == before


def test_declined_knowledge_keeps_a_listed_manual_wiki(home: Path, recorder: Recorder, monkeypatch: pytest.MonkeyPatch) -> None:
    (home / ".legion/configuration/personalisation.json").write_text('{"schemaVersion":1,"agents":[],"channels":[],"knowledgeEnabled":false}', encoding="utf-8")
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_: (True, True, [], ""))
    monkeypatch.setattr(_installer, "_marketplace_item", lambda *_: {"name": "llm-wiki"})
    run(home, yes=True)
    assert recorder.steps == [(entry.id, arguments) for entry in CATALOG.tools for arguments in (entry.plugin.uninstall, entry.plugin.marketplace_remove)]


def test_a_plain_uninstall_deletes_no_legion_folder_and_keeps_the_owners_data(home: Path, recorder: Recorder) -> None:
    lines = run(home, yes=True)
    assert recorder.handed == [[]]
    assert "done: legion is uninstalled" in lines
    assert (home / ".legion" / "configuration").is_dir()
    assert (home / ".legion" / "agents").is_dir()


def test_a_full_uninstall_hands_only_the_legion_tool_to_the_helper_and_never_removes_uv(home: Path, recorder: Recorder) -> None:
    recorder.uv.installed = "1.0.0"
    lines = run(home, yes=True)
    assert recorder.uv.detached == [(["uv", "tool", "uninstall", "legion"], [_stop_event.stop_path(home)])]
    assert recorder.uv.calls == [["tool", "list"], ["tool", "list"]]
    assert "legion command is removed when this command ends" in lines
    assert _stop_event.stop_path(home).is_file()


def test_a_legion_that_will_not_stop_blocks_the_uninstall_before_anything_is_deleted(home: Path, recorder: Recorder, monkeypatch: pytest.MonkeyPatch) -> None:
    recorder.uv.installed = "1.0.0"
    hub = home / ".legion/knowledge"
    hub.mkdir()
    monkeypatch.setattr(_installer.click, "confirm", lambda *_args, **_options: True)
    monkeypatch.setattr(_stop_event, "stop_all", lambda _home: [4242])
    with pytest.raises(_uv_tool.UvToolError, match="process 4242"):
        run(home, yes=True, purge=True)
    assert recorder.handed == []
    assert recorder.uv.detached == []
    assert recorder.steps == []
    assert hub.is_dir()


def test_a_full_uninstall_raises_the_stop_event_before_the_uv_step_and_a_partial_one_does_not(home: Path, recorder: Recorder, monkeypatch: pytest.MonkeyPatch) -> None:
    recorder.uv.installed = "1.0.0"
    raised: list[Path] = []
    monkeypatch.setattr(_stop_event, "stop_all", lambda target: raised.append(target) or [])
    run(home, ["codex"], yes=True)
    assert raised == []
    run(home, yes=True)
    assert raised == [home]


def test_one_tool_alone_leaves_the_legion_tool(home: Path, recorder: Recorder) -> None:
    recorder.uv.installed = "1.0.0"
    run(home, ["claude"], yes=True)
    assert recorder.uv.detached == []


def test_the_installed_legion_tool_alone_is_work_for_a_repeat(home: Path, recorder: Recorder, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args: False)
    for name in ("configuration", "agents"):
        (home / ".legion" / name).rmdir()
    recorder.uv.installed = "1.0.0"
    lines = run(home, yes=True)
    assert "skip: uninstall (already done)" not in lines
    assert recorder.uv.detached == [(["uv", "tool", "uninstall", "legion"], [_stop_event.stop_path(home)])]


@pytest.mark.usefixtures("answers")
def test_a_dry_run_previews_without_asking_running_or_handing_over(home: Path, recorder: Recorder) -> None:
    recorder.uv.installed = "1.0.0"
    lines = run(home, dry_run=True, purge=True)
    assert recorder.questions == []
    assert recorder.steps == []
    assert recorder.handed == []
    assert recorder.uv.detached == []
    assert f"Remove folder: {home / '.legion'}" in lines
    assert _uv_tool.STOP_NOTICE in lines
    assert "uv tool uninstall legion" in lines
    assert not _stop_event.stop_path(home).exists()


def test_a_declined_uninstall_changes_nothing(home: Path, recorder: Recorder, answers: list[bool]) -> None:
    answers.append(False)
    assert "Uninstall cancelled." in run(home)
    assert recorder.steps == []
    assert recorder.handed == []


@pytest.mark.usefixtures("answers")
def test_a_repeat_prints_skip_lines_and_does_not_ask(home: Path, recorder: Recorder, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args: False)
    for name in ("configuration", "agents"):
        (home / ".legion" / name).rmdir()
    lines = run(home)
    assert f"skip: claude plugin in {home / '.claude'} (not installed)" in lines
    assert "skip: uninstall (already done)" in lines
    assert recorder.questions == []
    assert recorder.steps == []
    assert recorder.handed == []


def test_a_tool_that_is_not_installed_is_reported_and_skipped(home: Path, recorder: Recorder, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer.shutil, "which", lambda name: None if name == "claude" else name)
    lines = run(home, yes=True)
    assert "skip: claude (not installed)" in lines
    assert {tool for tool, _arguments in recorder.steps} == {"codex", "copilot"}


def test_one_tool_alone_leaves_legions_folders(home: Path, recorder: Recorder) -> None:
    run(home, ["codex"], yes=True)
    assert {tool for tool, _arguments in recorder.steps} == {"codex"}
    assert recorder.handed == []


def test_purge_hands_over_all_of_the_legion_folder(home: Path, recorder: Recorder) -> None:
    run(home, yes=True, purge=True)
    assert recorder.handed == [[home / ".legion"]]


def test_purge_asks_separately_before_deleting_a_knowledge_hub(home: Path, recorder: Recorder, answers: list[bool]) -> None:
    (home / ".legion" / "knowledge").mkdir()
    answers.extend([True, False])
    run(home, purge=True)
    assert len(recorder.questions) == 2
    assert "knowledge" in recorder.questions[1]
    assert sorted(recorder.handed[0]) == sorted(home / ".legion" / name for name in ("configuration", "agents"))


def test_purge_deletes_the_knowledge_hub_only_on_its_own_yes(home: Path, recorder: Recorder, answers: list[bool]) -> None:
    (home / ".legion" / "knowledge").mkdir()
    answers.append(True)
    run(home, yes=True, purge=True)
    assert recorder.questions == ["Also delete the knowledge hub in ~/.legion/knowledge? [y/N]"]
    assert recorder.handed == [[home / ".legion"]]


@pytest.mark.parametrize("external", [False, True])
def test_purge_of_linked_hub_clears_only_the_pointer_to_the_hub_link(home: Path, recorder: Recorder, answers: list[bool], external: bool) -> None:
    outside = home / "outside"
    outside.mkdir()
    make_link(home / ".legion/knowledge", outside)
    pointer = home / ".config/llm-wiki/config.json"
    pointer.parent.mkdir(parents=True)
    value = outside.as_posix() if external else "~/.legion/knowledge"
    pointer.write_text(f'{{"hub_path":"{value}"}}', encoding="utf-8")
    answers.append(True)
    run(home, yes=True, purge=True)
    assert pointer.exists() is external
    assert outside.is_dir()
    assert recorder.handed == [[home / ".legion"]]


def test_purge_of_a_linked_legion_folder_hands_over_the_link_only(tmp_path: Path, recorder: Recorder, answers: list[bool]) -> None:
    answers.append(False)
    outside = tmp_path / "outside"
    (outside / "knowledge").mkdir(parents=True)
    home = tmp_path / "home"
    home.mkdir()
    make_link(home / ".legion", outside)
    run(home, yes=True, purge=True)
    assert recorder.handed == [[home / ".legion"]]


@pytest.mark.usefixtures("recorder")
def test_purge_needs_every_tool(home: Path) -> None:
    with pytest.raises(_installer.InstallerError, match="purge"):
        run(home, ["codex"], yes=True, purge=True)


def test_uninstall_and_purge_go_on_when_settings_are_invalid(home: Path, recorder: Recorder) -> None:
    (home / ".legion" / "configuration" / "personalisation.json").write_text("{}", encoding="utf-8")
    lines = run(home, yes=True, purge=True)
    assert any(line.startswith("skip: account folders (settings invalid: ") for line in lines)
    assert recorder.handed == [[home / ".legion"]]


def test_the_path_entry_goes_before_the_handover(home: Path, recorder: Recorder, monkeypatch: pytest.MonkeyPatch) -> None:
    def remove(_home: Path, _purge: bool = False, dry_run: bool = False) -> list[str]:
        if not dry_run:
            recorder.events.append("path")
        return ["Remove path entry"]

    monkeypatch.setattr(_user_path, "remove", remove)
    run(home, yes=True)
    assert recorder.events == ["path", "handover"]


@pytest.mark.skipif(sys.platform != "win32", reason="Windows saved PATH")
@pytest.mark.usefixtures("recorder")
def test_a_purge_takes_the_recorded_portable_tool_entry_out_of_the_user_path(home: Path, monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    portable = home / ".legion" / "tools" / "claude"
    saved = tmp_path / "user-path.txt"
    saved.write_text(f"other;{portable}", encoding="utf-8")
    monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(saved))
    monkeypatch.setenv("PATH", "fixture-only")
    _footprints.add(home, "path-entry", "user PATH", "legion", value=str(portable))
    run(home, yes=True, purge=True)
    assert saved.read_text(encoding="utf-8") == "other"


def test_a_plain_uninstall_leaves_a_linked_legion_folder_alone(tmp_path: Path, recorder: Recorder) -> None:
    outside = tmp_path / "outside"
    (outside / "configuration").mkdir(parents=True)
    home = tmp_path / "home"
    home.mkdir()
    make_link(home / ".legion", outside)
    run(home, yes=True)
    assert all(not folders for folders in recorder.handed)
    assert (outside / "configuration").is_dir()


def test_a_second_purge_still_asks_about_a_kept_knowledge_hub(home: Path, recorder: Recorder, answers: list[bool], monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args: False)
    for child in (home / ".legion").iterdir():
        child.rmdir()
    (home / ".legion" / "knowledge").mkdir()
    answers.extend([True, True])
    run(home, purge=True)
    assert len(recorder.questions) == 2
    assert recorder.handed == [[home / ".legion"]]


@pytest.mark.usefixtures("recorder")
def test_a_pending_path_cleanup_alone_is_work(home: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_installer, "_plugin_state", lambda *_args: (False, False, [], ""))
    monkeypatch.setattr(_installer, "_marketplace", lambda *_args: False)
    for name in ("configuration", "agents"):
        (home / ".legion" / name).rmdir()
    monkeypatch.setattr(_user_path, "remove", lambda *_args, **_options: ["Remove path entry"])
    lines = run(home, yes=True)
    assert "skip: uninstall (already done)" not in lines
