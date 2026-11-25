"""CI-only end-to-end checks against disposable homes and public Legion commands."""

import argparse
import hashlib
import importlib
import json
import os
import queue
import re
import shlex
import shutil
import subprocess
import sys
import threading
import time
import xml.etree.ElementTree as ET
from contextlib import contextmanager
from dataclasses import dataclass
from pathlib import Path
from typing import Any


TOOLS = ("claude", "codex", "copilot")
MARKETPLACE = "BlackGad/ps-legion-marketplace"
ENDPOINT = "https://example-resource.cognitiveservices.azure.com"
WINDOWS = sys.platform == "win32"
CANDIDATE_VERSION = "0.18.0"


def complete(cases: list["Case"], not_tested: dict[str, str]) -> bool:
    return bool(cases) and not not_tested and all(case.result == "passed" for case in cases)


class JsonProcess:
    # Both MCP and the nonbillable client control APIs use newline-delimited JSON.
    def __init__(self, command: list[str], env: dict[str, str], cwd: Path, error: Path) -> None:
        self.error = error.open("w", encoding="utf-8")
        self.process = subprocess.Popen(command, env=env, cwd=cwd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.error, text=True, encoding="utf-8")  # noqa: S603
        self.messages: queue.Queue[dict[str, Any]] = queue.Queue()
        self.pending: list[dict[str, Any]] = []
        self.reader = threading.Thread(target=self.read, daemon=True)
        self.reader.start()

    def read(self) -> None:
        assert self.process.stdout is not None
        for line in self.process.stdout:
            try:
                self.messages.put(json.loads(line))
            except ValueError:
                self.messages.put({"invalid": line})

    def send(self, message: dict[str, Any]) -> None:
        assert self.process.stdin is not None
        self.process.stdin.write(json.dumps(message) + "\n")
        self.process.stdin.flush()

    def receive(self, key: str, value: Any) -> dict[str, Any]:
        for index, message in enumerate(self.pending):
            if message.get(key) == value:
                return self.pending.pop(index)
        deadline = time.monotonic() + 30
        while True:
            message = self.messages.get(timeout=max(0.01, deadline - time.monotonic()))
            if message.get(key) == value:
                return message
            self.pending.append(message)

    def mcp_ready(self, name: str) -> None:
        while True:
            event = self.receive("method", "mcpServer/startupStatus/updated")["params"]
            if event["name"] == name and event["status"] in ("ready", "failed", "cancelled"):
                require(event["status"] == "ready", f"MCP startup failed: {event}")
                return

    def rpc(self, method: str, params: dict[str, Any], request: int) -> dict[str, Any]:
        self.send({"jsonrpc": "2.0", "id": request, "method": method, "params": params})
        message = self.receive("id", request)
        require("result" in message, f"{method}: {message}")
        return message["result"]

    def close(self) -> None:
        assert self.process.stdin is not None
        if not self.process.stdin.closed:
            self.process.stdin.close()
        try:
            self.process.wait(timeout=10)
        finally:
            if self.process.poll() is None:
                self.process.kill()
                self.process.wait(timeout=5)
            self.reader.join(timeout=5)
            assert self.process.stdout is not None
            self.process.stdout.close()
            self.error.close()


@dataclass
class Case:
    name: str
    repeat: bool
    result: str
    seconds: float
    message: str
    log: str

    @property
    def title(self) -> str:
        return self.name + (" (repeat)" if self.repeat else "")


def listed(entry: dict[str, Any], output: str, include_disabled: bool = False, kind: str = "plugin") -> bool:
    """Read CLI listings using the formats advertised by tools.json."""
    # Hand-built, reason: the three public CLIs expose different listing formats described by tools.json.
    if not output.strip():
        return False
    listing = entry["plugin"]["marketplaceListing" if kind == "marketplace" else "listing"]
    if listing["format"] == "json":
        items = json.loads(output)
        if "collectionField" in listing:
            items = items[listing["collectionField"]]
        wanted = "ps-legion-marketplace" if kind == "marketplace" else "legion@ps-legion-marketplace"
        for item in items:
            if item.get(listing.get("nameField", listing.get("idField"))) == wanted:
                return include_disabled or kind == "marketplace" or item.get(listing["enabledField"]) is True
        return False
    matches = [line for line in output.splitlines() if re.search(r"legion@ps-legion-marketplace(?![\w-])", line) and "not installed" not in line]
    return bool(matches) if include_disabled else any(not re.search(listing["rejectPattern"], line) for line in matches)


def write_report(out: Path, system: str, cases: list[Case], probe: list[str], extra: str = "") -> None:
    """Write the JUnit, benchmark and Markdown artifacts consumed by CI."""
    # Hand-built, reason: the benchmark action needs the existing custom JSON shape alongside JUnit and a readable summary.
    out.mkdir(parents=True, exist_ok=True)
    suite = ET.Element(
        "testsuite",
        name=f"integration.{system}",
        tests=str(len(cases)),
        failures=str(sum(c.result == "failed" for c in cases)),
        skipped=str(sum(c.result == "skipped" for c in cases)),
        time=f"{sum(c.seconds for c in cases):.3f}",
    )
    for case in cases:
        element = ET.SubElement(suite, "testcase", classname=f"integration.{system}", name=case.title, time=f"{case.seconds:.3f}")
        if case.result != "passed":
            # Hand-built, reason: JUnit XML 1.0 cannot represent terminal control sequences.
            clean = re.sub(r"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1b]*(?:\x07|\x1b\\)|[ -/]*[0-~])", "", case.message)
            clean = re.sub(r"[^\x09\x0a\x0d\x20-\ud7ff\ue000-\ufffd]", "", clean)
            ET.SubElement(element, "failure" if case.result == "failed" else "skipped", message=clean)
    ET.indent(suite)
    ET.ElementTree(suite).write(out / f"integration-{system}.xml", encoding="utf-8", xml_declaration=True)
    benchmark = []
    for case in cases:
        if case.result == "passed":
            entry: dict[str, Any] = {"name": f"{system} / {case.title}", "unit": "s", "value": case.seconds}
            if extra and not case.repeat:
                entry["extra"] = extra
            benchmark.append(entry)
    (out / f"integration-bench-{system}.json").write_text(json.dumps(benchmark, indent=2) + "\n", encoding="utf-8")
    lines = [f"## Integration ({system})", "", "### Probe", "", *(f"- {item}" for item in probe), "", "| step | first s | repeat s | result |", "| --- | --- | --- | --- |"]
    for first, repeat in zip(cases[::2], cases[1::2], strict=True):
        result = repeat.result if first.result == "passed" else first.result
        lines.append(f"| {first.name} | {first.seconds:.3f} | {repeat.seconds:.3f} | {result} |")
    notes = [f"- `{case.title}` {case.result}: {(case.message.splitlines() or [''])[0]}" for case in cases if case.result != "passed"]
    if notes:
        lines.extend(["", "### Details", "", *notes])
    summary = "\n".join(lines) + "\n"
    (out / "summary.md").write_text(summary, encoding="utf-8")
    if path := os.environ.get("GITHUB_STEP_SUMMARY"):
        with Path(path).open("a", encoding="utf-8") as stream:
            stream.write(summary)


def without_marketplace_timestamps(data: bytes) -> bytes:
    """Drop the per-marketplace lastUpdated that the Claude CLI rewrites on every marketplace update; the rest is compared as normalized JSON (key order and spacing ignored)."""
    # Hand-built, reason: only this CLI-maintained field is volatile, so source, path and entry changes must still show.
    try:
        entries = json.loads(data)
    except ValueError:
        return data
    if not isinstance(entries, dict) or not all(isinstance(entry, dict) for entry in entries.values()):
        return data
    return json.dumps({name: {key: value for key, value in entry.items() if key != "lastUpdated"} for name, entry in entries.items()}, sort_keys=True).encode()


