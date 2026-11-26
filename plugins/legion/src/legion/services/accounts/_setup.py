# Setup and add: work out what is missing, show it as a plan, and with consent do it, step by step.
# Accounts, the app and the CLI installs are the code the other verbs use; this file only orders them.

import json
import os
import shutil
import sys
from collections.abc import Callable, Iterator
from contextlib import contextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

import click
from pydantic import ValidationError

from legion.services.accounts import _accounts, _launchers
from legion.services.installation import (
    _installed_runtime,
    _refresh,
    _tool_install,
    installer as _installer,
)
from legion.services.status import _status
from legion.services.repository import _footprints
from legion.core import _generated, _settings_io
from legion.services.installation import _user_path
from legion.core._home import (
    bin_folder,
    full_path,
    home_path,
    path_contains,
    resolve_directory,
    same_path,
    settings_path,
)
from legion.core._plugin import PLUGIN_ROOT
from legion.core._settings_models import Agent, PersonalisationSettings, ToolDescriptor
from legion.core._validate import read_text

WINDOWS = sys.platform == "win32"
NO_FOLDER = "Existing account config folder does not exist."
NOTES_TEMPLATE = PLUGIN_ROOT / "skills" / "legion-personalisation" / "references" / "notes-template.md"
RUN_AGAIN = "Run again with --yes to apply."
NOTHING_TO_DO = "Nothing to do."


class SetupError(Exception):
    pass


# What a setup step can raise; the verb prints one line and exits 1.
ERRORS = (SetupError, _accounts.AccountError, _footprints.FootprintError, _launchers.LauncherError, _settings_io.SettingsError, _user_path.PathError, ValidationError, ValueError, OSError)


def one_line(text: str) -> str:
    return " ".join(text.split())


@dataclass
class Row:
    id: str
    tool: ToolDescriptor
    folder: Path
    requested: bool = False
    new: bool = False
    adopted: bool = False
    version: Optional[str] = None
    next_step: str = "ready"
    usable: bool = True
    command: Optional[str] = None
    provider: bool = False
    missing_allow_rules: list[str] = field(default_factory=list[str])

    # The account's own program is gone and only the owner can name it again.
    @property
    def blocked(self) -> bool:
        return self.next_step.startswith("target needed:")


@dataclass
class Plan:
    home: Path
    settings_file: Path
    accounts: list[Row]
    uv_missing: bool
    missing_tools: list[ToolDescriptor]
    bin: Path
    commands: list[tuple[Path, str]]
    needs_path: bool

    @property
    def notes(self) -> Path:
        return self.settings_file.parent / "notes.md"


# --- finding out what is there ---


# A command on this terminal's PATH, or on the saved PATH when it was installed a moment ago (Windows).
def command_available(name: str) -> bool:
    return shutil.which(name) is not None or (WINDOWS and _user_path.find_persistent_command(name) is not None)


# The process PATH plus the saved PATH folders for the work that starts programs: a command installed
# a moment ago may be only on the saved one. The caller's PATH comes back when the block ends.
@contextmanager
def saved_path() -> Iterator[None]:
    before = os.environ.get("PATH", "")
    add_saved_folders()
    try:
        yield
    finally:
        os.environ["PATH"] = before


# Also called after an install, which may have added a folder to the saved PATH.
def add_saved_folders() -> None:
    if not WINDOWS:
        return
    path = os.environ.get("PATH", "")
    for folder in _user_path.persistent_folders():
        if not path_contains(path, Path(folder)):
            path += f";{folder}"
    os.environ["PATH"] = path


def _resolve(folder: str, home: Path) -> Path:
    return full_path(home_path(folder, home))


# Two spellings of one folder (a link and its target) are one folder.
def _same_folder(left: Path, right: Path) -> bool:
    return same_path(resolve_directory(left), resolve_directory(right))


def _managed_folder(account: str, home: Path) -> Path:
    return full_path(home / ".legion" / "agents" / account)


# True when the account's own program is gone and the owner must name it again (legion account register);
# a missing stock CLI is installed instead.
def _target_needed(agent: Agent, home: Path) -> bool:
    return agent.command is not None and not _resolve(agent.command, home).is_file()


