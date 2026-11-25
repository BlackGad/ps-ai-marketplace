import io
import os
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Literal, Optional

import click

from . import _forward, _home, _plugin


def _show_version(context: click.Context, _parameter: click.Parameter, value: bool) -> None:
    if not value:
        return
    from ._settings_models import PluginManifest

    manifest = PluginManifest.model_validate_json((_plugin.PLUGIN_ROOT / "plugin.json").read_text(encoding="utf-8"))
    click.echo(f"{context.find_root().info_name} {manifest.version}")
    context.exit()


# Flags before any verb (`legion --no-channel`) belong to the Python overseer launch.
class _LegionGroup(click.Group):
    def resolve_command(self, ctx: click.Context, args: list[str]) -> tuple[Optional[str], Optional[click.Command], list[str]]:
        if args and args[0].startswith("-"):
            return "", _launch_command(""), args
        return super().resolve_command(ctx, args)


def _forwarded(verb: str, help_text: Optional[str] = None) -> click.Command:
    @click.pass_context
    def forward(context: click.Context, words: tuple[str, ...]) -> None:
        context.exit(_forward.run([verb, *words] if verb else list(words), context.obj))

    words = click.Argument(["words"], nargs=-1, type=click.UNPROCESSED)
    return click.Command(verb, callback=forward, params=[words], help=help_text, context_settings={"ignore_unknown_options": True}, add_help_option=False)


@click.group(cls=_LegionGroup, invoke_without_command=True, context_settings={"ignore_unknown_options": True}, help="Legion commands")
@click.option("--version", is_flag=True, is_eager=True, expose_value=False, callback=_show_version, help="Show the version and exit.")
@click.option("--home", type=click.Path(path_type=Path), help="Use this folder instead of the user's home folder.")
@click.pass_context
def main(context: click.Context, home: Optional[Path]) -> None:
    # A pipe on Windows defaults to the ANSI code page; messages carry any text.
    for stream in (sys.stdout, sys.stderr):
        if isinstance(stream, io.TextIOWrapper):
            stream.reconfigure(encoding="utf-8")
    # The Windows command passes its home as <home>/.legion/bin/../..
    if home is not None:
        home = Path(os.path.normpath(home)).absolute()
    context.obj = home
    if context.invoked_subcommand is None:
        _report_overseer(context, Path.cwd())


def _report_overseer(
    context: click.Context,
    repo: Path,
    *,
    account: Optional[str] = None,
    tool: Optional[str] = None,
    channels: tuple[str, ...] = (),
    no_channel: bool = False,
    dry_run: bool = False,
    arguments: tuple[str, ...] = (),
    pick: bool = False,
) -> None:
    from . import _overseer
    from ._channel import ChannelError
    from ._repository import RepositoryError
    from ._settings_io import SettingsError

    try:
        context.exit(_overseer.run(repo, _home.legion_home(context.obj), account=account, tool=tool, channels=channels, no_channel=no_channel, dry_run=dry_run, arguments=arguments, pick=pick))
    except (ChannelError, RepositoryError, SettingsError, _overseer.OverseerError, OSError, ValueError) as error:
        click.echo(" ".join(str(error).split()), err=True)
        context.exit(1)


def _launch_command(verb: str) -> click.Command:
    @click.command(verb, help="Choose which account leads the overseer" if verb else "Start the overseer")
    @click.option("--account")
    @click.option("--tool")
    @click.option("--channel", "channels", multiple=True)
    @click.option("--no-channel", is_flag=True)
    @click.option("--dry-run", is_flag=True)
    @click.option("--repo", type=click.Path(path_type=Path))
    @click.option("--argument", "arguments", multiple=True, help="A literal tool argument; repeat for each word (use --argument=--flag for flags).")
    @click.pass_context
    def launch(
        context: click.Context, account: Optional[str], tool: Optional[str], channels: tuple[str, ...], no_channel: bool, dry_run: bool, repo: Optional[Path], arguments: tuple[str, ...]
    ) -> None:
        _report_overseer(context, repo=repo or Path.cwd(), account=account, tool=tool, channels=channels, no_channel=no_channel, dry_run=dry_run, arguments=arguments, pick=verb == "pick")

    return launch


