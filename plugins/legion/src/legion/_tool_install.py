# Check, preview and install the CLI tools legion needs. A preview or a refusal changes nothing; an install runs
# only with consent (yes). The recipes come from the tool descriptors and the prerequisite helpers.

import hashlib
import json
import re
import shutil
import sys
import tempfile
import urllib.request
import zipfile
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path
from typing import IO, Optional, Union

from pydantic import BaseModel

from . import _user_path
from ._home import full_path, is_under
from ._plugin import PLUGIN_ROOT
from ._run import run_command
from ._settings_models import BinaryDownload, InstallRecipe, ScriptDownload, ToolDescriptor, Windows
from ._validate import load_descriptors

HELPERS_PATH = PLUGIN_ROOT / "bin" / "install-tool" / "helpers.json"
CHOICE_MESSAGE = "choose --method msi (official installer, needs admin) or --method zip (user folder, no admin)"
# An installer that asks for a restart still installed.
INSTALLER_SUCCESS_CODES = (0, 3010)
PACKAGE_MANAGER_PAGES = {"winget": "https://learn.microsoft.com/windows/package-manager/winget/", "brew": "https://brew.sh/"}
# An opener instead of urlopen: every vendor URL is https, and ruff flags urlopen (S310).
_opener = urllib.request.build_opener(urllib.request.HTTPSHandler)
DOWNLOAD_TIMEOUT_SECONDS = 120


class ToolInstallError(Exception):
    pass


def load_tools() -> list[ToolDescriptor]:
    return load_descriptors(ToolDescriptor, "tool.json")


# Tool descriptors plus the helpers (git, node, az, uv, bun) that have no tool skill.
def find_recipe(tool: str) -> InstallRecipe:
    for descriptor in load_tools():
        if descriptor.id == tool:
            return descriptor.install
    helpers = json.loads(HELPERS_PATH.read_text(encoding="utf-8"))
    if tool not in helpers:
        raise ToolInstallError(f"unknown tool '{tool}'")
    return InstallRecipe.model_validate(helpers[tool])


def command_available(name: str) -> bool:
    return shutil.which(name) is not None


# The version line when the tool's own check passes, "persisted PATH" for a Windows install this shell cannot see yet, else None.
def installed_version(recipe: InstallRecipe) -> Optional[str]:
    name, *arguments = recipe.check
    found = shutil.which(name)
    if found is None:
        # Installers update the saved PATH, while the running shell keeps its old copy.
        if sys.platform == "win32" and _user_path.find_persistent_command(name):
            return "persisted PATH"
        return None
    try:
        result = run_command(found, arguments, timeout=60)
    except OSError:
        return None
    if result.exit_code != 0:
        return None
    lines = result.output.splitlines()
    return lines[0].strip() if lines else ""


def winget_command(winget_id: str) -> list[str]:
    return ["winget", "install", "--id", winget_id, "-e", "--source", "winget", "--accept-source-agreements", "--accept-package-agreements"]


# Windows installs go through winget; the other systems list their commands (none when only docs exist).
def install_commands(recipe: InstallRecipe, platform: str) -> list[list[str]]:
    if platform == "windows":
        return [winget_command(_windows(recipe).winget_id)]
    return (recipe.macos if platform == "macos" else recipe.linux).commands


def _windows(recipe: InstallRecipe) -> Windows:
    if recipe.windows is None:
        raise ToolInstallError("this tool has no Windows install")
    return recipe.windows


# A path inside the tool folder: relative, no `..`, no drive.
def inside(root: Path, relative: str) -> Path:
    relative = relative.replace("\\", "/")
    if relative.startswith("/") or re.match(r"[a-zA-Z]:", relative) or ".." in relative.split("/"):
        raise ToolInstallError("path must be relative and inside the tool folder")
    path = full_path(root / relative)
    if not is_under(path, root, allow_equal=True):
        raise ToolInstallError("path must be inside the tool folder")
    return path


# The portable executable; a `*` in its path picks the newest version folder, comparing numbers as numbers (22.10 after 22.9).
def portable_command(recipe: InstallRecipe, root: Path) -> Optional[Path]:
    relative = _windows(recipe).portable_command
    path = inside(root, relative)
    if "*" not in relative:
        return path
    found = [match for match in root.glob(relative.replace("\\", "/")) if match.is_file()]
    if not found:
        return None
    newest = max(found, key=lambda match: re.sub(r"\d+", lambda number: number[0].zfill(20), match.relative_to(root).as_posix()))
    return inside(root, newest.relative_to(root).as_posix())


