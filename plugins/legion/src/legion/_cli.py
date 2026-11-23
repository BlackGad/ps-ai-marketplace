import argparse
import json
from collections.abc import Sequence
from pathlib import Path
from typing import Optional

from . import _inbox


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
    args = parser.parse_args(argv)
    if args.command == "inbox":
        if args.action == "send":
            _inbox.send(args.to, args.sender, args.text)
        else:
            _inbox.read(args.repo)
        return 0
    parser.print_help()
    return 0