@main.command("validate", help="Check a settings or project file against its schema")
@click.option("--kind", required=True, type=click.Choice(["personalisation", "project"]))
@click.option("--path", "path", required=True, type=click.Path(path_type=Path))
@click.pass_context
def validate(context: click.Context, kind: str, path: Path) -> None:
    from . import _validate

    issues = _validate.validate(kind, path)
    for issue in issues:
        click.echo(issue)
    context.exit(1 if issues else 0)


@main.command("update", help="Check for updates, or update legion to the newest version of its track")
@click.option("--check", is_flag=True, help="Check for updates without installing.")
@click.option("--force", is_flag=True, help="Check again even if today's result is cached; requires --check.")
@click.option("--yes", is_flag=True, help="Confirm the update without prompting.")
@click.pass_context
def update(context: click.Context, check: bool, force: bool, yes: bool) -> None:
    if force and not check:
        raise click.UsageError("--force requires --check")
    if check and yes:
        raise click.UsageError("--yes cannot be used with --check")
    if check:
        from . import _update

        for line in _update.check_lines(_plugin.PLUGIN_ROOT, context.obj, force=force):
            click.echo(line)
        return
    from . import _installer

    _report_installer(context, lambda: _installer.install(_home.legion_home(context.obj), update=True, yes=yes))


def _report_installer(context: click.Context, change: Callable[[], list[str]]) -> None:
    from ._installer import InstallerError
    from ._footprints import FootprintError
    from ._launchers import LauncherError
    from ._settings_io import SettingsError

    try:
        for line in change():
            click.echo(line)
    except (InstallerError, FootprintError, LauncherError, SettingsError, OSError, ValueError) as error:
        click.echo(str(error), err=True)
        context.exit(1)


@main.command("install", help="Install legion for one or more coding CLIs")
@click.option("--tool", "tools", multiple=True, help="CLI target; repeat or separate with commas")
@click.option("--source", default="BlackGad/ps-legion-marketplace")
@click.option("--ref", "ref", type=click.Choice(["release", "main"]), default="release")
@click.option("--config-dir", type=click.Path(path_type=Path))
@click.option("--dry-run", is_flag=True)
@click.option("--yes", is_flag=True)
@click.option("--update", is_flag=True, help="Update installed targets instead of installing.")
@click.option("--uninstall", is_flag=True, help="Remove installed targets instead of installing.")
@click.option("--purge", is_flag=True, help="Also remove recorded settings and data; requires --uninstall.")
@click.pass_context
def install(context: click.Context, tools: tuple[str, ...], source: str, ref: str, config_dir: Optional[Path], dry_run: bool, yes: bool, update: bool, uninstall: bool, purge: bool) -> None:
    from . import _installer

    _report_installer(
        context,
        lambda: _installer.install(
            _home.legion_home(context.obj), tools=list(tools), source=source, ref=ref, config_dir=config_dir, dry_run=dry_run, yes=yes, update=update, uninstall=uninstall, purge=purge
        ),
    )


@main.command("uninstall", help="Remove legion; --purge also deletes settings, notes and logins")
@click.option("--tool", "tools", multiple=True, help="CLI target; repeat or separate with commas")
@click.option("--config-dir", type=click.Path(path_type=Path))
@click.option("--purge", is_flag=True)
@click.option("--dry-run", is_flag=True)
@click.option("--yes", is_flag=True)
@click.pass_context
def uninstall(context: click.Context, tools: tuple[str, ...], config_dir: Optional[Path], purge: bool, dry_run: bool, yes: bool) -> None:
    from . import _installer

    _report_installer(context, lambda: _installer.install(_home.legion_home(context.obj), list(tools), config_dir=config_dir, dry_run=dry_run, yes=yes, uninstall=True, purge=purge))