@dataclass(frozen=True)
class Download:
    url: str
    sha256: Optional[str]
    kind: str
    arguments: list[str]
    path_folder: str


class Asset(BaseModel):
    name: str
    browser_download_url: str
    digest: Optional[str] = None


class Release(BaseModel):
    assets: list[Asset]


class NodeVersion(BaseModel):
    version: str
    lts: Union[bool, str]


def _file_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for block in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _open(url: str) -> IO[bytes]:
    if not url.startswith("https://"):
        raise ToolInstallError(f"refusing a download that is not https: {url}")
    return _opener.open(url, timeout=DOWNLOAD_TIMEOUT_SECONDS)


class ToolInstaller:
    def __init__(self, home: Path, platform: str, yes: bool, say: Callable[[str], None]) -> None:
        self.home = home
        self.platform = platform
        self.yes = yes
        self.say = say

    def root(self, tool: str) -> Path:
        return self.home / ".legion" / "tools" / tool

    # Run a program with its output shown; returns its exit code. A command that cannot start raises OSError.
    def execute(self, command: list[str]) -> int:
        result = run_command(shutil.which(command[0]) or command[0], command[1:])
        for text in (result.output, result.error):
            if text.strip():
                self.say(text.rstrip())
        return result.exit_code

    def fetch_text(self, url: str) -> str:
        with _open(url) as response:
            return response.read().decode("utf-8-sig")

    def download_file(self, url: str, path: Path) -> None:
        with _open(url) as response, path.open("wb") as file:
            shutil.copyfileobj(response, file)

    # The official download for a method, with its SHA-256 unless the vendor's own script verifies its payload.
    def resolve_download(self, tool: str, method: str) -> Download:
        windows = _windows(find_recipe(tool))
        recipe = windows.download.msi if method == "msi" else windows.download.zip
        if isinstance(recipe, ScriptDownload):
            return Download(recipe.url, None, "script", [], "")
        assert isinstance(recipe, BinaryDownload)
        path_folder = recipe.path_folder or ""
        if recipe.resolver == "release-assets":
            release = Release.model_validate_json(self.fetch_text(str(recipe.metadata_url)))
            pattern = str(recipe.asset_pattern)
            asset = next((asset for asset in release.assets if re.search(pattern, asset.name)), None)
            if asset is None:
                raise ToolInstallError(f"no official {tool} {method} release asset found")
            digest = re.fullmatch(r"sha256:([a-fA-F0-9]{64})", asset.digest or "")
            if digest is None:
                raise ToolInstallError(f"no SHA-256 digest for {asset.name}")
            return Download(asset.browser_download_url, digest[1].lower(), recipe.kind, recipe.arguments, path_folder)
        versions = [NodeVersion.model_validate(item) for item in json.loads(self.fetch_text(str(recipe.metadata_url)))]
        version = next((item.version for item in versions if item.lts), "")
        if not re.fullmatch(r"v\d+\.\d+\.\d+", version):
            raise ToolInstallError(f"no {tool} LTS release found")
        name = str(recipe.asset_name).replace("{version}", version)
        checksums = self.fetch_text(str(recipe.checksum_url).replace("{version}", version))
        match = re.search(r"^([a-fA-F0-9]{64})\s+\*?" + re.escape(name) + r"\s*$", checksums, re.MULTILINE)
        if match is None:
            raise ToolInstallError(f"no SHA-256 checksum for {name}")
        return Download(str(recipe.url).replace("{version}", version), match[1].lower(), recipe.kind, recipe.arguments, path_folder.replace("{version}", version))

    # Unpack a verified archive (when the executable is not there yet) and put its folder on the user PATH.
    def install_zip(self, tool: str, recipe: InstallRecipe, archive: Optional[Path], path_folder: str) -> None:
        root = full_path(self.root(tool))
        folder = inside(root, path_folder)
        command = portable_command(recipe, root)
        if archive is not None and (command is None or not command.is_file()):
            # extractall drops the parts of a name that would climb out of the folder.
            with zipfile.ZipFile(archive) as contents:
                contents.extractall(root)
            command = portable_command(recipe, root)
        if command is None or not command.is_file():
            raise ToolInstallError(f"{tool} executable missing from download")
        if not folder.is_dir():
            raise ToolInstallError(f"executable folder missing for {tool} download")
        _user_path.add(self.home, folder)

    def download_install(self, tool: str, recipe: InstallRecipe, method: str) -> None:
        download = self.resolve_download(tool, method)
        temp_root = self.home / ".legion" / "temp"
        temp_root.mkdir(parents=True, exist_ok=True)
        # The folder and its download go away on success and on failure.
        with tempfile.TemporaryDirectory(dir=temp_root, prefix="install-") as folder:
            file = Path(folder) / f"download.{'ps1' if download.kind == 'script' else download.kind}"
            self.download_file(download.url, file)
            if download.kind != "script" and (download.sha256 is None or _file_hash(file) != download.sha256.lower()):
                raise ToolInstallError(f"hash mismatch for {tool} download")
            if download.kind == "zip":
                self.install_zip(tool, recipe, file, download.path_folder)
            else:
                commands = {
                    "msi": ["msiexec.exe", "/i", str(file)],
                    "exe": [str(file)],
                    # Windows PowerShell 5.1 is on every Windows; the owner needs no PowerShell 7 for a vendor script.
                    "script": ["powershell", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(file)],
                }
                code = self.execute(commands[download.kind] + download.arguments)
                if code not in INSTALLER_SUCCESS_CODES:
                    raise ToolInstallError(f"{tool} installation command exited {code}")
        self.say(f"{tool}: installed; open a new terminal to refresh PATH")

    def run_checked(self, tool: str, command: list[str]) -> None:
        code = self.execute(command)
        if code != 0:
            raise ToolInstallError(f"{tool} installation command exited {code}")

    # Returns the exit code: 0 done, 2 when the owner must choose a Windows method. Other failures raise ToolInstallError.
    def install(self, tool: str, method: Optional[str] = None) -> int:
        recipe = find_recipe(tool)
        if method and self.platform != "windows":
            raise ToolInstallError("--method is Windows only")
        version = installed_version(recipe)
        if version is not None:
            self.say(f"skip: {tool} already installed ({version}) (already done)" if self.yes else f"{tool}: installed {version}")
            return 0
        if self.platform == "windows":
            return self.install_on_windows(tool, recipe, method)
        return self.install_with_commands(tool, recipe)

    def install_on_windows(self, tool: str, recipe: InstallRecipe, method: Optional[str]) -> int:
        windows = _windows(recipe)
        root = full_path(self.root(tool))
        portable = portable_command(recipe, root)
        if portable is not None and portable.is_file():
            if self.yes:
                self.install_zip(tool, recipe, None, portable.parent.relative_to(root).as_posix())
            self.say(f"skip: {tool} already installed (portable) (already done)")
            return 0
        npm = windows.npm_when_available
        if npm is not None and command_available(npm.check):
            self.say(f"{tool}: {' '.join(npm.command)}")
            if self.yes:
                self.run_checked(tool, npm.command)
            return 0
        if method in ("msi", "zip"):
            download = windows.download.msi if method == "msi" else windows.download.zip
            if isinstance(download, ScriptDownload):
                self.say(f"{tool}: powershell -NoProfile -Command irm {download.url} | iex")
            else:
                self.say(f"{tool}: --method {method} (official download)")
            if self.yes:
                self.download_install(tool, recipe, method)
            return 0
        command = winget_command(windows.winget_id)
        self.say(f"{tool}: {' '.join(command)}")
        winget_available = command_available("winget")
        if winget_available and not self.yes:
            return 0
        if winget_available:
            try:
                code = self.execute(command)
                if code == 0:
                    return 0
                self.say(f"winget failed (exit {code}).")
            except OSError:  # A blocked or broken winget needs the same method choice.
                self.say("winget failed to start.")
        else:
            self.say("winget is not available.")
        self.say(CHOICE_MESSAGE)
        return 2

    def install_with_commands(self, tool: str, recipe: InstallRecipe) -> int:
        platform = recipe.macos if self.platform == "macos" else recipe.linux
        self.say(f"{tool}: missing")
        for need in platform.needs:
            if installed_version(find_recipe(need)) is None:
                self.install(need)
                if self.yes and installed_version(find_recipe(need)) is None:
                    raise ToolInstallError(f"{tool} needs {need}; install {need} using the instructions above, then run this again")
        if not platform.commands:
            self.say(f"{tool}: install instructions: {platform.docs}")
            return 0
        for command in platform.commands:
            self.say(f"{tool}: {' '.join(command)}")
        if not self.yes:
            return 0
        manager = platform.commands[0][0]
        if manager in PACKAGE_MANAGER_PAGES and not command_available(manager):
            raise ToolInstallError(f"{manager} is missing; install it from {PACKAGE_MANAGER_PAGES[manager]}, then run this again")
        for command in platform.commands:
            self.run_checked(tool, command)
        after = installed_version(recipe)
        if after is None:
            raise ToolInstallError(f"{tool} is still missing after installation; open a new terminal to refresh PATH, then check again")
        self.say(f"{tool}: installed {after}")
        return 0
