import argparse
import json
from collections.abc import Sequence
from pathlib import Path
from typing import Optional

from . import _bridge, _inbox, _telegram


def main(argv: Optional[Sequence[str]] = None) -> int:
    manifest_path = Path(__file__).resolve().parents[2] / "plugin.json"
    version = json.loads(manifest_path.read_text(encoding="utf-8"))["version"]
    parser = argparse.ArgumentParser(prog="legion-py", description="Legion Python helpers")
    parser.add_argument("--version", action="version", version=f"%(prog)s {version}")
    commands = parser.add_subparsers(dest="command")
    inbox = commands.add_parser("inbox", help="Send or read repository overseer messages")
    actions = inbox.add_subparsers(dest="action", required=True)
    send = actions.add_parser("send", help="Send a message to a repository overseer")
    send.add_argument("--to", required=True, type=Path)
    send.add_argument("--from", dest="sender", required=True)
    send.add_argument("--text", required=True)
    read = actions.add_parser("read", help="Read this repository's inbox")
    read.add_argument("--repo", type=Path, default=Path.cwd())
    telegram = commands.add_parser("telegram", help="Send to Telegram or bridge its messages into the inbox")
    telegram_actions = telegram.add_subparsers(dest="action", required=True)
    telegram_send = telegram_actions.add_parser("send", help="Send a message or files through a channel's bot")
    telegram_send.add_argument("--channel", required=True)
    telegram_send.add_argument("--chat", required=True)
    telegram_send.add_argument("--text", required=True)
    telegram_send.add_argument("--format", dest="text_format", choices=["text", "markdownv2"], default="text")
    telegram_send.add_argument("--reply-to", type=int)
    telegram_send.add_argument("--file", dest="files", action="append", default=[], type=Path)
    telegram_react = telegram_actions.add_parser("react", help="React to a message")
    telegram_react.add_argument("--channel", required=True)
    telegram_react.add_argument("--chat", required=True)
    telegram_react.add_argument("--message", required=True)
    telegram_react.add_argument("--emoji", required=True)
    bridge = telegram_actions.add_parser("bridge", help="Poll a channel's bot and write owner messages into the repository inbox")
    bridge.add_argument("--channel", required=True)
    bridge.add_argument("--repo", required=True, type=Path)
    args = parser.parse_args(argv)
    if args.command == "telegram":
        if args.action == "send":
            return _telegram.send(args.channel, args.chat, args.text, args.text_format, args.reply_to, args.files)
        if args.action == "react":
            return _telegram.react(args.channel, args.chat, args.message, args.emoji)
        return _bridge.run(args.channel, args.repo)
    if args.command == "inbox":
        if args.action == "send":
            _inbox.send(args.to, args.sender, args.text)
        else:
            _inbox.read(args.repo)
        return 0
    parser.print_help()
    return 0
