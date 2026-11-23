# A stand-in for claude, codex, copilot, git and az. Its wrapper names it in LEGION_FAKE_NAME; the test
# chooses its behavior through LEGION_FAKE_* variables, or LEGION_FAKE_<NAME>_* for one fake only.
import json
import os
import subprocess
import sys
import time
from pathlib import Path

SLEEPER = "import os, sys, time; from pathlib import Path; Path(sys.argv[1]).write_text(str(os.getpid())); time.sleep(60)"


def setting(name: str) -> str:
    return os.environ.get(f"LEGION_FAKE_{name}", "")


# az reads only its own AZ_ settings, so a tool's answer is never az's.
def own_setting(name: str, key: str) -> str:
    value = setting(f"{name.upper()}_{key}")
    return value if value or name == "az" else setting(key)


def write_session(codex_home: Path) -> None:
    folder = codex_home / "sessions" / "2026" / "11" / "22"
    folder.mkdir(parents=True, exist_ok=True)
    records = [line for line in Path(own_setting("codex", "SESSION")).read_text(encoding="utf-8").splitlines() if '"session_meta"' not in line]
    metadata = json.dumps({"type": "session_meta", "payload": {"id": "probe", "cwd": str(Path.cwd())}})
    (folder / "rollout-new.jsonl").write_text("\n".join([metadata, *records]) + "\n", encoding="utf-8")
    if setting("CONCURRENT"):
        other = json.dumps({"type": "session_meta", "payload": {"id": "other", "cwd": "/another-project"}})
        records = Path(own_setting("codex", "SESSION")).read_text(encoding="utf-8").splitlines()
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
    if own_setting(name, "SLEEP"):
        marker = Path(setting("LOG")) / "grandchild.pid"
        subprocess.Popen([sys.executable, "-c", SLEEPER, str(marker)])
        deadline = time.monotonic() + 20
        while not marker.is_file() and time.monotonic() < deadline:
            time.sleep(0.05)
        time.sleep(float(own_setting(name, "SLEEP")))
    if own_setting(name, "STDOUT"):
        sys.stdout.write(Path(own_setting(name, "STDOUT")).read_text(encoding="utf-8"))
    if own_setting(name, "STDERR"):
        sys.stderr.write(Path(own_setting(name, "STDERR")).read_text(encoding="utf-8"))
    if name == "codex" and own_setting(name, "SESSION"):
        write_session(Path(os.environ["CODEX_HOME"]))
    return int(own_setting(name, "EXIT") or "0")


if __name__ == "__main__":
    sys.exit(main())