def _read_json(file: Path) -> dict[str, object]:
    try:
        data = json.loads(read_text(file))
    except (OSError, ValueError) as error:
        raise SetupError(f"cannot read {file}: {one_line(str(error))}") from None
    if not isinstance(data, dict):
        raise SetupError(f"cannot read {file}: not a JSON object")
    return data


# The rules a settings file allows now: a list, or one rule written as text. Another shape is refused.
def _allowed_rules(file: Path, data: dict[str, object]) -> list[object]:
    permissions = data.get("permissions")
    if permissions is not None and not isinstance(permissions, dict):
        raise SetupError(f"cannot read {file}: permissions is not an object")
    allowed = permissions.get("allow") if isinstance(permissions, dict) else None
    if allowed is None:
        return []
    if isinstance(allowed, str):
        return [allowed]
    if isinstance(allowed, list):
        return list(allowed)
    raise SetupError(f"cannot read {file}: permissions.allow is not a list or a rule")


def _missing_allow_rules(tool: ToolDescriptor, folder: Path) -> list[str]:
    rules = [rule for rule in tool.allow_rules or [] if rule]
    file = folder / "settings.json"
    if not rules or not file.exists():
        return rules
    current = _allowed_rules(file, _read_json(file))
    return [rule for rule in rules if rule not in current]


def _row(agent: Agent, tool: ToolDescriptor, home: Path, requested: bool = False, new: bool = False, adopted: bool = False) -> Row:
    folder = _resolve(agent.config_dir, home)
    # Login is owner-only; infer the guidance from our managed folder without reading credentials.
    next_step = f"log in: {_accounts.login_command(tool, folder, agent.command, home)}" if not adopted and agent.provider is None and same_path(folder, _managed_folder(agent.id, home)) else "ready"
    if not new and agent.provider is None and _target_needed(agent, home):
        next_step = f"target needed: {agent.id}; ask the owner for the registered executable"
    return Row(
        id=agent.id,
        tool=tool,
        folder=folder,
        requested=requested,
        new=new,
        adopted=adopted,
        version=_status.installed_version(folder, tool),
        next_step=next_step,
        usable=not next_step.startswith("target needed:"),
        command=agent.command,
        provider=agent.provider is not None,
        missing_allow_rules=_missing_allow_rules(tool, folder),
    )


def _next_id(tool_id: str, planned: PersonalisationSettings, home: Path) -> str:
    number = 1
    while True:
        candidate = f"{tool_id}{number}"
        if all(agent.id != candidate for agent in planned.agents) and _launchers.find_command(candidate, home) is None:
            return candidate
        number += 1


# One `tool` or `tool:folder` item. The folder follows the first colon, so it may hold colons itself.
def _added_account(item: str, account_id: Optional[str], planned: PersonalisationSettings, tools: dict[str, ToolDescriptor], home: Path) -> Row:
    tool_id, colon, text = item.partition(":")
    if tool_id not in tools:
        raise SetupError(f"unknown tool '{tool_id}'")
    folder: Optional[Path] = None
    if colon:
        folder = _resolve(text, home) if text else None
        if folder is None or not folder.is_dir():
            raise SetupError(NO_FOLDER)
        if account_id is None:
            same = next((agent for agent in planned.agents if agent.tool == tool_id and agent.provider is None and _same_folder(_resolve(agent.config_dir, home), folder)), None)
            if same is not None:
                account_id, folder = same.id, _resolve(same.config_dir, home)
    account_id = account_id or _next_id(tool_id, planned, home)
    folder = folder or _managed_folder(account_id, home)
    existing = next((agent for agent in planned.agents if agent.id == account_id), None)
    if existing is not None:
        if existing.tool != tool_id or existing.provider is not None or not _same_folder(_resolve(existing.config_dir, home), folder):
            raise SetupError(f"account '{account_id}' already exists with other values")
    else:
        _accounts.check_new_id(planned, account_id, home)
    agent = existing or Agent.model_construct(id=account_id, tool=tool_id, config_dir=str(folder))
    return _row(agent, tools[tool_id], home, requested=True, new=existing is None, adopted=bool(colon))