@main.command("status", help="Show accounts, commands, channels and this repository")
@click.pass_obj
def status(home: Optional[Path]) -> None:
    from . import _status

    for line in _status.status_lines(Path.cwd(), home):
        click.echo(line)


@main.command("limits", help="Show each account's usage windows and reset times (or one account)")
@click.option("--id", "account", help="one account instead of every account")
@click.pass_context
def limits(context: click.Context, account: Optional[str]) -> None:
    from .limits import LimitsError, report_lines

    try:
        lines = report_lines(context.obj, account)
    except LimitsError as error:
        click.echo(str(error), err=True)
        context.exit(1)
    for line in lines:
        click.echo(line)


@main.group(help="Send or read repository overseer messages")
def inbox() -> None:
    pass


@inbox.command("send", help="Send a message to a repository overseer")
@click.option("--to", "target", required=True, type=click.Path(path_type=Path))
@click.option("--from", "sender", help="the sender's repository path (default: current folder)")
@click.option("--text", required=True)
@click.pass_obj
def inbox_send(home: Optional[Path], target: Path, sender: Optional[str], text: str) -> None:
    from . import _inbox

    sender = sender or str(Path.cwd().resolve())
    if sender.strip().lower() == "telegram":
        raise click.UsageError("--from telegram is reserved for the Telegram bridge")
    if not target.is_dir():
        raise click.UsageError(f"--to {target} is not an existing folder")
    _inbox.send(target, sender, text, home)


@inbox.command("read", help="Read this repository's inbox")
@click.option("--repo", type=click.Path(path_type=Path), default=None)
@click.pass_obj
def inbox_read(home: Optional[Path], repo: Optional[Path]) -> None:
    from . import _inbox

    _inbox.read(repo or Path.cwd(), home)


@main.group(help="Send to Telegram or bridge its messages into the inbox")
def telegram() -> None:
    pass


@telegram.command("send", help="Send a message or files through a channel's bot")
@click.option("--channel", required=True)
@click.option("--chat", required=True)
@click.option("--text", required=True)
@click.option("--format", "text_format", type=click.Choice(["text", "markdownv2"]), default="text")
@click.option("--reply-to", type=int)
@click.option("--file", "files", multiple=True, type=click.Path(path_type=Path))
@click.pass_context
def telegram_send(context: click.Context, channel: str, chat: str, text: str, text_format: str, reply_to: Optional[int], files: tuple[Path, ...]) -> None:
    from . import _telegram

    context.exit(_telegram.send(channel, chat, text, text_format, reply_to, list(files), home=context.obj))


@telegram.command("react", help="React to a message")
@click.option("--channel", required=True)
@click.option("--chat", required=True)
@click.option("--message", required=True)
@click.option("--emoji", required=True)
@click.pass_context
def telegram_react(context: click.Context, channel: str, chat: str, message: str, emoji: str) -> None:
    from . import _telegram

    context.exit(_telegram.react(channel, chat, message, emoji, home=context.obj))


@telegram.command("bridge", help="Poll a channel's bot and write owner messages into the repository inbox")
@click.option("--channel", required=True)
@click.option("--repo", required=True, type=click.Path(path_type=Path))
@click.pass_context
def telegram_bridge(context: click.Context, channel: str, repo: Path) -> None:
    from . import _bridge

    context.exit(_bridge.run(channel, repo, home=context.obj))


@main.group(help="Take, check or release this repository's overseer lease")
def lease() -> None:
    pass


_repo_option = click.option("--repo", type=click.Path(path_type=Path), default=None, help="the repository (default: current folder)")
_process_option = click.option("--process-id", type=int, help="the owner session's process id (default: the agent session that runs legion)")


# Prints the lease message, or its refusal on stderr with exit code 1.
def _report_lease(context: click.Context, change: Callable[[], str]) -> None:
    from ._lease import LeaseError

    try:
        click.echo(change())
    except LeaseError as error:
        click.echo(str(error), err=True)
        context.exit(1)


