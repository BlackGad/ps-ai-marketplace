# CLI tool installs against fakes: no real winget, npm, installer or download, and no real PATH or registry.
import hashlib
import json
import os
import sys
import zipfile
from collections.abc import Callable
from pathlib import Path
from typing import Any, Optional

import pytest
from cli_runner import run

from legion import _tool_install, _user_path
from legion._footprints import read as read_footprints
from legion._plugin import PLUGIN_ROOT
from legion._settings_models import InstallRecipe, ScriptDownload, ToolDescriptor
from legion._tool_install import ToolInstaller, ToolInstallError

REPO = Path(__file__).resolve().parents[3]
SOURCES: dict[str, Any] = json.loads((REPO / "tests/fixtures/install/sources.json").read_text(encoding="utf-8"))
FOURTH: dict[str, Any] = json.loads((REPO / "tests/fixtures/tools/legion-fourth/tool.json").read_text(encoding="utf-8"))["install"]
CHOICE = "choose --method msi (official installer, needs admin) or --method zip (user folder, no admin)"
HASH = "1" * 64
WINGET_FLAGS = " --source winget --accept-source-agreements --accept-package-agreements"


def recipe(tool: str) -> InstallRecipe:
    return _tool_install.find_recipe(tool)


def fourth(change: Callable[[dict[str, Any]], None] = lambda _data: None) -> InstallRecipe:
    data = json.loads(json.dumps({key: value for key, value in FOURTH.items() if key != "hint"}))
    change(data)
    return InstallRecipe.model_validate(data)


def make_zip(path: Path, files: dict[str, str]) -> str:
    with zipfile.ZipFile(path, "w") as archive:
        for name, text in files.items():
            archive.writestr(name, text)
    return hashlib.sha256(path.read_bytes()).hexdigest()


class Bench:
    def __init__(self, root: Path, monkeypatch: pytest.MonkeyPatch) -> None:
        self.monkeypatch = monkeypatch
        self.root = root
        self.home = root / "home"
        self.home.mkdir()
        self.tools = self.home / ".legion" / "tools"
        self.lines: list[str] = []
        self.commands: list[list[str]] = []
        self.requests: list[str] = []
        self.downloads: list[Path] = []
        self.path_writes: list[str] = []
        self.installed: set[str] = set()
        self.available: set[str] = set()
        self.exit_codes: list[int] = []
        self.launch_error: Optional[OSError] = None
        self.sources: dict[str, Any] = json.loads(json.dumps(SOURCES))
        self.archives: dict[str, Path] = {}
        self.on_execute: Callable[[list[str]], None] = lambda _command: None
        self.user_path_file = root / "user-path.txt"
        self.user_path_file.write_text("%SYSTEMROOT%\\existing", encoding="utf-8")
        monkeypatch.setenv("LEGION_TEST_USER_PATH_FILE", str(self.user_path_file))
        monkeypatch.setattr(_tool_install, "installed_version", self.installed_version)
        monkeypatch.setattr(_tool_install, "command_available", lambda name: name in self.available)
        real_set = _user_path.set_user_path
        monkeypatch.setattr(_user_path, "set_user_path", lambda value: (self.path_writes.append(value), real_set(value))[1])

    def installed_version(self, item: InstallRecipe) -> Optional[str]:
        return "1.2.3" if item.check[0] in self.installed else None

    def installer(self, platform: str = "windows", yes: bool = False) -> ToolInstaller:
        installer = ToolInstaller(self.home, platform, yes, self.lines.append)
        installer.execute = self.execute
        installer.fetch_text = self.fetch_text
        installer.download_file = self.download_file
        return installer

    def run(self, tool: str, platform: str = "windows", yes: bool = False, method: Optional[str] = None) -> int:
        return self.installer(platform, yes).install(tool, method)

    def text(self) -> str:
        return "\n".join(self.lines)

    def execute(self, command: list[str]) -> int:
        self.commands.append(command)
        if self.launch_error:
            raise self.launch_error
        self.on_execute(command)
        return self.exit_codes.pop(0) if self.exit_codes else 0

    def fetch_text(self, url: str) -> str:
        self.requests.append(url)
        if url not in self.sources:
            raise OSError(f"unexpected metadata: {url}")
        source = self.sources[url]
        return source if isinstance(source, str) else json.dumps(source)

    def download_file(self, url: str, path: Path) -> None:
        self.requests.append(url)
        self.downloads.append(path)
        if url in self.archives:
            path.write_bytes(self.archives[url].read_bytes())
        elif url.endswith(("install.ps1", ".exe", ".msi")):
            path.write_text("# inert test installer", encoding="utf-8")
        else:
            raise OSError(f"unexpected test download: {url}")

    def serve_zip(self, files: dict[str, str]) -> str:
        archive = self.root / "served.zip"
        digest = make_zip(archive, files)
        self.archives["https://fixture.test/az.zip"] = archive
        return digest

    def serve(self, digest: str, kind: str, folder: str = "bin") -> None:
        download = _tool_install.Download(url="https://fixture.test/az.zip", sha256=digest, kind=kind, arguments=["/qn", "/norestart"], path_folder=folder)
        self.monkeypatch.setattr(ToolInstaller, "resolve_download", lambda _installer, _tool, _method: download)

    def user_path(self) -> str:
        return self.user_path_file.read_text(encoding="utf-8")