def _accounts_plan(adds: list[str], account_id: Optional[str], settings: PersonalisationSettings, tools: dict[str, ToolDescriptor], home: Path) -> list[Row]:
    if account_id and len(adds) != 1:
        raise SetupError("--id requires exactly one add")
    rows: list[Row] = []
    for agent in settings.agents:
        if agent.tool not in tools:
            raise SetupError(f"account '{agent.id}' uses unknown tool '{agent.tool}'")
        rows.append(_row(agent, tools[agent.tool], home))
    # Reserve planned ids in memory, so two adds for one tool get distinct ids without writing settings.
    planned = settings.model_copy(update={"agents": list(settings.agents)})
    for item in adds:
        row = _added_account(item, account_id, planned, tools, home)
        previous = next((other for other in rows if other.id == row.id), None)
        if previous is not None:
            row.new = previous.new
            if row.new:
                row.usable, row.next_step = True, previous.next_step
            rows.remove(previous)
        rows.append(row)
        if row.new and previous is None:
            planned.agents.append(Agent.model_construct(id=row.id, tool=row.tool.id, config_dir=str(row.folder)))
    return rows


def build_plan(home: Path, adds: list[str], account_id: Optional[str]) -> Plan:
    file = settings_path(home)
    settings = _settings_io.load_unchecked(home) if file.exists() else PersonalisationSettings.model_validate_json(_settings_io.EMPTY)
    tools = {tool.id: tool for tool in _tool_install.load_tools()}
    accounts = _accounts_plan(adds, account_id, settings, tools, home)
    # Without uv no Python work can run: an account that needs some waits, and the owner is told as its next step.
    uv_missing = _installed_runtime.find_uv() is None
    if uv_missing:
        for row in accounts:
            if row.usable and row.requested:
                row.usable, row.next_step = False, "uv is missing"
    needs_stock = {row.tool.id for row in accounts if row.usable and row.command is None}
    missing = [tool for tool in tools.values() if tool.id in needs_stock and not command_available(tool.command)]
    commands = bin_folder(home)
    needs_path = not path_contains(_user_path.user_path(), commands) if WINDOWS else not _user_path.shell_profile(home).has_path
    return Plan(home, file, accounts, uv_missing, missing, commands, _status.command_states(commands), needs_path)


# --- the plan the owner reads ---


def install_hint(tool_id: str, platform: Optional[str] = None) -> str:
    return "; ".join(_tool_install.install_hints(tool_id, platform or _tool_install.current_platform()))


def plan_lines(plan: Plan) -> list[str]:
    lines: list[str] = []
    if not plan.settings_file.exists() or not plan.notes.exists():
        lines.append(f"  create   settings and notes in {plan.settings_file.parent}")
    for tool in plan.missing_tools:
        lines.append(f"  cli      install {tool.id} ({install_hint(tool.id)})")
    for row in plan.accounts:
        if row.new:
            lines.append(f"  add      {row.id} ({row.tool.id}) {'existing' if row.adopted else 'new'} folder {row.folder}")
    if plan.uv_missing:
        lines.append("  uv       missing; ask the owner before installing it")
    lines.extend(f"  account  {row.next_step}" for row in plan.accounts if row.blocked)
    folders = list(dict.fromkeys(str(row.folder) for row in plan.accounts if row.usable and row.version is None))
    if folders:
        lines.append(f"  install  legion into {', '.join(folders)}")
    permissions = {str(row.folder): row for row in plan.accounts if row.usable and row.missing_allow_rules}
    for folder in sorted(permissions, key=str.lower):
        lines.append(f"  permission allow {', '.join(permissions[folder].missing_allow_rules)} in {folder}/settings.json")
    missing = [path.name.removesuffix(".cmd") for path, state in plan.commands if state == "missing"]
    if missing:
        lines.append(f"  commands write {', '.join(dict.fromkeys(missing))} in {plan.bin}")
    permission = [path.name.removesuffix(".cmd") for path, state in plan.commands if state == "permission"]
    if permission:
        lines.append(f"  commands restore execute permission for {', '.join(dict.fromkeys(permission))}")
    if plan.needs_path:
        lines.append(f"  path     {f'add {plan.bin} to your user PATH' if WINDOWS else _user_path.shell_profile_lines(plan.home, dry_run=True)[0]}")
    blocked = [f"blocked: command {name} (another file is there)" for name in dict.fromkeys(path.name.removesuffix(".cmd") for path, state in plan.commands if state == "blocked")]
    if not lines:
        return [*blocked, NOTHING_TO_DO]
    return [*blocked, "Plan (nothing changed yet):", *lines, RUN_AGAIN]