def snapshot(root: Path, excludes: list[str] | None = None, ignore_timestamps: list[str] | None = None) -> dict[str, str]:
    """Hash a tree so a repeat can name changed paths."""
    # Hand-built, reason: a path-by-path hash names unexpected repeat changes and excludes observed CLI runtime files.
    result = {}
    for path in root.rglob("*"):
        relative = path.relative_to(root).as_posix()
        if any(re.fullmatch(pattern, relative) for pattern in excludes or []):
            continue
        if path.is_dir():
            result[relative] = "directory"
        else:
            data = path.read_bytes()
            result[relative] = hashlib.sha256(without_marketplace_timestamps(data) if relative in (ignore_timestamps or []) else data).hexdigest()
    return result


def unchanged(before: dict[str, str], after: dict[str, str]) -> None:
    changes = [f"{'added' if name not in before else 'removed' if name not in after else 'changed'}: {name}" for name in sorted(before.keys() | after.keys()) if before.get(name) != after.get(name)]
    if changes:
        omitted = f"\n{len(changes) - 20} more paths omitted" if len(changes) > 20 else ""
        raise AssertionError("the home changed on the repeat run:\n" + "\n".join(changes[:20]) + omitted)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def contains(output: str, expected: str) -> None:
    require(expected in output, f"expected {expected!r} in output:\n{output}")


@contextmanager
def restore_user_path():
    """Restore the Windows user PATH if an external CLI installer changes it."""
    # Hand-built, reason: winreg is the standard library API that preserves both the raw value and registry type.
    if sys.platform != "win32":
        yield
        return
    winreg = importlib.import_module("winreg")
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, "Environment", 0, winreg.KEY_QUERY_VALUE | winreg.KEY_SET_VALUE) as key:
        try:
            before = winreg.QueryValueEx(key, "Path")
        except FileNotFoundError:
            before = None
        try:
            yield
        finally:
            try:
                after = winreg.QueryValueEx(key, "Path")
            except FileNotFoundError:
                after = None
            if after != before:
                if before is None:
                    winreg.DeleteValue(key, "Path")
                else:
                    winreg.SetValueEx(key, "Path", 0, before[1], before[0])
                try:
                    restored = winreg.QueryValueEx(key, "Path")
                except FileNotFoundError:
                    restored = None
                require(restored == before, "Windows user PATH was not restored")


def windows_saved_path_folders() -> list[Path]:
    """Find folders added by an installer after this process started."""
    # Hand-built, reason: winget saves PATH in the registry, while the CI process keeps its old copy.
    winreg = importlib.import_module("winreg")
    folders = []
    for root, key_name in ((winreg.HKEY_CURRENT_USER, "Environment"), (winreg.HKEY_LOCAL_MACHINE, r"SYSTEM\CurrentControlSet\Control\Session Manager\Environment")):
        try:
            with winreg.OpenKey(root, key_name) as key:
                value = str(winreg.QueryValueEx(key, "Path")[0])
        except FileNotFoundError:
            continue
        folders.extend(Path(os.path.expandvars(part.strip().strip('"'))) for part in value.split(";") if part.strip())
    return folders