@pytest.fixture
def bench(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Bench:
    return Bench(tmp_path, monkeypatch)


# --- descriptor data ---


def test_recipe_data_comes_from_descriptors_and_helpers() -> None:
    assert recipe("bun").check == ["bun", "--version"]
    assert recipe("uv").check == ["uv", "--version"]
    uv_windows = recipe("uv").windows
    assert uv_windows is not None
    assert uv_windows.winget_id == "astral-sh.uv"
    script = uv_windows.download.zip
    assert isinstance(script, ScriptDownload)
    assert script.url == "https://astral.sh/uv/install.ps1"
    for platform in ("linux", "macos"):
        assert _tool_install.install_commands(recipe("uv"), platform) == [["sh", "-c", "curl -LsSf https://astral.sh/uv/install.sh | sh"]]
    descriptor_tools = {tool.id for tool in _tool_install.load_tools()}
    assert {"claude", "codex", "copilot"} <= descriptor_tools
    assert descriptor_tools.isdisjoint({"git", "node", "az", "uv", "bun"})
    assert PLUGIN_ROOT.joinpath("bin/install-tool/helpers.json").is_file()


def test_unknown_tool_is_refused(bench: Bench) -> None:
    with pytest.raises(ToolInstallError, match="unknown tool 'nope'"):
        bench.run("nope", "linux")


def test_install_commands_per_platform() -> None:
    windows = {
        "git": "winget install --id Git.Git -e",
        "node": "winget install --id OpenJS.NodeJS.LTS -e",
        "claude": "winget install --id Anthropic.ClaudeCode -e",
        "codex": "winget install --id OpenAI.Codex -e",
        "copilot": "winget install --id GitHub.Copilot -e",
        "az": "winget install --id Microsoft.AzureCLI -e",
    }
    macos = {
        "git": "brew install git",
        "node": "brew install node",
        "claude": "bash -c curl -fsSL https://claude.ai/install.sh | bash",
        "codex": "npm install -g @openai/codex",
        "copilot": "npm install -g @github/copilot",
        "az": "brew install azure-cli",
    }
    for tool, command in windows.items():
        assert " ".join(_tool_install.install_commands(recipe(tool), "windows")[0]) == command + WINGET_FLAGS
    for tool, command in macos.items():
        assert " ".join(_tool_install.install_commands(recipe(tool), "macos")[0]) == command
    docs = {"git": "https://git-scm.com/download/linux", "node": "https://nodejs.org/en/download", "az": "https://learn.microsoft.com/cli/azure/install-azure-cli-linux"}
    for tool, link in docs.items():
        assert _tool_install.install_commands(recipe(tool), "linux") == []
        assert recipe(tool).linux.docs == link
    assert recipe("codex").linux.needs == ["node"]
    assert recipe("copilot").linux.needs == ["node"]
    codex_windows = recipe("codex").windows
    assert codex_windows is not None
    assert codex_windows.winget_id == "OpenAI.Codex"


def test_every_descriptor_installs_with_a_noninteractive_winget_command() -> None:
    for tool in ("claude", "codex", "copilot"):
        windows = recipe(tool).windows
        assert windows is not None
        expected = f"winget install --id {windows.winget_id} -e{WINGET_FLAGS}"
        assert " ".join(_tool_install.install_commands(recipe(tool), "windows")[0]) == expected
    assert all(isinstance(tool, ToolDescriptor) for tool in _tool_install.load_tools())


# --- consent: preview executes nothing; yes installs once; a repeat skips ---


@pytest.mark.parametrize("tool", ["bun", "uv"])
def test_preview_then_yes_then_repeat(bench: Bench, tool: str) -> None:
    bench.available = {"curl", "bash", "sh", "brew"}
    bench.on_execute = lambda _command: bench.installed.add(tool)
    assert bench.run(tool, "linux") == 0
    assert bench.commands == []
    assert bench.run(tool, "linux", yes=True) == 0
    assert len(bench.commands) == 1
    assert bench.run(tool, "linux", yes=True) == 0
    assert len(bench.commands) == 1
    assert f"skip: {tool} already installed (1.2.3) (already done)" in bench.lines


def test_installed_tool_without_yes_only_reports_its_version(bench: Bench) -> None:
    bench.installed = {"git"}
    assert bench.run("git", "linux") == 0
    assert bench.lines == ["git: installed 1.2.3"]


def test_preview_names_prerequisite_and_exact_command(bench: Bench) -> None:
    assert bench.run("codex", "linux") == 0
    assert bench.commands == []
    assert "node" in bench.text()
    assert "npm install -g @openai/codex" in bench.text()


def test_prerequisite_runs_before_the_tool_and_a_repeat_skips(bench: Bench) -> None:
    bench.available = {"npm", "brew"}

    def mark(command: list[str]) -> None:
        if "@openai/codex" in command:
            bench.installed.add("codex")

    bench.on_execute = mark
    bench.installed = {"node"}
    assert bench.run("codex", "macos", yes=True) == 0
    assert [" ".join(command) for command in bench.commands] == ["npm install -g @openai/codex"]
    assert bench.run("codex", "windows", yes=True) == 0
    assert len(bench.commands) == 1
    assert "skip: codex already installed" in bench.text()


def test_missing_node_installs_first_in_the_consent_order(bench: Bench) -> None:
    bench.available = {"npm", "brew"}

    def mark(command: list[str]) -> None:
        bench.installed.add("node" if command[0] == "brew" else "codex")

    bench.on_execute = mark
    assert bench.run("codex", "macos", yes=True) == 0
    assert "; ".join(" ".join(command) for command in bench.commands) == "brew install node; npm install -g @openai/codex"


def test_docs_only_tool_prints_its_link_and_runs_nothing(bench: Bench) -> None:
    assert bench.run("git", "linux", yes=True) == 0
    assert bench.commands == []
    assert "https://git-scm.com/download/linux" in bench.text()


def test_docs_only_prerequisite_blocks_the_tool(bench: Bench) -> None:
    with pytest.raises(ToolInstallError, match="codex needs node"):
        bench.run("codex", "linux", yes=True)
    assert bench.commands == []


def test_missing_package_manager_is_named(bench: Bench) -> None:
    with pytest.raises(ToolInstallError, match=r"brew is missing; install it from https://brew\.sh/"):
        bench.run("git", "macos", yes=True)
    assert bench.commands == []


def test_failing_install_command_stops(bench: Bench) -> None:
    bench.available = {"brew"}
    bench.exit_codes = [7]
    with pytest.raises(ToolInstallError, match="git installation command exited 7"):
        bench.run("git", "macos", yes=True)


def test_tool_still_missing_after_install_is_reported(bench: Bench) -> None:
    bench.available = {"brew"}
    with pytest.raises(ToolInstallError, match="git is still missing after installation"):
        bench.run("git", "macos", yes=True)


def test_method_is_windows_only(bench: Bench) -> None:
    with pytest.raises(ToolInstallError, match="--method is Windows only"):
        bench.run("az", "linux", yes=True, method="zip")


# --- the winget exit contract ---


@pytest.mark.parametrize("state", ["missing", "error", "blocked", "ok"])
def test_winget_states(bench: Bench, state: str) -> None:
    if state != "missing":
        bench.available = {"winget"}
    if state == "error":
        bench.exit_codes = [42]
    if state == "blocked":
        bench.launch_error = OSError("fixture launch denied")
    code = bench.run("git", "windows", yes=True)
    assert code == (0 if state == "ok" else 2)
    assert (CHOICE in bench.text()) == (state != "ok")
    if state == "error":
        assert "winget failed (exit 42)" in bench.text()
        assert "winget is not available" not in bench.text()
    if state == "blocked":
        assert "winget failed to start" in bench.text()
    if state == "missing":
        assert "winget is not available" in bench.text()
    if state == "ok":
        assert [" ".join(command) for command in bench.commands] == [f"winget install --id Git.Git -e{WINGET_FLAGS}"]


def test_missing_winget_preview_also_asks_for_a_method(bench: Bench) -> None:
    assert bench.run("git", "windows") == 2
    assert CHOICE in bench.text()
    assert bench.commands == []


def test_working_winget_preview_runs_nothing(bench: Bench) -> None:
    bench.available = {"winget"}
    assert bench.run("git", "windows") == 0
    assert bench.commands == []


@pytest.mark.parametrize("tool", ["claude", "codex"])
def test_explicit_winget_never_switches_to_a_remote_script(bench: Bench, tool: str) -> None:
    assert bench.run(tool, "windows", yes=True, method="winget") == 2
    assert CHOICE in bench.text()
    assert bench.commands == []
    assert bench.requests == []


# --- Windows downloads ---


@pytest.mark.parametrize("tool", ["git", "node", "az", "copilot"])
@pytest.mark.parametrize("method", ["msi", "zip"])
def test_vendor_downloads_resolve_with_a_hash(bench: Bench, tool: str, method: str) -> None:
    folders = {"git": "cmd", "node": "node-v28.1.0-win-x64", "az": "bin", "copilot": ""}
    bench.sources["https://nodejs.org/dist/v28.1.0/SHASUMS256.txt"] = f"{HASH}  node-v28.1.0-x64.msi\n{HASH}  node-v28.1.0-win-x64.zip"
    download = bench.installer().resolve_download(tool, method)
    assert download.sha256 == HASH
    assert download.url.startswith("https://")
    if method == "zip":
        assert download.kind == "zip"
        assert download.path_folder == folders[tool]
    elif tool == "git":
        assert download.kind == "exe"
        assert "/VERYSILENT" in download.arguments
        assert "/CURRENTUSER" in download.arguments
    else:
        assert download.kind == "msi"
        assert "/qn" in download.arguments
    if tool == "node":
        assert "v28.1.0" in download.url


@pytest.mark.parametrize("tool", ["claude", "codex"])
@pytest.mark.parametrize("method", ["msi", "zip"])
def test_agent_cli_downloads_delegate_to_the_vendor_script(bench: Bench, tool: str, method: str) -> None:
    download = bench.installer().resolve_download(tool, method)
    assert download.kind == "script"
    assert download.sha256 is None
    assert download.url.endswith("/install.ps1")


def test_uv_windows_download_is_the_official_script(bench: Bench) -> None:
    assert bench.installer().resolve_download("uv", "zip").url == "https://astral.sh/uv/install.ps1"


def test_missing_vendor_digest_blocks_the_download(bench: Bench) -> None:
    bench.sources["https://api.github.com/repos/Azure/azure-cli/releases/latest"]["assets"][0]["digest"] = ""
    with pytest.raises(ToolInstallError, match="no SHA-256 digest"):
        bench.installer().resolve_download("az", "zip")


def test_explicit_method_preview_has_no_network_and_runs_nothing(bench: Bench) -> None:
    assert bench.run("az", method="zip") == 0
    assert bench.requests == []
    assert bench.commands == []
    assert "az: --method zip (official download)" in bench.text()
    assert bench.run("claude", method="zip") == 0
    assert "irm https://claude.ai/install.ps1 | iex" in bench.text()


def test_verified_archive_extracts_once_and_repeat_writes_nothing(bench: Bench) -> None:
    digest = bench.serve_zip({"bin/az.cmd": "inert fixture, never execute"})
    bench.serve(digest, "zip")
    assert bench.run("az", yes=True, method="zip") == 0
    exe = bench.tools / "az" / "bin" / "az.cmd"
    assert exe.is_file()
    stamp = exe.stat().st_mtime_ns
    requests = len(bench.requests)
    assert bench.run("az", yes=True, method="zip") == 0
    assert len(bench.requests) == requests, "a repeat downloads nothing"
    assert exe.stat().st_mtime_ns == stamp
    assert "skip: az already installed (portable) (already done)" in bench.text()
    assert len(bench.path_writes) == 1
    assert str(exe.parent) in bench.user_path()
    assert bench.user_path().startswith("%SYSTEMROOT%\\existing"), "existing placeholders survive"
    records = [(entry.kind, entry.path, entry.value) for entry in read_footprints(bench.home).entries]
    assert ("path-entry", "user PATH", str(exe.parent)) in records


def test_preview_never_repairs_the_path_and_yes_repairs_it_once(bench: Bench) -> None:
    digest = bench.serve_zip({"bin/az.cmd": "inert"})
    bench.serve(digest, "zip")
    bench.run("az", yes=True, method="zip")
    requests, stamp = len(bench.requests), (bench.tools / "az" / "bin" / "az.cmd").stat().st_mtime_ns
    bench.user_path_file.write_text("C:\\existing", encoding="utf-8")
    bench.run("az", method="zip")
    assert len(bench.path_writes) == 1
    bench.run("az", yes=True, method="zip")
    assert len(bench.path_writes) == 2
    assert len(bench.requests) == requests
    assert (bench.tools / "az" / "bin" / "az.cmd").stat().st_mtime_ns == stamp


def test_expanded_equivalent_path_entry_is_not_duplicated(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    folder = bench.tools / "az" / "bin"
    monkeypatch.setenv("LEGION_TEST_ROOT", str(bench.home / ".legion"))
    bench.user_path_file.write_text(f"%LEGION_TEST_ROOT%{os.sep}tools{os.sep}az{os.sep}bin{os.sep}", encoding="utf-8")
    folder.mkdir(parents=True)
    (folder / "az.cmd").write_text("inert", encoding="utf-8")
    bench.run("az", yes=True, method="zip")
    assert bench.path_writes == []


def test_hash_mismatch_deletes_the_download_and_extracts_nothing(bench: Bench) -> None:
    bench.serve_zip({"bin/az.cmd": "inert"})
    bench.serve("0" * 64, "zip")
    with pytest.raises(ToolInstallError, match=r"^hash mismatch for az download$"):
        bench.run("az", yes=True, method="zip")
    assert not bench.downloads[-1].exists()
    assert not (bench.tools / "az").exists()
    assert bench.commands == []
    assert bench.path_writes == []


def test_archive_without_the_executable_never_updates_the_path(bench: Bench) -> None:
    digest = bench.serve_zip({"bin/readme.txt": "no executable"})
    bench.serve(digest, "zip")
    with pytest.raises(ToolInstallError, match="az executable missing from download"):
        bench.run("az", yes=True, method="zip")
    assert bench.path_writes == []


@pytest.mark.parametrize("kind", ["msi", "exe"])
def test_installer_downloads_run_their_command(bench: Bench, kind: str) -> None:
    digest = bench.serve_zip({"x": "y"})
    bench.serve(digest, kind, folder="")
    assert bench.run("az", yes=True, method="msi") == 0
    command = bench.commands[-1]
    if kind == "msi":
        assert command[:2] == ["msiexec.exe", "/i"]
    else:
        assert command[0].endswith(".exe")
    assert "/qn" in command
    assert not bench.downloads[-1].exists(), "the download is deleted after the run"
    bench.exit_codes = [3010]
    assert bench.run("az", yes=True, method="msi") == 0, "reboot-needed counts as success"
    bench.exit_codes = [5]
    with pytest.raises(ToolInstallError, match="az installation command exited 5"):
        bench.run("az", yes=True, method="msi")
    assert not bench.downloads[-1].exists()


def test_installed_tool_skips_before_any_download(bench: Bench) -> None:
    bench.installed = {"az"}
    assert bench.run("az", yes=True, method="msi") == 0
    assert "skip: az already installed (1.2.3)" in bench.text()
    assert bench.requests == []


def test_copilot_prefers_npm_when_node_is_there(bench: Bench) -> None:
    bench.available = {"node"}
    assert bench.run("copilot", yes=True, method="msi") == 0
    assert bench.run("copilot", yes=True, method="zip") == 0
    assert [" ".join(command) for command in bench.commands] == ["npm install -g @github/copilot"] * 2


def test_vendor_scripts_run_through_powershell_for_both_methods(bench: Bench) -> None:
    for tool in ("claude", "codex"):
        for method in ("msi", "zip"):
            assert bench.run(tool, yes=True, method=method) == 0
    assert len(bench.commands) == 4
    assert all("-File" in command for command in bench.commands)
    assert all("winget" not in " ".join(command) for command in bench.commands)
    assert bench.commands[0][0].lower().startswith("powershell")
    assert not any(path.exists() for path in bench.downloads)
    assert "claude: installed; open a new terminal to refresh PATH" in bench.lines
    assert bench.path_writes == []


# --- synthetic recipes: portable folders and download resolvers ---


def test_portable_glob_compares_numbers_numerically(tmp_path: Path) -> None:
    item = fourth()
    for version in ("fourth-v10", "fourth-v2", "fourth-v9"):
        (tmp_path / version).mkdir()
        (tmp_path / version / "fourth-cli.exe").write_text("", encoding="utf-8")
    assert _tool_install.portable_command(item, tmp_path) == tmp_path / "fourth-v10" / "fourth-cli.exe"
    assert _tool_install.portable_command(fourth(), tmp_path / "empty") is None


def test_portable_node_selects_the_newest_version(tmp_path: Path) -> None:
    for version in ("22.9.0", "22.10.0", "20.99.0"):
        folder = tmp_path / f"node-v{version}-win-x64"
        folder.mkdir()
        (folder / "node.exe").write_text("", encoding="utf-8")
    assert _tool_install.portable_command(recipe("node"), tmp_path) == tmp_path / "node-v22.10.0-win-x64" / "node.exe"


def test_roots_with_brackets_still_glob(tmp_path: Path) -> None:
    root = tmp_path / "home[1]" / "tools"
    (root / "fourth-v3").mkdir(parents=True)
    (root / "fourth-v3" / "fourth-cli.exe").write_text("", encoding="utf-8")
    assert _tool_install.portable_command(fourth(), root) == root / "fourth-v3" / "fourth-cli.exe"


@pytest.mark.parametrize("bad", ["../fourth-sibling/file.exe", "sub/../../fourth-sibling/file.exe", "C:\\outside.exe", "/outside.exe", "\\outside.exe"])
def test_unsafe_tool_paths_are_rejected(tmp_path: Path, bad: str) -> None:
    # The descriptor model refuses these too; the installer checks again before touching the disk.
    with pytest.raises(ToolInstallError, match="path must be relative and inside the tool folder"):
        _tool_install.inside(tmp_path, bad)


def test_unsafe_path_folder_never_extracts_or_writes_the_path(bench: Bench) -> None:
    for bad in ("../fourth-sibling", "sub/../../fourth-sibling", str(bench.root / "outside")):
        with pytest.raises(ToolInstallError):
            bench.installer(yes=True).install_zip("az", recipe("az"), Path("unused.zip"), bad)
    assert not (bench.tools / "az").exists()
    assert bench.path_writes == []


def test_installed_portable_glob_repairs_the_path_once(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_tool_install, "find_recipe", lambda _tool: fourth())
    bench.user_path_file.write_text("existing", encoding="utf-8")
    for version in ("fourth-v10", "fourth-v2"):
        folder = bench.tools / "fourth" / version
        folder.mkdir(parents=True)
        (folder / "fourth-cli.exe").write_text("", encoding="utf-8")
    bench.available = {"winget"}
    bench.run("fourth")
    assert bench.path_writes == []
    bench.run("fourth", yes=True)
    bench.run("fourth", yes=True)
    assert len(bench.path_writes) == 1
    assert str(bench.tools / "fourth" / "fourth-v10") in bench.user_path()
    assert bench.commands == []


def test_release_assets_resolver_reads_the_digest(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(_tool_install, "find_recipe", lambda _tool: fourth())
    download = bench.installer().resolve_download("fourth", "zip")
    assert download.url == "https://fixture.test/fourth.zip"
    assert download.sha256 == HASH
    for digest in (None, "sha256:bad", "sha512:" + HASH):
        bench.sources["https://fixture.test/releases/latest"]["assets"][0]["digest"] = digest
        with pytest.raises(ToolInstallError):
            bench.installer().resolve_download("fourth", "zip")


def test_lts_resolver_keeps_the_leading_v_and_matches_the_file_name(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    def lts(data: dict[str, Any]) -> None:
        data["windows"]["download"]["zip"] = {
            "kind": "zip",
            "resolver": "lts-index",
            "metadataUrl": "https://fixture.test/versions",
            "assetName": "fourth-{version}.zip",
            "url": "https://fixture.test/{version}/fourth-{version}.zip",
            "checksumUrl": "https://fixture.test/{version}/sums",
            "verification": "checksum-file",
            "arguments": [],
            "pathFolder": "fourth-{version}",
        }

    monkeypatch.setattr(_tool_install, "find_recipe", lambda _tool: fourth(lts))
    download = bench.installer().resolve_download("fourth", "zip")
    assert download.url == "https://fixture.test/v42.3.1/fourth-v42.3.1.zip"
    assert download.path_folder == "fourth-v42.3.1"
    assert "https://fixture.test/v42.3.1/sums" in bench.requests
    assert download.sha256 == "3" * 64
    bench.sources["https://fixture.test/v42.3.1/sums"] = ("3" * 64) + "  other.zip"
    with pytest.raises(ToolInstallError, match=r"no SHA-256 checksum for fourth-v42\.3\.1\.zip"):
        bench.installer().resolve_download("fourth", "zip")
    bench.sources["https://fixture.test/versions"] = '[{"version":"v99.0.0","lts":false}]'
    with pytest.raises(ToolInstallError, match=r"^no fourth LTS release found$"):
        bench.installer().resolve_download("fourth", "zip")


def test_vendor_script_alone_has_no_hash_and_bypasses_extraction(bench: Bench, monkeypatch: pytest.MonkeyPatch) -> None:
    def script(data: dict[str, Any]) -> None:
        data["windows"]["download"]["zip"] = {"kind": "script", "url": "https://fixture.test/install.ps1", "verification": "vendor"}

    monkeypatch.setattr(_tool_install, "find_recipe", lambda _tool: fourth(script))
    assert bench.installer().resolve_download("fourth", "zip").sha256 is None
    assert bench.run("fourth", yes=True, method="zip") == 0
    assert len(bench.commands) == 1
    assert "-File" in bench.commands[0]
    assert bench.path_writes == []
    assert not bench.downloads[-1].exists()


# --- detection ---


def fake_cli(folder: Path, name: str, exit_code: int = 0) -> None:
    folder.mkdir(exist_ok=True)
    if sys.platform == "win32":
        (folder / f"{name}.cmd").write_text(f"@echo off\r\necho fixture-version %*\r\nexit /b {exit_code}\r\n", encoding="utf-8")
    else:
        path = folder / name
        path.write_text(f'#!/bin/sh\necho fixture-version "$@"\nexit {exit_code}\n', encoding="utf-8")
        path.chmod(0o755)


def test_detection_runs_the_declared_check(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    fake_cli(tmp_path / "bin", "fourth-cli")
    monkeypatch.setenv("PATH", str(tmp_path / "bin"))
    item = fourth(lambda data: data.update(check=["fourth-cli", "--probe", "space value"]))
    version = _tool_install.installed_version(item)
    assert version is not None
    assert version.startswith("fixture-version")
    assert "space value" in version


def test_a_failing_check_or_a_missing_command_is_not_installed(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    fake_cli(tmp_path / "bin", "fourth-cli", exit_code=7)
    monkeypatch.setenv("PATH", str(tmp_path / "bin"))
    assert _tool_install.installed_version(fourth()) is None
    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    assert _tool_install.installed_version(fourth()) is None


@pytest.mark.skipif(sys.platform != "win32", reason="the saved PATH exists only on Windows")
def test_a_command_only_on_the_saved_path_counts_as_installed(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    fake_cli(tmp_path / "saved", "fourth-cli")
    monkeypatch.setenv("PATH", str(tmp_path / "empty"))
    monkeypatch.setattr(_user_path, "persistent_folders", lambda: [str(tmp_path / "saved")])
    assert _tool_install.installed_version(fourth()) == "persisted PATH"


# --- the saved user PATH ---


def test_user_path_entries_compare_without_case_and_expand_variables(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("LEGION_TEST_FOLDER", "C:\\Tools")
    assert _user_path.has_entry("C:\\a;%LEGION_TEST_FOLDER%\\bin\\", "c:\\tools\\BIN")
    assert not _user_path.has_entry("C:\\a;C:\\b", "C:\\c")
    assert not _user_path.has_entry("", "C:\\c")


def test_adding_to_the_user_path_keeps_the_existing_value(bench: Bench, tmp_path: Path) -> None:
    folder = tmp_path / "tool" / "bin"
    assert _user_path.add(bench.home, folder) is True
    assert bench.user_path() == f"%SYSTEMROOT%\\existing;{folder}"
    assert _user_path.add(bench.home, folder) is False
    assert len(bench.path_writes) == 1
    bench.user_path_file.write_text("", encoding="utf-8")
    _user_path.add(bench.home, folder)
    assert bench.user_path() == str(folder)


# --- the verb ---


def test_the_verb_reports_an_installed_tool(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    bench.installed = {"git"}
    assert run(["--home", str(bench.home), "tool", "install", "--tool", "git"]) == 0
    assert capsys.readouterr().out == "git: installed 1.2.3\n"
    assert run(["--home", str(bench.home), "tool", "install", "--tool", "git", "--yes"]) == 0
    assert capsys.readouterr().out == "skip: git already installed (1.2.3) (already done)\n"


def test_the_verb_refuses_an_unknown_tool_and_a_bad_method(bench: Bench, capsys: pytest.CaptureFixture[str]) -> None:
    assert run(["--home", str(bench.home), "tool", "install", "--tool", "nope"]) == 1
    assert "unknown tool 'nope'" in capsys.readouterr().err
    assert run(["--home", str(bench.home), "tool", "install", "--tool", "git", "--method", "rpm"]) == 2
    assert run(["tool", "install"]) == 2
    capsys.readouterr()


def test_the_verb_exits_with_the_installer_code(bench: Bench, monkeypatch: pytest.MonkeyPatch, capsys: pytest.CaptureFixture[str]) -> None:
    monkeypatch.setattr(_tool_install.ToolInstaller, "install", lambda self, _tool, _method=None: (self.say("choose"), 2)[1])
    assert run(["--home", str(bench.home), "tool", "install", "--tool", "git", "--yes"]) == 2
    assert capsys.readouterr().out == "choose\n"
