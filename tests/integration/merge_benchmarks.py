"""
Merge the per-system integration timing files that run.py wrote.

Usage: python merge_benchmarks.py <results folder> <merged file>

Writes `complete=true` to GITHUB_OUTPUT only when each system has exactly one file.
"""

import json
import os
import sys
from pathlib import Path

SYSTEMS = ("windows", "macos", "linux")


def append_line(variable: str, line: str) -> None:
    target = os.environ.get(variable)
    if target:
        with open(target, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")


def merge(results: Path, out_file: Path) -> None:
    entries: list[object] = []
    found_any = False
    complete = True
    for system in SYSTEMS:
        files = sorted(results.rglob(f"integration-bench-{system}.json"))
        if len(files) != 1:
            print(f"::warning::missing integration timing file or duplicate for {system}")
            complete = False
        for file in files:
            found_any = True
            entries.extend(json.loads(file.read_text(encoding="utf-8")))
    if not found_any:
        append_line("GITHUB_STEP_SUMMARY", "No integration timings were produced.")
        return
    out_file.write_text(json.dumps(entries, indent=2) + "\n", encoding="utf-8")
    if complete:
        append_line("GITHUB_OUTPUT", "complete=true")


if __name__ == "__main__":
    merge(Path(sys.argv[1]), Path(sys.argv[2]))