@lease.command("take", help="Take the lease for this session; a stale lease is replaced")
@_repo_option
@click.option("--tool", required=True)
@click.option("--account", required=True)
@_process_option
@click.pass_context
def lease_take(context: click.Context, repo: Optional[Path], tool: str, account: str, process_id: Optional[int]) -> None:
    from . import _lease

    _report_lease(context, lambda: _lease.take(repo or Path.cwd(), tool, account, process_id))


@lease.command("status", help="Print free, held, stale or foreign")
@_repo_option
def lease_status(repo: Optional[Path]) -> None:
    from . import _lease

    click.echo(_lease.state(repo or Path.cwd()).state)


@lease.command("release", help="Release the lease if this session holds it")
@_repo_option
@_process_option
@click.pass_context
def lease_release(context: click.Context, repo: Optional[Path], process_id: Optional[int]) -> None:
    from . import _lease

    _report_lease(context, lambda: _lease.release(repo or Path.cwd(), process_id))


@main.group(help="Set up this repository for legion orchestration")
def repository() -> None:
    pass


@repository.command("setup", help="Create and commit Private or Shared orchestration files")
@_repo_option
@click.option("--mode", type=click.Choice(["private", "shared"], case_sensitive=False), default="private")
@click.option("--gate")
@click.option("--rules-file")
@click.pass_context
def repository_setup(context: click.Context, repo: Optional[Path], mode: Literal["private", "shared"], gate: Optional[str], rules_file: Optional[str]) -> None:
    from . import _repository

    try:
        lines = _repository.setup(repo or Path.cwd(), mode, gate, rules_file)
    except _repository.RepositoryError as error:
        click.echo(" ".join(str(error).split()), err=True)
        context.exit(1)
    for line in lines:
        click.echo(line)


@main.group(help="Add, remove or check the owner's channel bindings")
def channel() -> None:
    pass


# Runs one channel change and prints its line, or its refusal on stderr with exit code 1.
def _report_channel(context: click.Context, change: Callable[[], list[str]]) -> None:
    from ._channel import ChannelError
    from ._settings_io import SettingsError

    try:
        lines = change()
    except (ChannelError, SettingsError) as error:
        click.echo(" ".join(str(error).split()), err=True)
        context.exit(1)
    for line in lines:
        click.echo(line)


_channel_kind_option = click.option("--kind", required=True, help="the channel kind, such as telegram")
_channel_accounts_option = click.option("--account", "accounts", required=True, multiple=True, help="an account id; repeat for each account")


@channel.command("add", help="Bind a channel to accounts")
@click.option("--id", "channel_id", required=True)
@_channel_kind_option
@click.option("--target", required=True, help="the destination, such as a Telegram chat id")
@_channel_accounts_option
@click.pass_context
def channel_add(context: click.Context, channel_id: str, kind: str, target: str, accounts: tuple[str, ...]) -> None:
    from . import _channel

    _report_channel(context, lambda: [_channel.add(_home.legion_home(context.obj), channel_id, kind, target, list(accounts))])


@channel.command("remove", help="Remove a channel binding")
@click.option("--id", "channel_id", required=True)
@click.pass_context
def channel_remove(context: click.Context, channel_id: str) -> None:
    from . import _channel

    _report_channel(context, lambda: [_channel.remove(_home.legion_home(context.obj), channel_id)])


@channel.command("check", help="Show what a channel needs for each account, without starting any CLI")
@_channel_kind_option
@_channel_accounts_option
@click.pass_context
def channel_check(context: click.Context, kind: str, accounts: tuple[str, ...]) -> None:
    from . import _channel

    _report_channel(context, lambda: _channel.check(_home.legion_home(context.obj), kind, list(accounts)))


@main.group(help="Add, register, rename or remove accounts")
def account() -> None:
    pass


# Runs one account change and prints its lines, or its refusal on stderr with exit code 1.
def _report_account(context: click.Context, change: Callable[[], list[str]]) -> None:
    from ._accounts import AccountError
    from ._footprints import FootprintError
    from ._launchers import LauncherError
    from ._settings_io import SettingsError
    from pydantic import ValidationError

    try:
        lines = change()
    except (AccountError, FootprintError, LauncherError, SettingsError, ValidationError, ValueError, OSError) as error:
        click.echo(" ".join(str(error).split()), err=True)
        context.exit(1)
    for line in lines:
        click.echo(line)


