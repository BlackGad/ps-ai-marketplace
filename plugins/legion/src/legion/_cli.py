import io
import json
import sys
from pathlib import Path
from typing import Optional

import click

from . import _forward


def _show_version(context: click.Context, _parameter: click.Parameter, value: bool) -> None:
    if not value:
        return
    manifest_path = Path(__file__).resolve().parents[2] / "plugin.json"
    version = json.loads(manifest_path.read_text(encoding="utf-8"))["version"]
    click.echo(f"{context.find_root().info_name} {version}")
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


for _verb, _help in _forward.FORWARDED_VERBS.items():
    main.add_command(_forwarded(_verb, _help))
