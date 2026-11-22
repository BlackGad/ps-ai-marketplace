import argparse
import json
from collections.abc import Sequence
from pathlib import Path
from typing import Optional


def main(argv: Optional[Sequence[str]] = None) -> int:
    manifest_path = Path(__file__).resolve().parents[2] / "plugin.json"
    version = json.loads(manifest_path.read_text(encoding="utf-8"))["version"]
    parser = argparse.ArgumentParser(prog="legion-py", description="Legion Python helpers")
    parser.add_argument("--version", action="version", version=f"%(prog)s {version}")
    parser.parse_args(argv)
    parser.print_help()
    return 0