_account_id_option = click.option("--id", "account_id", required=True, help="the account id")
_account_tool_option = click.option("--tool", "tool_id", required=True, help="the tool, such as claude, codex or copilot")


@account.command("add", help="Add a subscription account, or repair the launchers of an existing one")
@_account_id_option
@_account_tool_option
@click.option("--command", help="the account's own CLI program, when it is not the tool's stock command")
@click.option("--config-dir", help="an existing account folder to adopt")
@click.option("--provider", type=click.Choice(["foundry"]))
@click.option("--endpoint")
@click.option("--deployment", "deployments", multiple=True)
@click.option("--default", "default_model")
@click.option("--alias", "aliases", multiple=True)
@click.option("--standard", is_flag=True)
@click.option("--list", "list_only", is_flag=True)
@click.pass_context
def account_add(
    context: click.Context,
    account_id: str,
    tool_id: str,
    command: Optional[str],
    config_dir: Optional[str],
    provider: Optional[str],
    endpoint: Optional[str],
    deployments: tuple[str, ...],
    default_model: Optional[str],
    aliases: tuple[str, ...],
    standard: bool,
    list_only: bool,
) -> None:
    from . import _accounts

    if standard and (aliases or default_model):
        raise click.UsageError("--standard cannot be combined with --alias or --default")
    if standard and provider != "foundry":
        raise click.UsageError("--standard is only for Foundry add or models")
    if provider == "foundry":
        if config_dir:
            raise click.UsageError("--config-dir is for existing subscription accounts; omit it for Foundry.")
        if not endpoint:
            raise click.UsageError("--endpoint is required for Foundry")
        _report_account(context, lambda: _accounts.add_foundry(_home.legion_home(context.obj), account_id, tool_id, endpoint, list(deployments), default_model, list(aliases), standard, list_only))
        return
    _report_account(context, lambda: _accounts.add_subscription(_home.legion_home(context.obj), account_id, tool_id, command, config_dir))


@account.command("models", help="Show or change a Foundry account's deployments")
@_account_id_option
@click.option("--deployment", "deployments", multiple=True)
@click.option("--default", "default_model")
@click.option("--alias", "aliases", multiple=True)
@click.option("--standard", is_flag=True)
@click.option("--list", "list_only", is_flag=True)
@click.pass_context
def account_models(context: click.Context, account_id: str, deployments: tuple[str, ...], default_model: Optional[str], aliases: tuple[str, ...], standard: bool, list_only: bool) -> None:
    from . import _accounts

    if standard and (aliases or default_model):
        raise click.UsageError("--standard cannot be combined with --alias or --default")
    selected_aliases = [] if aliases == ("",) else list(aliases) if aliases else None
    _report_account(context, lambda: _accounts.models(_home.legion_home(context.obj), account_id, list(deployments), default_model, selected_aliases, standard, list_only))


# Runs setup (or add) and prints its lines, or its refusal on stderr with exit code 1.
def _run_setup(context: click.Context, adds: list[str], account_id: Optional[str], source: Optional[str], yes: bool) -> None:
    from . import _setup

    try:
        _setup.run(_home.legion_home(context.obj), adds, account_id, source, yes, click.echo)
    except _setup.ERRORS as error:
        click.echo(" ".join(str(error).split()), err=True)
        context.exit(1)


@main.command("setup", help="Finish setup: settings, commands, legion in every account")
@click.option("--yes", is_flag=True, help="Apply without asking.")
@click.pass_context
def setup(context: click.Context, yes: bool) -> None:
    _run_setup(context, [], None, None, yes)