# The preview looks for commands where the apply will, so the hint it shows is the command that runs.
def preview(home: Path, adds: list[str], account_id: Optional[str]) -> list[str]:
    with saved_path():
        return plan_lines(build_plan(home, adds, account_id))


# --- doing it ---


def initialize_files(plan: Plan, say: Callable[[str], None]) -> None:
    if plan.settings_file.exists():
        say("skip: settings (already done)")
    else:
        _generated.write_generated(plan.settings_file, _settings_io.EMPTY + "\n", executable=False)
    if plan.notes.exists():
        say("skip: notes (already done)")
    else:
        _generated.write_generated(plan.notes, NOTES_TEMPLATE.read_text(encoding="utf-8-sig"), executable=False)


# An error message, or None when the tool is installed. The installer talks to the owner's terminal itself.
def install_tool(home: Path, tool_id: str) -> Optional[str]:
    lines: list[str] = []
    try:
        code = _tool_install.ToolInstaller(home, _tool_install.current_platform(), True, lines.append).install(tool_id)
    except (_tool_install.ToolInstallError, ValueError, OSError) as error:
        return one_line(str(error)) or "install failed"
    return None if code == 0 else one_line(" ".join(lines)) or f"installer exit {code}"


def install_tools(plan: Plan) -> None:
    for tool in plan.missing_tools:
        message = install_tool(plan.home, tool.id)
        add_saved_folders()
        if message is not None:
            reason = f"{tool.id} install failed: {one_line(message)}"
        elif not command_available(tool.command):
            reason = f"{tool.id} installed: open a new terminal, then repeat the add"
        else:
            continue
        for row in plan.accounts:
            if row.tool.id == tool.id and row.command is None:
                row.usable, row.next_step = False, reason


def add_accounts(plan: Plan, say: Callable[[str], None]) -> None:
    for row in plan.accounts:
        if not row.usable:
            continue
        if row.requested:
            adopted = row.adopted or not same_path(row.folder, _managed_folder(row.id, plan.home))
            # The account verb takes the settings lock itself, so no lock is held here.
            try:
                lines = _accounts.add_subscription(plan.home, row.id, row.tool.id, None, str(row.folder) if adopted else None)
            except ERRORS as error:
                raise SetupError(one_line(str(error))) from None
            if not row.new:
                for line in lines:
                    say(line)
        else:
            say(f"skip: account {row.id} (already done)")
        if row.new and not row.adopted:
            row.next_step = f"log in: {_accounts.login_command(row.tool, row.folder, row.command, plan.home)}"


def add_allow_rules(plan: Plan, say: Callable[[str], None]) -> None:
    for row in plan.accounts:
        if not row.usable:
            continue
        # Read again: an earlier account may share this folder, and the file may have changed since the plan.
        missing = _missing_allow_rules(row.tool, row.folder)
        if not missing:
            if row.tool.allow_rules:
                say(f"skip: permission rule in {row.folder} (already done)")
            continue
        file = row.folder / "settings.json"
        owner = _footprints.target_owner(row.tool, row.folder, plan.home)
        # Record only the rules setup adds; a rule the owner already had stays theirs.
        for rule in missing:
            _footprints.add(plan.home, "edit", file, owner, key="permissions.allow", value=rule)
        data = _read_json(file) if file.exists() else {}
        current = [rule for rule in _allowed_rules(file, data) if rule]
        permissions = data.get("permissions")
        if not isinstance(permissions, dict):
            permissions = data["permissions"] = {}
        permissions["allow"] = [*current, *missing]
        _generated.write_generated(file, json.dumps(data, indent=2, ensure_ascii=False) + "\n", executable=False)


def set_path(plan: Plan, say: Callable[[str], None]) -> None:
    if not WINDOWS:
        for line in _user_path.shell_profile_lines(plan.home):
            say(line)
        return
    if not _user_path.add(plan.home, plan.bin):
        say("skip: path (already done)")
    if not path_contains(os.environ.get("PATH", ""), plan.bin):
        os.environ["PATH"] += f";{plan.bin}"


