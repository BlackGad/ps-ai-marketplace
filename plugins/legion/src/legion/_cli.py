import io
import os
import sys
from collections.abc import Callable
from pathlib import Path
from typing import Optional

import click

from . import _forward, _home, _plugin


def _show_version(context: click.Context, _parameter: click.Parameter, value: bool) -> None:
    if not value:
        return
    from ._settings_models import PluginManifest

    manifest = PluginManifest.model_validate_json((_plugin.PLUGIN_ROOT / "plugin.json").read_text(encoding="utf-8"))
    click.echo(f"{context.find_root().info_name} {manifest.version}")
    context.exit()


# Flags before any verb (`legion --no-channel`) belong to the overseer launch, so they forward with no verb.
class _LegionGroup(click.Group):
    def resolve_command(self, ctx: click.Context, args: list[str]) -> tuple[Optional[str], Optional[click.Command], list[str]]:
        if args and args[0].startswith("-"):
            return "", _forwarded(""), args
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
        home = Path(os.path.normpath(home))
    context.obj = home
    if context.invoked_subcommand is None:
        context.exit(_forward.run([], home))


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
    context.exit(_forward.run(["update", *(["--yes"] if yes else [])], context.obj))


@main.command("status", help="Show accounts, commands, channels and this repository")
@click.pass_obj
def status(home: Optional[Path]) -> None:
    from . import _status

    for line in _status.status_lines(Path.cwd(), home):
        click.echo(line)


@main.command("limits", help="Show each account's usage windows and reset times (or one account)")
@click.argument("account", required=False)
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


for _verb, _help in _forward.FORWARDED_VERBS.items():
    main.add_command(_forwarded(_verb, _help))