@main.command("add", help="Add a claude, codex or copilot account")
@click.argument("tool")
@click.argument("folder", required=False)
@click.option("--yes", is_flag=True, help="Apply without asking.")
@click.option("--id", "account_id", hidden=True, help="the account id, for one add")
@click.option("--source", hidden=True, help="where the plugin installer takes legion from")
@click.pass_context
def add(context: click.Context, tool: str, folder: Optional[str], yes: bool, account_id: Optional[str], source: Optional[str]) -> None:
    # The setup code splits the item on its first colon, so a folder may contain colons.
    _run_setup(context, [f"{tool}:{folder}" if folder is not None else tool], account_id, source, yes)


@main.group(help="Check and install the CLI tools legion needs")
def tool() -> None:
    pass


@tool.command("install", help="Show what installing a tool would do; with --yes, install it")
@click.option("--tool", "tool_id", required=True, help="the tool, such as claude, git or uv")
@click.option("--yes", is_flag=True, help="the owner agreed: run the install")
@click.option("--method", type=click.Choice(["winget", "msi", "zip"]), help="Windows only: how to install")
@click.pass_context
def tool_install(context: click.Context, tool_id: str, yes: bool, method: Optional[str]) -> None:
    from ._tool_install import ToolInstaller, ToolInstallError, current_platform

    try:
        context.exit(ToolInstaller(_home.legion_home(context.obj), current_platform(), yes, click.echo).install(tool_id, method))
    except (ToolInstallError, ValueError, OSError) as error:
        click.echo(" ".join(str(error).split()), err=True)
        context.exit(1)


@main.group("foundry", hidden=True)
def foundry() -> None:
    pass


@foundry.command("run", add_help_option=False, context_settings={"ignore_unknown_options": True, "allow_interspersed_args": False})
@click.option("--account", required=True)
@click.argument("arguments", nargs=-1, type=click.UNPROCESSED)
@click.pass_context
def foundry_run(context: click.Context, account: str, arguments: tuple[str, ...]) -> None:
    from .foundry._run import run
    from ._settings_io import SettingsError

    try:
        context.exit(run(account, list(arguments), _home.legion_home(context.obj)))
    except (ValueError, OSError, SettingsError) as error:
        click.echo(" ".join(str(error).split()), err=True)
        context.exit(1)


@main.command("refresh", hidden=True)
@click.pass_context
def refresh(context: click.Context) -> None:
    from ._refresh import refresh as change

    _report_account(context, lambda: change(_home.legion_home(context.obj)))


@account.command("register", help="Register an existing account folder and the program that runs it")
@_account_id_option
@_account_tool_option
@click.option("--command", required=True, help="the program that runs the account")
@click.option("--config-dir", required=True, help="the account's existing folder")
@click.pass_context
def account_register(context: click.Context, account_id: str, tool_id: str, command: str, config_dir: str) -> None:
    from . import _accounts

    _report_account(context, lambda: _accounts.add_subscription(_home.legion_home(context.obj), account_id, tool_id, command, config_dir))


@account.command("rename", help="Give an account a new id; its folder stays")
@_account_id_option
@click.option("--new-id", required=True, help="the new account id")
@click.pass_context
def account_rename(context: click.Context, account_id: str, new_id: str) -> None:
    from . import _accounts

    _report_account(context, lambda: _accounts.rename(_home.legion_home(context.obj), account_id, new_id))


# `legion remove` and `legion account remove` are the same command under two names.
def _remove_account(context: click.Context, account_id: str) -> None:
    from . import _accounts

    _report_account(context, lambda: _accounts.remove(_home.legion_home(context.obj), account_id))


@account.command("remove", help="Remove an account (its folder is kept)")
@_account_id_option
@click.pass_context
def account_remove(context: click.Context, account_id: str) -> None:
    _remove_account(context, account_id)


@main.command("remove", help="Remove an account (its folder is kept)")
@_account_id_option
@click.pass_context
def remove(context: click.Context, account_id: str) -> None:
    _remove_account(context, account_id)


main.add_command(_launch_command("pick"))

for _verb, _help in _forward.FORWARDED_VERBS.items():
    main.add_command(_forwarded(_verb, _help))


if __name__ == "__main__":
    main()