# The plugin goes into an account's folder by the installer module, without questions (yes); its output goes to a log.
# Returns 0 when it finished, 1 when it failed.
def install_plugin(tool_id: str, folder: Path, home: Path, source: Optional[str]) -> int:
    options: dict[str, Any] = {"tools": [tool_id], "config_dir": folder, "update": True, "yes": True}
    if source:
        options["source"] = source
    try:
        output = "\n".join(_installer.install(home, **options))
        code = 0
    except (_installer.InstallerError, _footprints.FootprintError, _launchers.LauncherError, _settings_io.SettingsError, OSError, ValueError) as error:
        output, code = str(error), 1
    log = home / ".legion" / "temp" / f"setup-install-{tool_id}.log"
    log.parent.mkdir(parents=True, exist_ok=True)
    log.write_text(output, encoding="utf-8")
    return code


def install_plugins(plan: Plan, source: Optional[str], say: Callable[[str], None]) -> None:
    results: dict[str, int] = {}
    for row in plan.accounts:
        if not row.usable:
            continue
        # Setup installs legion only where it is missing; moving versions is the update flow's job.
        if row.version:
            say(f"skip: legion in {row.folder} (already done)")
            continue
        key = f"{row.tool.id}:{os.path.normcase(str(resolve_directory(row.folder)))}"
        if key not in results:
            try:
                results[key] = install_plugin(row.tool.id, row.folder, plan.home, source)
            except (OSError, ValueError):
                results[key] = 1
        row.version = _status.installed_version(row.folder, row.tool)
        if results[key] != 0 and row.version is None:
            row.next_step = f"install failed: log in with {row.id}, then finish setup"


def write_commands(plan: Plan, say: Callable[[str], None]) -> None:
    if plan.uv_missing:
        say("uv is missing. Ask the owner before installing it.")
        return
    for row in plan.accounts:
        if row.version:
            owner = _footprints.target_owner(row.tool, row.folder, plan.home)
            for path, _state in plan.commands:
                _footprints.add(plan.home, "file", path, owner)
            _footprints.add(plan.home, "app", plan.home / ".legion" / "app", owner)
    for line in _refresh.refresh(plan.home):
        say(line)
    if any(state == "owned" for _path, state in plan.commands):
        say("skip: command legion (already done)")


def write_table(plan: Plan, say: Callable[[str], None]) -> None:
    if plan.accounts:
        say("account  tool  folder  legion  next step")
        for row in plan.accounts:
            say(f"{row.id}  {row.tool.id}  {row.folder}  {row.version or 'missing'}  {row.next_step}")
    blocked = [path.name.removesuffix(".cmd") for path, state in plan.commands if state == "blocked"]
    if blocked:
        say(f"Blocked commands: {', '.join(dict.fromkeys(blocked))}")


def apply(home: Path, adds: list[str], account_id: Optional[str], source: Optional[str], say: Callable[[str], None]) -> None:
    # A fresh home can reject bad input without creating a lock file or settings folder.
    if not settings_path(home).exists():
        build_plan(home, adds, account_id)
    with _settings_io.writer(home, require_existing=False):
        plan = build_plan(home, adds, account_id)
        initialize_files(plan, say)
    with saved_path():
        install_tools(plan)
        add_accounts(plan, say)
        add_allow_rules(plan, say)
        set_path(plan, say)
        install_plugins(plan, source, say)
        write_commands(plan, say)
    write_table(plan, say)


# --- the owner's flow ---


def interactive() -> bool:
    return sys.stdin.isatty()


def ask() -> str:
    return click.prompt("Apply? [Y/n]", default="", show_default=False, prompt_suffix=" ")


# Without --yes: the plan, then (only when someone can answer) Apply? Otherwise the plan alone, with its hint.
def run(home: Path, adds: list[str], account_id: Optional[str], source: Optional[str], yes: bool, say: Callable[[str], None]) -> None:
    if yes:
        apply(home, adds, account_id, source, say)
        return
    lines = preview(home, adds, account_id)
    if lines[-1] == NOTHING_TO_DO or not interactive():
        for line in lines:
            say(line)
        return
    # The prompt replaces the plan's own hint to run again with --yes.
    for line in lines:
        if line != RUN_AGAIN:
            say(line)
    if ask().strip().lower() in ("", "y", "yes"):
        apply(home, adds, account_id, source, say)
    else:
        say("Nothing changed.")
