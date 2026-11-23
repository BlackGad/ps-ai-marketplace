# A stand-in for claude, codex, copilot, git and az. Its wrapper names it in LEGION_FAKE_NAME; the test
# chooses its behavior through LEGION_FAKE_* variables.
import json
import os
import subprocess
import sys
import time
from pathlib import Path

SLEEPER = "import os, sys, time; from pathlib import Path; Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(60)"


def setting(name: str) -> str:
    return os.environ.get(f"LEGION_FAKE_{name}", "")


def write_session(codex_home: Path) -> None:
    folder = codex_home / "sessions" / "2026" / "11" / "22"
    folder.mkdir(parents=True, exist_ok=True)
    records = [line for line in Path(setting("SESSION")).read_text(encoding="utf-8").splitlines() if '"session_meta"' not in line]
    metadata = json.dumps({"type": "session_meta", "payload": {"id": "probe", "cwd": str(Path.cwd())}})
    (folder / "rollout-new.jsonl").write_text("\n".join([metadata, *records]) + "\n", encoding="utf-8")
    if setting("CONCURRENT"):
        other = json.dumps({"type": "session_meta", "payload": {"id": "other", "cwd": "/another-project"}})
        records = Path(setting("SESSION")).read_text(encoding="utf-8").splitlines()
        (folder / "rollout-concurrent.jsonl").write_text("\n".join([other, *records]) + "\n", encoding="utf-8")


def main() -> int:
    name = setting("NAME")
    call = {
        "arguments": sys.argv[1:],
        "folder": str(Path.cwd()),
        "stdin": sys.stdin.read(),
        "config": {key: os.environ.get(key) for key in ("CLAUDE_CONFIG_DIR", "CODEX_HOME", "COPILOT_HOME", "AZURE_CONFIG_DIR")},
    }
    with (Path(setting("LOG")) / f"{name}.jsonl").open("a", encoding="utf-8") as log:
        log.write(json.dumps(call) + "\n")
    if name == "git":
        (Path(sys.argv[2]) / ".git").mkdir()
        return 0
    prefix = "AZ_" if name == "az" else ""
    if setting(prefix + "SLEEP"):
        marker = Path(setting("LOG")) / "grandchild.pid"
        subprocess.Popen([sys.executable, "-c", SLEEPER, str(marker)])  # noqa: S603
        deadline = time.monotonic() + 20
        while not marker.is_file() and time.monotonic() < deadline:
            time.sleep(0.05)
        time.sleep(float(setting(prefix + "SLEEP")))
    if setting(prefix + "STDOUT"):
        sys.stdout.write(Path(setting(prefix + "STDOUT")).read_text(encoding="utf-8"))
    if setting(prefix + "STDERR"):
        sys.stderr.write(Path(setting(prefix + "STDERR")).read_text(encoding="utf-8"))
    if name == "codex" and setting("SESSION"):
        write_session(Path(os.environ["CODEX_HOME"]))
    return int(setting(prefix + "EXIT") or "0")


if __name__ == "__main__":
    sys.exit(main())