class Runner:
    def __init__(self, checkout: Path, home: Path, out: Path, fallback: bool) -> None:
        self.checkout, self.home, self.out, self.fallback = checkout, home, out, fallback
        self.work = home.parent / "legion-work"
        self.work.mkdir(parents=True, exist_ok=True)
        self.home.mkdir(parents=True, exist_ok=True)
        self.catalog = {entry["id"]: entry for entry in json.loads((checkout / "plugins/legion/tools.json").read_text(encoding="utf-8"))["tools"]}
        self.targets: dict[str, tuple[str, str]] = {}
        self.not_tested: dict[str, str] = {}
        self.versions: dict[str, tuple[str, str]] = {}
        self.state: dict[str, Any] = {}
        self.log: list[str] = []
        self.env = os.environ.copy()
        # Installed-command checks must not import the maintainer's checkout or use a real account.
        for name in list(self.env):
            if name.startswith(("PYTHON", "UV_PROJECT", "LEGION_", "CODEX_", "CLAUDE_", "COPILOT_", "ANTHROPIC_", "OPENAI_", "AZURE_")) or name in ("GH_TOKEN", "GITHUB_TOKEN"):
                self.env.pop(name)
        temp = self.work / "temp"
        temp.mkdir(exist_ok=True)
        self.env.update(
            {
                "HOME": str(home),
                "USERPROFILE": str(home),
                "NO_COLOR": "1",
                "LEGION_TEST_USER_PATH_FILE": str(self.work / "user-path.txt"),
                "UV_CACHE_DIR": str(self.work / "uv-cache"),
                "UV_PYTHON_INSTALL_DIR": str(home / ".legion/managed-python"),
                "UV_TOOL_DIR": str(home / ".legion/uv-tools"),
                "GIT_CONFIG_GLOBAL": str(home / ".gitconfig"),
                "GIT_CONFIG_NOSYSTEM": "1",
                "NPM_CONFIG_USERCONFIG": str(home / ".npmrc"),
                "NPM_CONFIG_PREFIX": str(home / ".local"),
                "TMP": str(temp),
                "TEMP": str(temp),
                "TMPDIR": str(temp),
                "PYTHONDONTWRITEBYTECODE": "1",
                "DISABLE_AUTOUPDATER": "1",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1",
                "DISABLE_TELEMETRY": "1",
            }
        )
        for name in ("APPDATA", "LOCALAPPDATA", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME"):
            folder = home / name
            folder.mkdir(exist_ok=True)
            self.env[name] = str(folder)
        self.base_path = self.env["PATH"]
        (self.work / "user-path.txt").touch(exist_ok=True)
        for tool in TOOLS:
            self.env[self.catalog[tool]["configEnv"]] = str(self.folder(tool))

    def folder(self, tool: str) -> Path:
        value = self.catalog[tool]["plugin"]["defaultConfigDir"]
        return self.home / value[2:] if value.startswith("~/") else Path(value)

    def command(self, name: str) -> str:
        path = shutil.which(name, path=self.env["PATH"])
        if path:
            return path
        candidates = [self.home / ".local/bin", self.home / ".legion/bin"]
        if sys.platform == "win32":
            candidates += [Path(folder) for folder in (self.work / "user-path.txt").read_text(encoding="utf-8").split(";") if folder]
            candidates += windows_saved_path_folders()
        for folder in candidates:
            if folder.is_dir():
                if str(folder) not in self.base_path.split(os.pathsep):
                    self.base_path += os.pathsep + str(folder)
                if str(folder) not in self.env["PATH"].split(os.pathsep):
                    self.env["PATH"] += os.pathsep + str(folder)
        path = shutil.which(name, path=self.env["PATH"])
        if path is None:
            raise AssertionError(f"{name} was not found on PATH after install")
        return path

    def run(self, argv: list[str], *, env: dict[str, str] | None = None, cwd: Path | None = None, check: bool = True) -> str:
        result = subprocess.run(  # noqa: S603
            argv, cwd=cwd or self.work, env=env or self.env, text=True, encoding="utf-8", stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL, timeout=300, check=False
        )
        output = result.stdout.rstrip()
        self.log.append(output)
        if check and result.returncode:
            raise RuntimeError(f"{Path(argv[0]).name} exited {result.returncode}\n{output}")
        return output

    def legion(self, *args: str, owner: bool = False) -> str:
        if owner:
            return self.run([str(self.launcher("legion")), *args])
        env = self.env.copy()
        env["UV_PROJECT_ENVIRONMENT"] = str(self.work / "python-env")
        return self.run([self.command("uv"), "run", "--project", str(self.checkout / "plugins/legion"), "--frozen", "--quiet", "legion", "--home", str(self.home), *args], env=env)

    def launcher(self, name: str) -> Path:
        return self.home / ".legion/bin" / (name + ".cmd" if sys.platform == "win32" else name)

    def cli(self, tool: str, args: list[str], folder: Path | None = None) -> str:
        entry = self.catalog[tool]
        env = self.env.copy()
        env[entry["configEnv"]] = str(folder or self.folder(tool))
        env.update(entry["plugin"].get("listingEnv", {}))
        return self.run([self.command(entry["command"]), *args], env=env, cwd=self.work)

    def listing(self, tool: str, folder: Path, kind: str = "plugin", include_disabled: bool = False) -> bool:
        args = self.catalog[tool]["plugin"]["marketplaceList" if kind == "marketplace" else "list"]
        return listed(self.catalog[tool], self.cli(tool, args, folder), include_disabled, kind)

    def version(self, tool: str, folder: Path) -> str | None:
        # Hand-built, reason: read installed public manifests without the removed installer helper.
        entry = self.catalog[tool]
        root = entry["plugin"].get("installedRoot")
        files = list((folder / root).rglob("plugin.json")) if root and (folder / root).exists() else []
        if tool == "copilot":
            try:
                settings = json.loads((folder / "settings.json").read_text(encoding="utf-8"))
                marketplace = settings["extraKnownMarketplaces"]["ps-legion-marketplace"]
                if settings["enabledPlugins"].get("legion@ps-legion-marketplace") is not True:
                    return None
                if marketplace["source"]["source"] == "directory":
                    source = marketplace["source"]["path"]
                    manifest = json.loads((Path(source) / ".claude-plugin/marketplace.json").read_text(encoding="utf-8"))
                    files = [Path(source) / plugin["source"] / "plugin.json" for plugin in manifest["plugins"] if plugin["name"] == "legion"]
            except (OSError, KeyError, ValueError):
                pass
        versions = []
        for file in files:
            try:
                data = json.loads(file.read_text(encoding="utf-8-sig"))
                if data.get("name") == "legion":
                    versions.append(data["version"])
            except (OSError, ValueError, KeyError):
                pass
        return max(versions, key=lambda value: tuple(int(part) for part in value.split(".")[:3]), default=None)

    def installed_source_matches(self, tool: str, folder: Path) -> bool:
        expected = (self.checkout / "plugins/legion/src/legion/services/installation/_installed_runtime.py").read_bytes()
        if tool == "copilot":
            try:
                settings = json.loads((folder / "settings.json").read_text(encoding="utf-8"))
                source = settings["extraKnownMarketplaces"]["ps-legion-marketplace"]["source"]
                if self.targets[tool][1] == "main":
                    return source["source"] != "directory" and MARKETPLACE.lower() in json.dumps(source).lower()
                return source["source"] == "directory" and Path(source["path"]).resolve() == self.checkout.resolve()
            except (OSError, KeyError, ValueError):
                return False
        installed_root = self.catalog[tool]["plugin"].get("installedRoot")
        if not installed_root or not (folder / installed_root).is_dir():
            return False
        files = []
        for manifest in (folder / installed_root).rglob("plugin.json"):
            if manifest.parent.name in (".codex-plugin", ".claude-plugin"):
                continue
            try:
                if json.loads(manifest.read_text(encoding="utf-8-sig")).get("name") == "legion":
                    files.append(manifest.parent / "src/legion/services/installation/_installed_runtime.py")
            except (OSError, ValueError):
                continue
        return bool(files) and all(path.is_file() and path.read_bytes() == expected for path in files)

    def settings(self) -> dict[str, Any]:
        return json.loads((self.home / ".legion/configuration/personalisation.json").read_text(encoding="utf-8"))

    def active(self) -> list[str]:
        return [tool for tool in TOOLS if tool not in self.not_tested]

    def home_snapshot(self, update: bool = False) -> dict[str, str]:
        runtime = {"claude": [], "codex": ["tmp", r"tmp/arg0-(windows|linux|macos)(/codex-arg0[^/]+(/.*)?)?"], "copilot": ["logs", r"logs/process-[0-9]+-[0-9]+\.log"]}
        folders = [(tool, self.folder(tool)) for tool in TOOLS]
        if (self.home / ".legion/configuration/personalisation.json").exists():
            folders += [(agent["tool"], self.resolve_folder(agent.get("configDir", ""))) for agent in self.settings()["agents"]]
        # Hand-built, reason: CLI runtime caches in HOME are unrelated to Legion repeat behavior.
        result = {}
        legion = self.home / ".legion"
        nested = [re.escape(folder.relative_to(legion).as_posix()) + r"/.*" for _, folder in folders if folder.is_relative_to(legion) and folder != legion]
        for path in [legion, *(folder for _, folder in folders)]:
            if path.is_dir() and path.is_relative_to(self.home):
                prefix = path.relative_to(self.home).as_posix()
                tool = next((tool for tool, folder in folders if folder == path), None)
                if path == legion:
                    excludes = nested
                elif tool:
                    excludes = runtime[tool]
                else:
                    excludes = []
                ignore_timestamps = ["plugins/known_marketplaces.json"] if update and tool == "claude" else []
                for name, value in snapshot(path, excludes, ignore_timestamps).items():
                    result[prefix + "/" + name] = value
        for name in (".zshrc", ".bashrc", ".profile"):
            path = self.home / name
            if path.is_file():
                result[name] = hashlib.sha256(path.read_bytes()).hexdigest()
        return result

    def resolve_folder(self, value: str) -> Path:
        return self.home / value[2:] if value.startswith("~/") else Path(value)

    def install_tool(self, tool: str) -> str:
        args = ("tool", "install", "--tool", tool, "--yes")
        try:
            return self.legion(*args)
        except RuntimeError as error:
            if not WINDOWS or not re.search(r"\bexited 2(?:\n|$)", str(error)):
                raise
            return self.legion(*args, "--method", "zip")

    def install_cli(self, tool: str, repeat: bool) -> str:
        output = self.install_tool(tool)
        if repeat:
            contains(output, "skip:")
        command = self.command(self.catalog[tool]["command"])
        version_output = self.run([command, "--version"])
        match = re.search(r"\d+\.\d+\.\d+(?:-[A-Za-z0-9.-]+)?", version_output)
        if match is None:
            raise AssertionError(f"{tool} --version has no version token: {version_output}")
        value = (match.group(), command)
        if repeat:
            require(value == self.versions[tool], f"{tool} version or executable changed on repeat: {self.versions[tool]} -> {value}")
        else:
            self.versions[tool] = value
        return output + "\n" + version_output

    def bootstrap(self, repeat: bool) -> str:
        if sys.platform == "win32":
            output = self.run(["powershell.exe", "-NoProfile", "-File", str(self.checkout / "install.ps1"), "-Yes", "-HomeRoot", str(self.home)])
        else:
            output = self.run(["sh", str(self.checkout / "install.sh"), "--yes"])
        contains(output, "skip: uv (already done)")
        uv = self.home / ".legion/bin" / ("uv.exe" if sys.platform == "win32" else "uv")
        require(uv.is_file(), f"bootstrap did not install uv at {uv}")
        return output + "\n" + self.run([str(uv), "--version"])

    def install_legion(self, tool: str) -> str:
        source, ref = self.targets.get(tool, (str(self.checkout), "release"))
        args = ["install", "--tool", tool, "--source", source, "--yes"]
        if ref == "main":
            args += ["--ref", "main"]
        return self.legion(*args)

    def install_first(self) -> str:
        lines, errors = [], []
        for tool in TOOLS:
            try:
                lines.append(self.install_legion(tool))
                self.targets[tool] = (str(self.checkout), "release")
            except RuntimeError as error:
                message = str(error)
                command = self.catalog[tool]["command"]
                # Hand-built, reason: only a CLI's own local-source refusal may be skipped or retried from main.
                refusal = re.search(
                    r"(local (path|folder|directory|source|marketplace)|filesystem|directory source).{0,80}(not supported|unsupported|not allowed|not permitted|cannot|refus|rejected)",
                    message,
                    re.IGNORECASE,
                )
                if not (re.search(rf"\b{re.escape(command)} exited \d+", message) and refusal):
                    errors.append(f"{tool}: {message}")
                    continue
                if not self.fallback:
                    self.not_tested[tool] = f"{tool} refuses a local folder and was not tested from the checkout: {message.splitlines()[0]}"
                    lines.append("skip: " + self.not_tested[tool])
                    continue
                revision = self.run(["git", "-C", str(self.checkout), "rev-parse", "HEAD"])
                remote = self.run(["git", "-C", str(self.checkout), "ls-remote", "origin", "refs/heads/main"]).split()[0]
                require(remote == revision, f"{tool} needs published source but main differs: checkout {revision}, main {remote}")
                self.targets[tool] = (MARKETPLACE, "main")
                lines.append(self.install_legion(tool))
                later = self.run(["git", "-C", str(self.checkout), "ls-remote", "origin", "refs/heads/main"]).split()[0]
                require(later == revision, f"main moved during install: {revision} -> {later}")
        require(not errors, "\n".join(errors))
        require(bool(self.active()), "; ".join(self.not_tested.values()))
        expected = json.loads((self.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
        for tool in self.active():
            require(self.listing(tool, self.folder(tool)), f"{tool} does not list enabled legion")
            control = self.work / f"control-{tool}"
            control.mkdir(exist_ok=True)
            require(not self.listing(tool, control, include_disabled=True), f"{tool} lists legion in empty control folder")
            require(self.version(tool, self.folder(tool)) == expected, f"{tool} plugin version is wrong")
        self.state["snapshot"] = self.home_snapshot()
        return "\n".join(lines)

    def install_repeat(self) -> str:
        lines = "\n".join(self.install_legion(tool) for tool in self.active())
        contains(lines, "skip:")
        unchanged(self.state["snapshot"], self.home_snapshot())
        return lines

    def stage_candidate(self) -> Path:
        candidate = self.work / "candidate"
        require(not candidate.exists(), "candidate staging must be fresh")
        files = self.run(["git", "-C", str(self.checkout), "ls-files", "-z"]).split("\0")
        for name in filter(None, files):
            source = self.checkout / name
            require(source.resolve().is_relative_to(self.checkout.resolve()), "candidate source escaped checkout")
            target = candidate / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        for name in ("plugin.json", ".claude-plugin/plugin.json", ".codex-plugin/plugin.json"):
            path = candidate / "plugins/legion" / name
            document = json.loads(path.read_text(encoding="utf-8"))
            require(document["version"] != CANDIDATE_VERSION, "candidate must differ from the committed version")
            document["version"] = CANDIDATE_VERSION
            path.write_text(json.dumps(document, indent=2) + "\n", encoding="utf-8")
        return candidate

    def prepare_candidate(self) -> None:
        candidate = self.stage_candidate()
        upgrade = Runner(candidate, self.work / "upgrade/home", self.out / "candidate", False)
        upgrade.base_path = os.pathsep.join((str(upgrade.home / ".legion/bin"), self.env["PATH"]))
        upgrade.env["PATH"] = upgrade.base_path
        upgrade.out.mkdir(parents=True, exist_ok=True)
        # A sibling stands in for the owner's real configuration. Never hash credential files.
        outside = upgrade.work.parent / "fake-real"
        for name in (".legion", ".claude", ".codex", ".copilot"):
            folder = outside / name
            folder.mkdir(parents=True)
            (folder / "keep.txt").write_text("owner sentinel\n", encoding="utf-8")
        self.state["candidate"] = upgrade
        self.state["outside"] = outside
        self.state["outside_snapshot"] = snapshot(outside)

    def install_old(self) -> None:
        upgrade = self.state["candidate"]
        old = upgrade.work / "old-source"
        self.run(["git", "clone", "--quiet", "--depth", "1", "--branch", "v0.17.0", "https://github.com/BlackGad/ps-legion-marketplace.git", str(old)])
        upgrade.checkout = old
        for tool in TOOLS:
            upgrade.install_legion(tool)
            require(upgrade.listing(tool, upgrade.folder(tool)), f"{tool}: old plugin not enabled")
            require(upgrade.version(tool, upgrade.folder(tool)) == "0.17.0", f"{tool}: old install not proven")
        app = upgrade.home / ".legion/app/0.17.0"
        require((app / ".legion-app-ready").is_file(), "old app not ready")
        python = upgrade.app_python(app)
        identity = json.loads(upgrade.run([str(python), "-I", "-c", "import json; from legion._plugin import PLUGIN_ROOT; print(json.dumps({'root': str(PLUGIN_ROOT)}))"]))
        require(Path(identity["root"]).resolve() == app.resolve(), "old launcher environment uses the wrong checkout")
        contains(upgrade.legion("--help", owner=True), "Install legion")
        self.state["old_shims"] = {path.name: path.read_bytes() for path in upgrade.owner_shims()}

    def owner_shims(self) -> list[Path]:
        return [self.launcher("legion"), self.launcher("legion").with_suffix("")] if WINDOWS else [self.launcher("legion")]

    def app_python(self, app: Path) -> Path:
        key = str(app.resolve()).rstrip("/\\")
        if WINDOWS:
            key = key.lower()
        digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:12]
        return self.home / ".legion/python" / f"env-{digest}" / ("Scripts/python.exe" if WINDOWS else "bin/python3")

    def upgrade_candidate(self) -> None:
        upgrade = self.state["candidate"]
        # Keep the registered local marketplace path stable, just as a published track
        # changes its contents. --source does not retarget an existing 0.17.0 marketplace.
        candidate = self.work / "candidate"
        files = self.run(["git", "-C", str(upgrade.checkout), "ls-files", "-z"]).split("\0")
        for name in filter(None, files):
            path = upgrade.checkout / name
            require(path.resolve().is_relative_to(upgrade.work.resolve()), "old source escaped scratch")
            if path.is_file():
                path.unlink()
        for source in candidate.rglob("*"):
            if source.is_file():
                target = upgrade.checkout / source.relative_to(candidate)
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        # This is deliberately the installed old command. No checkout CLI or repair runs first.
        output = upgrade.legion("update", "--yes", owner=True)
        for tool in TOOLS:
            contains(output, f"Update legion for {tool}")
            require(upgrade.version(tool, upgrade.folder(tool)) == CANDIDATE_VERSION, f"{tool}: upgrade was skipped")
            upgrade.targets[tool] = (str(upgrade.checkout), "release")
        for path in upgrade.owner_shims():
            require(path.read_bytes() != self.state["old_shims"][path.name], f"{path.name}: old launcher remains")
            contains(path.read_text(encoding="utf-8"), CANDIDATE_VERSION)

    def check_runtime_identity(self, identity: dict[str, Any], app: Path) -> None:
        require(Path(identity["root"]).resolve() == app.resolve(), f"runtime is from the wrong checkout: {identity}")
        require(identity["version"] == CANDIDATE_VERSION, "runtime version is not the candidate")
        for name in ("cli", "server"):
            require(Path(identity[name]).resolve().is_relative_to(app.resolve()), f"{name} runtime is outside the candidate app")

    def candidate_plugin(self, tool: str) -> Path:
        if tool == "copilot":
            return self.checkout / "plugins/legion"
        root = self.folder(tool) / self.catalog[tool]["plugin"]["installedRoot"]
        matches = []
        for path in root.rglob("plugin.json"):
            if path.parent.name in (".codex-plugin", ".claude-plugin"):
                continue
            document = json.loads(path.read_text(encoding="utf-8-sig"))
            if document.get("name") == "legion" and document.get("version") == CANDIDATE_VERSION:
                matches.append(path.parent)
        require(len(matches) == 1, f"{tool}: expected one installed candidate, found {matches}")
        return matches[0]

    def check_candidate_bytes(self, root: Path) -> None:
        source = self.checkout / "plugins/legion"
        files = [*source.rglob("*.py"), source / ".mcp.json", source / "plugin.json", *source.glob("hooks/*.json")]
        for path in files:
            target = root / path.relative_to(source)
            require(target.is_file() and target.read_bytes() == path.read_bytes(), f"candidate checkout mismatch: {target}")

    def check_candidate_launchers(self, app: Path) -> None:
        for path in self.owner_shims():
            windows = path.suffix == ".cmd"
            script = (
                "import json; from pathlib import Path; from legion.services.installation._installed_runtime import shim_text; "
                f"print(json.dumps(shim_text(Path({str(app)!r}), Path({str(self.home)!r}), {windows})))"
            )
            expected = json.loads(self.run([str(self.app_python(app)), "-I", "-c", script]))
            require(path.read_text(encoding="utf-8").replace("\r\n", "\n") == expected.replace("\r\n", "\n"), f"{path.name}: launcher was generated by old runtime code")

    def verify_candidate(self) -> None:
        upgrade = self.state["candidate"]
        app = upgrade.home / ".legion/app" / CANDIDATE_VERSION
        require((app / ".legion-app-ready").is_file(), "candidate app not ready")
        upgrade.check_candidate_bytes(app)
        upgrade.check_candidate_launchers(app)
        script = (
            "import json; import legion.cli, legion.mcp.server; from legion.core._plugin import PLUGIN_ROOT; "
            "print(json.dumps({'root':str(PLUGIN_ROOT),'version':json.loads((PLUGIN_ROOT/'plugin.json').read_text())['version'],"
            "'cli':legion.cli.__file__,'server':legion.mcp.server.__file__}))"
        )
        identity = json.loads(upgrade.run([str(upgrade.app_python(app)), "-I", "-c", script]))
        upgrade.check_runtime_identity(identity, app)
        (upgrade.out / "runtime.json").write_text(json.dumps(identity, indent=2) + "\n", encoding="utf-8")
        for tool in TOOLS:
            require(upgrade.listing(tool, upgrade.folder(tool)), f"{tool}: candidate not enabled")
            plugin = upgrade.candidate_plugin(tool)
            upgrade.check_candidate_bytes(plugin)
            hook = plugin / "hooks/session_start.py"
            hook_script = f"import runpy, sys; from pathlib import Path; sys.argv=[{str(hook)!r}, '--format', 'text']; runpy.run_path({str(hook)!r},run_name='__main__')"
            env = upgrade.env.copy()
            env.update({"LEGION_ROLE": "member", "LEGION_TASK": "candidate-hook-sentinel"})
            contains(upgrade.run([str(upgrade.app_python(app)), "-I", "-c", hook_script], env=env), "you are a legion member")
        upgrade.prove_mcp()
        upgrade.check_client_command()
        upgrade.prove_clients()
        self.state["candidate_snapshot"] = upgrade.home_snapshot(update=True)

    def check_client_command(self) -> None:
        command = shutil.which("legion", path=self.env["PATH"])
        require(command is not None and Path(command).resolve() == self.launcher("legion").resolve(), "client MCP command resolves outside the candidate home")

    def prove_mcp(self) -> None:
        expected = json.loads(self.run([str(self.launcher("legion")), "status", "--json"]))
        require(Path(expected["settings"]["path"]).resolve() == (self.home / ".legion/configuration/personalisation.json").resolve(), "status escaped fake home")
        for reconnect in range(2):
            connection = JsonProcess([str(self.launcher("legion")), "mcp"], self.env, self.work, self.out / f"mcp-{reconnect}.stderr")
            try:
                connection.rpc("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "candidate-proof", "version": "1"}}, 1)
                connection.send({"jsonrpc": "2.0", "method": "notifications/initialized"})
                tools = connection.rpc("tools/list", {}, 2)
                require({tool["name"] for tool in tools["tools"]} == {"status", "limits"}, "wrong MCP tools")
                result = connection.rpc("tools/call", {"name": "status", "arguments": {"repo": str(self.work)}}, 3)
                require(not result.get("isError"), f"MCP status failed: {result}")
                require(result["structuredContent"] == expected, "MCP status differs from installed CLI")
            finally:
                connection.close()
            require(connection.process.returncode == 0, "MCP did not exit cleanly on EOF")
        self.log.append("SDK-independent MCP wire proof: initialize, tools/list, status parity, EOF exit, reconnect; no real client tool call claimed")

    def probe_client(self, tool: str) -> dict[str, Any]:
        evidence: dict[str, Any] = {"host": tool, "discovered": False, "launched": False, "status_called": False, "source": "installed plugin", "limitation": ""}
        if tool == "claude":
            output = self.cli(tool, ["mcp", "list"])
            evidence["output"] = output
            evidence["discovered"] = "legion" in output.lower()
            evidence["launched"] = any("legion" in line.lower() and "connected" in line.lower() and "not connected" not in line.lower() for line in output.splitlines())
            evidence["limitation"] = "mcp list health check proves initialization only; no nonbillable direct tool-call API exercised"
        elif tool == "copilot":
            output = self.cli(tool, ["mcp", "list", "--json"])
            evidence["output"] = output
            evidence["discovered"] = "legion" in output.lower()
            evidence["limitation"] = "configuration listing only; does not prove a server launch or a tool call"
            connection = JsonProcess([self.command("copilot"), "--disable-builtin-mcps", "--disable-client-telemetry", "--acp"], self.env, self.work, self.out / "copilot-client.stderr")
            try:
                evidence["control_initialize"] = connection.rpc("initialize", {"protocolVersion": 1, "clientCapabilities": {}}, 1)
                evidence["control_session"] = connection.rpc("session/new", {"cwd": str(self.work), "mcpServers": []}, 2)
            except (AssertionError, queue.Empty) as error:
                evidence["limitation"] += "; ACP session blocked: " + (str(error) or type(error).__name__)
            finally:
                connection.close()
        else:
            connection = JsonProcess([self.command("codex"), "app-server"], self.env, self.work, self.out / "codex-client.stderr")
            try:
                connection.rpc("initialize", {"clientInfo": {"name": "legion-proof", "version": "1"}, "capabilities": {"experimentalApi": True}}, 1)
                connection.send({"jsonrpc": "2.0", "method": "initialized"})
                thread = connection.rpc("thread/start", {"cwd": str(self.work), "approvalPolicy": "never", "sandbox": "read-only"}, 2)["thread"]["id"]
                servers = connection.rpc("mcpServerStatus/list", {"threadId": thread}, 3)
                evidence["inventory"] = servers
                matches = [server for server in servers["data"] if "legion" in server["name"]]
                evidence["discovered"] = bool(matches)
                for selected in matches:
                    server = selected
                    if server.get("runtimeStatus") == "starting":
                        connection.mcp_ready(server["name"])
                        refreshed = connection.rpc("mcpServerStatus/list", {"threadId": thread}, 5)
                        server = next(item for item in refreshed["data"] if item["name"] == server["name"])
                        evidence["inventory"] = refreshed
                    tools = server["tools"]
                    if "status" not in tools:
                        continue
                    evidence["launched"] = True
                    result = connection.rpc("mcpServer/tool/call", {"threadId": thread, "server": server["name"], "tool": "status", "arguments": {"repo": str(self.work)}}, 4)
                    expected = json.loads(self.run([str(self.launcher("legion")), "status", "--json"]))
                    require(not result.get("isError") and result["structuredContent"] == expected, "Codex client status differs from CLI")
                    evidence["status_called"] = True
                evidence["limitation"] = "No model turn or account probe; host interruption and reconnect await separate client lifecycle proof"
            finally:
                connection.close()
        return evidence

    def prove_clients(self) -> None:
        evidence = []
        for tool in TOOLS:
            try:
                evidence.append(self.probe_client(tool))
            except Exception as error:
                evidence.append({"host": tool, "discovered": False, "launched": False, "status_called": False, "limitation": str(error) or type(error).__name__})
        (self.out / "clients.json").write_text(json.dumps(evidence, indent=2) + "\n", encoding="utf-8")
        missing = [item["host"] for item in evidence if not item["discovered"] or not item["launched"]]
        require(not missing, "client discovery/launch remains unproven: " + ", ".join(missing) + "; see candidate/clients.json")

    def finish_candidate(self) -> None:
        upgrade = self.state["candidate"]
        output = upgrade.legion("update", "--yes", owner=True)
        for tool in TOOLS:
            contains(output, f"Update legion for {tool}")
            require(upgrade.version(tool, upgrade.folder(tool)) == CANDIDATE_VERSION, f"{tool}: repeat changed version")
        contains(output, "already up to date")
        unchanged(self.state["candidate_snapshot"], upgrade.home_snapshot(update=True))
        upgrade.legion("uninstall", "--purge", "--yes", owner=True)
        require(not any(path.exists() for path in upgrade.owner_shims()), "candidate launcher remains after uninstall")
        require(not (upgrade.home / ".legion/app").exists(), "candidate app remains after uninstall")
        footprints = upgrade.home / ".legion/footprints.json"
        require(not footprints.exists() or not json.loads(footprints.read_text(encoding="utf-8"))["entries"], "candidate footprints remain")
        for tool in TOOLS:
            upgrade.check_uninstalled(tool, upgrade.folder(tool))
        unchanged(self.state["outside_snapshot"], snapshot(self.state["outside"]))

    def update_from_0_17_0(self, repeat: bool) -> None:
        try:
            if repeat:
                self.finish_candidate()
            else:
                self.prepare_candidate()
                self.install_old()
                self.upgrade_candidate()
                self.verify_candidate()
        finally:
            if "candidate" in self.state:
                upgrade = self.state["candidate"]
                self.log.extend(upgrade.log)
                upgrade.log.clear()
            if "outside" in self.state:
                unchanged(self.state["outside_snapshot"], snapshot(self.state["outside"]))

    def update(self, repeat: bool) -> str:
        expected = json.loads((self.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
        active = self.active()
        if not repeat:
            # Use the public tool commands to leave one target absent. The owner update must restore it.
            target = next((tool for tool in active if self.targets[tool][1] != "main"), active[0])
            entry = self.catalog[target]["plugin"]
            self.cli(target, entry["uninstall"])
            self.cli(target, entry["marketplaceRemove"])
            require(not self.listing(target, self.folder(target)), f"{target} remains installed before update")
            self.state["update_target"] = target
        target = self.state["update_target"]
        if repeat:
            output = self.legion("update", "--yes", owner=True)
        else:
            source, ref = self.targets[target]
            arguments = ["install", "--update", "--source", source]
            if ref == "main":
                arguments += ["--ref", "main"]
            output = self.legion(*arguments, "--yes", owner=True)
        if not repeat:
            contains(output, f"legion not installed -> {expected}")
        for tool in self.active():
            contains(output, f"Update legion for {tool}")
            require(self.version(tool, self.folder(tool)) == expected, f"{tool} version changed away from the checkout")
            require(self.installed_source_matches(tool, self.folder(tool)), f"{tool} update did not keep the PR checkout source")
        if repeat:
            contains(output, "already up to date")
            unchanged(self.state["update_snapshot"], self.home_snapshot(update=True))
        else:
            self.state["update_snapshot"] = self.home_snapshot(update=True)
        return output

    def setup_accounts(self) -> str:
        return "\n".join(self.legion("add", tool, "--id", f"{tool}1", "--source", self.targets[tool][0], "--yes") for tool in self.active())

    def check_accounts(self, agents: list[dict[str, Any]]) -> None:
        expected = json.loads((self.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
        for agent in agents:
            require(self.version(agent["tool"], self.resolve_folder(agent["configDir"])) == expected, f"{agent['id']} has wrong legion version")

    def setup_first(self) -> str:
        output = self.setup_accounts()
        settings_path = self.home / ".legion/configuration/personalisation.json"
        self.legion("validate", "--kind", "personalisation", "--path", str(settings_path), owner=True)
        require((settings_path.parent / "notes.md").is_file(), "notes.md missing")
        agents = self.settings()["agents"]
        for tool in self.active():
            require(f"{tool}1" in [agent["id"] for agent in agents], f"{tool}1 missing")
            contains(output, f"log in: run {tool}1")
        self.check_accounts(agents)
        require(any((self.home / ".legion/bin").iterdir()), "no owner commands")
        help_text = self.legion("--help", owner=True)
        for verb in ("inbox", "telegram", "validate", "setup", "status"):
            contains(help_text, f"  {verb} ")
        contains(self.legion("status", owner=True), "commands: yes")
        if sys.platform == "win32":
            require(str(self.home / ".legion/bin") in (self.work / "user-path.txt").read_text(encoding="utf-8").split(";"), "owner bin missing from saved PATH")
        else:
            require(self.profile_count() == 1, "profile must have one legion line")
        self.state["snapshot"] = self.home_snapshot()
        return output + "\n" + help_text

    def setup_repeat(self) -> str:
        output = self.setup_accounts()
        contains(output, "skip:")
        unchanged(self.state["snapshot"], self.home_snapshot())
        return output

    def profile_count(self) -> int:
        return sum((self.home / name).read_text(encoding="utf-8").splitlines().count("# Added by legion") for name in (".zshrc", ".bashrc", ".profile") if (self.home / name).exists())

    def add(self, repeat: bool) -> str:
        tool = self.active()[0]
        output = self.legion("add", tool, "--id", "ci-extra", "--source", self.targets[tool][0], "--yes")
        agents = self.settings()["agents"]
        if repeat:
            contains(output, "skip: account ci-extra (already done)")
            require(len(agents) == self.state["agent_count"], "repeat added an account")
        else:
            matched = [agent for agent in agents if agent["id"] == "ci-extra"]
            require(len(matched) == 1, "ci-extra not recorded")
            require(self.resolve_folder(matched[0]["configDir"]).is_dir(), "ci-extra folder missing")
            self.check_accounts(matched)
            self.state["agent_count"] = len(agents)
        return output

    def remove(self, repeat: bool) -> str:
        folder = self.resolve_folder(next(agent["configDir"] for agent in self.settings()["agents"] if agent["id"] == "ci-extra")) if not repeat else None
        output = self.legion("account", "remove", "--id", "ci-extra", owner=True)
        if repeat:
            contains(output, "skip: account remove ci-extra (already done)")
        else:
            require(not any(agent["id"] == "ci-extra" for agent in self.settings()["agents"]), "ci-extra still in settings")
            require(folder is not None and folder.is_dir(), "ci-extra folder removed")
            contains(output, "Config folder kept at")
        return output

    def new_repo(self, name: str, rules: bool = False) -> Path:
        repo = self.work / name
        repo.mkdir(exist_ok=True)
        self.run(["git", "-C", str(repo), "init", "--quiet"])
        self.run(["git", "-C", str(repo), "config", "user.name", "integration"])
        self.run(["git", "-C", str(repo), "config", "user.email", "integration@example.com"])
        self.run(["git", "-C", str(repo), "config", "commit.gpgsign", "false"])
        (repo / "README.md").write_text(name + "\n", encoding="utf-8")
        self.run(["git", "-C", str(repo), "add", "README.md"])
        if rules:
            (repo / "AGENTS.md").write_text(f"# {name} rules\n", encoding="utf-8")
            self.run(["git", "-C", str(repo), "add", "AGENTS.md"])
        self.run(["git", "-C", str(repo), "commit", "--quiet", "-m", "initial"])
        return repo

    def commit_count(self, repo: Path) -> int:
        return int(self.run(["git", "-C", str(repo), "rev-list", "--count", "HEAD"]))

    def repository(self, mode: str, repeat: bool) -> str:
        name = "repo-a" if mode == "private" else "repo-b"
        repo = self.work / name if repeat else self.new_repo(name, rules=mode == "shared")
        args = ["repository", "setup", "--repo", str(repo), "--mode", mode, "--gate", "git status --porcelain"]
        if mode == "shared":
            args += ["--rules-file", "AGENTS.md"]
        output = self.legion(*args, owner=True)
        for item in ("configuration/project.json", "configuration/workflow.md", "scripts/index.md", "scripts/check-task.ps1", "state/handoff.md"):
            require((repo / ".legion" / item).exists(), f".legion/{item} missing")
        self.legion("validate", "--kind", "project", "--path", str(repo / ".legion/configuration/project.json"), owner=True)
        if mode == "private":
            require(self.commit_count(repo / ".legion") >= 1, "inner repository has no commit")
            require(self.commit_count(repo) == 1 and not self.run(["git", "-C", str(repo), "status", "--porcelain"]), "outer repository changed")
            if repeat:
                contains(output, "skip: Private orchestration (already done)")
                require(self.commit_count(repo / ".legion") == self.state["inner_commits"], "repeat made an inner commit")
            else:
                self.state["inner_commits"] = self.commit_count(repo / ".legion")
        else:
            heading = (self.checkout / "plugins/legion/skills/legion-repository/references/rules-file-lines.md").read_text(encoding="utf-8").splitlines()[0]
            require((repo / "AGENTS.md").read_text(encoding="utf-8").splitlines().count(heading) == 1, "rules block count wrong")
            require(self.commit_count(repo) == 2, "shared repository commit count wrong")
            require(self.run(["git", "-C", str(repo), "log", "-1", "--format=%s"]) == "Set up legion orchestration", "unexpected commit subject")
            require(not self.run(["git", "-C", str(repo), "status", "--porcelain"]), "shared repository dirty")
            if repeat:
                contains(output, "skip:")
        return output

    def channel_account(self) -> str | None:
        for agent in self.settings()["agents"]:
            if agent["id"] in ("claude1", "codex1"):
                return agent["id"]
        require("claude" in self.not_tested and "codex" in self.not_tested, "no Claude or Codex setup account")
        return None

    def channel(self, repeat: bool) -> str:
        account = self.channel_account()
        if account is None:
            return "not tested: no Claude or Codex setup account"
        add = ("channel", "add", "--id", "ci-bot", "--kind", "telegram", "--target", "1", "--account", account)
        lines = [self.legion(*add, owner=True), self.legion("channel", "check", "--kind", "telegram", "--account", account, owner=True)]
        if repeat:
            again = self.legion(*add, owner=True)
            contains(again, "skip:")
            lines.append(again)
        require("ci-bot" in [channel["id"] for channel in self.settings().get("channels", [])], "ci-bot binding missing")
        lines.append(self.legion("channel", "remove", "--id", "ci-bot", owner=True))
        if repeat:
            removed = self.legion("channel", "remove", "--id", "ci-bot", owner=True)
            contains(removed, "skip:")
            lines.append(removed)
        require("ci-bot" not in [channel["id"] for channel in self.settings().get("channels", [])], "ci-bot binding remains")
        return "\n".join(lines)

    @contextmanager
    def fake_az(self):
        old = self.env["PATH"]
        self.env["PATH"] = str(self.checkout / "tests/fixtures/integration-az") + os.pathsep + old
        try:
            yield
        finally:
            self.env["PATH"] = old

    def foundry_launch(self) -> str:
        output = self.run([str(self.launcher("ci-foundry")), "--version"])
        require(not list((self.home / ".legion/temp").glob("copilot-providers-*.json")), "Copilot provider file remains")
        return output

    def foundry(self, repeat: bool) -> str:
        if "copilot" in self.not_tested:
            return "not tested: Copilot was not tested from checkout"
        args = ("account", "add", "--id", "ci-foundry", "--tool", "copilot", "--provider", "foundry", "--endpoint", ENDPOINT, "--deployment", "model-a", "--default", "model-a")
        with self.fake_az():
            output = self.legion(*args, owner=True)
            if repeat:
                contains(output, "skip: account ci-foundry (already done)")
            output += "\n" + self.foundry_launch()
            if repeat:
                output += "\n" + self.legion("account", "remove", "--id", "ci-foundry", owner=True)
        return output

    @contextmanager
    def without_pwsh(self):
        # Hand-built, reason: an executable trap proves a child did not invoke pwsh.
        trap = self.work / "pwsh-trap"
        trap.mkdir(exist_ok=True)
        marker = trap / "called"
        marker.unlink(missing_ok=True)
        if sys.platform == "win32":
            (trap / "pwsh.cmd").write_text(f'@echo off\necho called>"{marker}"\nexit /b 97\n', encoding="utf-8")
        else:
            executable = trap / "pwsh"
            executable.write_text(f"#!/bin/sh\necho called > {shlex.quote(str(marker))}\nexit 97\n", encoding="utf-8")
            executable.chmod(0o755)
        kept = []
        for folder in self.base_path.split(os.pathsep):
            if not folder:
                continue
            path = Path(folder)
            if (
                sys.platform != "win32"
                or not (path / "pwsh.exe").exists()
                or any(
                    (path / (name + suffix)).exists() for name in ("uv", "git", "sh", "claude", "codex", "copilot", "legion", "node", "npm", "npx", "winget", "az") for suffix in ("", ".exe", ".cmd")
                )
            ):
                kept.append(folder)
        self.env["PATH"] = os.pathsep.join([str(trap), str(self.checkout / "tests/fixtures/integration-az"), *kept])
        try:
            yield
        finally:
            self.env["PATH"] = self.base_path
            require(not marker.exists(), "a command called pwsh")

    def no_pwsh(self, repeat: bool) -> str:
        with self.without_pwsh():
            repo = self.work / "no-pwsh-repo" if repeat else self.new_repo("no-pwsh-repo")
            lines = [self.legion("repository", "setup", "--repo", str(repo), "--gate", "git status --porcelain", owner=True)]
            if repeat:
                contains(lines[0], "skip:")
            account = self.channel_account()
            if account:
                add = ("channel", "add", "--id", "ci-no-pwsh", "--kind", "telegram", "--target", "1", "--account", account)
                lines.append(self.legion(*add, owner=True))
                if repeat:
                    again = self.legion(*add, owner=True)
                    contains(again, "skip:")
                    lines.append(again)
                lines += [self.legion("channel", "check", "--kind", "telegram", "--account", account, owner=True), self.legion("channel", "remove", "--id", "ci-no-pwsh", owner=True)]
            tool = self.active()[0]
            add_account = ("account", "add", "--id", "ci-no-pwsh", "--tool", tool)
            lines.append(self.legion(*add_account, owner=True))
            if repeat:
                again = self.legion(*add_account, owner=True)
                contains(again, "skip:")
                lines.append(again)
            lines.append(self.run([str(self.launcher("ci-no-pwsh")), "--version"]))
            lines.append(self.legion("account", "remove", "--id", "ci-no-pwsh", owner=True))
            if "copilot" not in self.not_tested:
                with self.fake_az():
                    lines.append(
                        self.legion(
                            "account", "add", "--id", "ci-foundry", "--tool", "copilot", "--provider", "foundry", "--endpoint", ENDPOINT, "--deployment", "model-a", "--default", "model-a", owner=True
                        )
                    )
                    lines.append(self.foundry_launch())
                    lines.append(self.legion("account", "remove", "--id", "ci-foundry", owner=True))
            lines.append(self.legion("refresh", owner=True))
            return "\n".join(lines)

    def targets_for_uninstall(self, all_tools: bool = False) -> list[tuple[str, Path]]:
        active = list(TOOLS) if all_tools else self.active()
        targets = [(tool, self.folder(tool)) for tool in active]
        for agent in self.settings()["agents"]:
            if agent["tool"] in active and agent.get("configDir"):
                item = (agent["tool"], self.resolve_folder(agent["configDir"]))
                if item not in targets:
                    targets.append(item)
        return targets

    def check_uninstalled(self, tool: str, folder: Path) -> None:
        require(self.version(tool, folder) is None, f"legion remains in {folder}")
        require(not self.listing(tool, folder, include_disabled=True), f"{tool} still lists legion in {folder}")
        cache = self.catalog[tool]["plugin"].get("cacheDir")
        require(not cache or not (folder / cache).exists(), f"{tool} cache remains")

    def account_ids(self) -> list[str]:
        return [agent["id"] for agent in self.settings()["agents"] if agent["tool"] in self.active()]

    def check_launchers(self, run: bool = False) -> None:
        for account in self.account_ids():
            launcher = self.launcher(account)
            require(launcher.is_file(), f"launcher {account} missing")
            if sys.platform == "win32":
                require(launcher.with_suffix("").is_file(), f"launcher {account} missing")
            if run:
                self.run([str(launcher), "--version"])

    def uninstall(self, repeat: bool) -> str:
        targets = self.targets_for_uninstall() if not repeat else []
        output = self.legion("uninstall", "--yes", owner=not repeat)
        if repeat:
            contains(output, "Nothing to uninstall.")
            return output
        for tool, folder in targets:
            self.check_uninstalled(tool, folder)
        for tool in self.active():
            self.run([self.command(self.catalog[tool]["command"]), "--version"])
        require(not self.launcher("legion").exists(), "owner command remains")
        if sys.platform == "win32":
            require(not self.launcher("legion").with_suffix("").exists(), "owner command remains")
        require(not (self.home / ".legion/app").exists(), "app remains")
        self.check_launchers()
        for name in ("configuration", "agents"):
            require((self.home / ".legion" / name).is_dir(), f"{name} removed")
        return output

    def reinstall(self, repeat: bool, restore: bool = False) -> str:
        if restore and not repeat:
            for account in self.account_ids():
                self.launcher(account).unlink()
                if sys.platform == "win32":
                    self.launcher(account).with_suffix("").unlink()
        output = "\n".join(self.install_legion(tool) for tool in self.active())
        if repeat:
            contains(output, "skip:")
            unchanged(self.state["snapshot"], self.home_snapshot())
        else:
            expected = json.loads((self.checkout / "plugins/legion/plugin.json").read_text(encoding="utf-8"))["version"]
            for tool, folder in self.targets_for_uninstall():
                require(self.version(tool, folder) == expected, f"{tool} version wrong in {folder}")
            self.check_launchers(run=True)
            self.state["snapshot"] = self.home_snapshot()
        return output

    def purge(self, repeat: bool) -> str:
        if not repeat:
            self.state["purge_targets"] = self.targets_for_uninstall(all_tools=True)
            output = self.legion("uninstall", "--purge", "--yes", owner=True)
        elif WINDOWS:
            output = self.run(["powershell.exe", "-NoProfile", "-File", str(self.checkout / "install.ps1"), "-HomeRoot", str(self.home), "-Uninstall", "-Purge", "-Yes"])
        else:
            output = self.run(["sh", str(self.checkout / "install.sh"), "--uninstall", "--purge", "--yes"])
        if repeat:
            contains(output, "skip: purge (already done)")
        require(not (self.home / ".legion").exists(), "legion home remains")
        require(self.profile_count() == 0, "profile legion line remains")
        for tool, folder in self.state["purge_targets"]:
            if folder.is_dir():
                self.check_uninstalled(tool, folder)
                require(not self.listing(tool, folder, "marketplace"), f"{tool} marketplace remains")
                plugin = self.catalog[tool]["plugin"]
                for relative in [plugin.get("cacheDir"), *plugin.get("purge", {}).get("paths", []), *plugin.get("purge", {}).get("emptyDirs", [])]:
                    if relative:
                        require(not (folder / relative).exists(), f"purge path remains: {folder / relative}")
                for setting in plugin.get("purge", {}).get("settings", []):
                    path = folder / setting["path"]
                    require(not path.is_file() or "legion" not in path.read_text(encoding="utf-8").lower(), f"legion remains in {path}")
        for tool in TOOLS:
            self.cli(tool, ["--version"])
        if repeat:
            unchanged(self.state["purge_snapshot"], self.home_snapshot())
        else:
            self.state["purge_snapshot"] = self.home_snapshot()
        return output

    def steps(self) -> list[tuple[str, Any]]:
        steps = [("bootstrap", self.bootstrap)]
        steps += [(f"install-cli-{tool}", lambda repeat, tool=tool: self.install_cli(tool, repeat)) for tool in TOOLS]
        steps += [
            ("update-from-0.17.0", self.update_from_0_17_0),
            ("install-legion", lambda repeat: self.install_repeat() if repeat else self.install_first()),
            ("update-legion", self.update),
            ("setup", lambda repeat: self.setup_repeat() if repeat else self.setup_first()),
            ("add", self.add),
            ("remove", self.remove),
            ("repo-private", lambda repeat: self.repository("private", repeat)),
            ("repo-shared", lambda repeat: self.repository("shared", repeat)),
            ("channel", self.channel),
            ("foundry-launcher", self.foundry),
            ("no-pwsh", self.no_pwsh),
            ("uninstall", self.uninstall),
            ("reinstall", self.reinstall),
            ("restore-launchers", lambda repeat: self.reinstall(repeat, restore=True)),
            ("purge", self.purge),
        ]
        return steps

    def execute(self) -> list[Case]:
        cases = []
        blocked = ""
        (self.out / "logs").mkdir(parents=True, exist_ok=True)
        for name, action in self.steps():
            for repeat in (False, True):
                start = time.monotonic()
                self.log = []
                result, message = "passed", ""
                if blocked:
                    result, message = "skipped", blocked
                else:
                    try:
                        if name == "bootstrap":
                            returned = action(repeat)
                        else:
                            with self.without_pwsh():
                                returned = action(repeat)
                        if isinstance(returned, str):
                            logged = "\n".join(self.log).splitlines()
                            self.log.extend(line for line in returned.splitlines() if line not in logged)
                    except Exception as error:
                        result, message = "failed", str(error) or type(error).__name__
                        blocked = f"previous step failed: {name}{' (repeat)' if repeat else ''}"
                log = "\n".join([*self.log, message]).strip()
                case = Case(name, repeat, result, time.monotonic() - start if not blocked or result == "failed" else 0, message, log)
                cases.append(case)
                (self.out / "logs" / f"{name}{'-repeat' if repeat else ''}.log").write_text(log + "\n", encoding="utf-8")
                print(f"{case.title}: {case.result}{': ' + message.splitlines()[0] if message else ''}", flush=True)
        return cases


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--home-root", type=Path)
    parser.add_argument("--checkout", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--allow-source-fallback", action="store_true")
    args = parser.parse_args()
    if os.environ.get("CI") != "true":
        parser.error("integration installs real tools and only runs in CI (CI=true)")
    if args.home_root is None and not os.environ.get("RUNNER_TEMP"):
        parser.error("--home-root or RUNNER_TEMP is required")
    home = args.home_root or Path(os.environ["RUNNER_TEMP"]) / "legion-home"
    system = "windows" if sys.platform == "win32" else "macos" if sys.platform == "darwin" else "linux"
    probe = []
    for command in ("winget", "pwsh", "powershell", "node", "git"):
        path = shutil.which(command)
        if path:
            arguments = ["-NoProfile", "-Command", "$PSVersionTable.PSVersion.ToString()"] if command == "powershell" else ["--version"]
            result = subprocess.run([path, *arguments], text=True, capture_output=True, check=False)  # noqa: S603
            probe.append(f"{command}: {result.stdout.splitlines()[0] if result.returncode == 0 and result.stdout else 'not found'}")
        else:
            probe.append(f"{command}: not found")
    runner = Runner(args.checkout, home, args.out, args.allow_source_fallback)
    with restore_user_path():
        cases = runner.execute()
        extra = ", ".join(f"{tool} {version[0]}" for tool, version in runner.versions.items())
        if runner.not_tested:
            extra += "; not tested from checkout: " + ", ".join(runner.not_tested)
        write_report(args.out, system, cases, probe, extra)
    return int(not complete(cases, runner.not_tested))


if __name__ == "__main__":
    sys.exit(main())
