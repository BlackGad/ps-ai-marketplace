# A stand-in for claude, codex, copilot, git and az. Its wrapper names it in LEGION_FAKE_NAME; the test
# chooses its behavior through LEGION_FAKE_* variables, or LEGION_FAKE_<NAME>_* for one fake only.
import json
import os
import subprocess
import sys
import time
from pathlib import Path

# The grandchild publishes its pid through a sibling file, so a reader that sees the file sees all of it.
SLEEPER = "import os, sys, time; from pathlib import Path; part = Path(sys.argv[1] + '.part'); part.write_text(str(os.getpid())); part.replace(sys.argv[1]); time.sleep(60)"


def setting(name: str) -> str:
    return os.environ.get(f"LEGION_FAKE_{name}", "")


# az and git read only their own AZ_ and GIT_ settings, so a tool's answer is never theirs.
def own_setting(name: str, key: str) -> str:
    value = setting(f"{name.upper()}_{key}")
    return value if value or name in ("az", "git") else setting(key)


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
        "pid": os.getpid(),
        "arguments": sys.argv[1:],
        "folder": str(Path.cwd()),
        "stdin": sys.stdin.read(),
        "config": {key: os.environ.get(key) for key in ("CLAUDE_CONFIG_DIR", "CODEX_HOME", "COPILOT_HOME", "AZURE_CONFIG_DIR")},
    }
    # Keep only the variables asserted by the Foundry tests; the parent may carry credentials.
    names = (
        "LEGION_HOME",
        "CLAUDE_CONFIG_DIR",
        "CODEX_HOME",
        "COPILOT_HOME",
        "COPILOT_PROVIDERS_CONFIG",
        "CLAUDE_CODE_USE_FOUNDRY",
        "ANTHROPIC_FOUNDRY_BASE_URL",
        "ANTHROPIC_MODEL",
        "ANTHROPIC_DEFAULT_OPUS_MODEL",
        "CLAUDE_CODE_USE_BEDROCK",
    )
    call["environment"] = {name: os.environ[name] for name in names if name in os.environ}
    call["foundry_names"] = sorted(name for name in os.environ if name.startswith("ANTHROPIC_FOUNDRY"))
    providers = Path(os.environ.get("COPILOT_PROVIDERS_CONFIG", ""))
    fake_home = setting("HOME")
    fixture_temp = Path(fake_home) / ".legion" / "temp" if fake_home else None
    call["providers"] = providers.read_text(encoding="utf-8") if fixture_temp and providers.resolve().parent == fixture_temp.resolve() and providers.is_file() else None
    with (Path(setting("LOG")) / f"{name}.jsonl").open("a", encoding="utf-8") as log:
        log.write(json.dumps(call) + "\n")
    if name == "az" and setting("AZ_ANSWERS"):
        # Foundry tests choose one fake response per az argument list; no Azure command or network runs.
        answers = json.loads(Path(setting("AZ_ANSWERS")).read_text(encoding="utf-8"))
        answer = answers.get(" ".join(sys.argv[1:]), {"exit": 1, "stderr": "unexpected fake az call"})
        sys.stdout.write(answer.get("stdout", ""))
        sys.stderr.write(answer.get("stderr", ""))
        return int(answer.get("exit", 0))
    if name == "git" and not own_setting(name, "EXIT") and not own_setting(name, "SLEEP"):
        (Path(sys.argv[2]) / ".git").mkdir()
        return 0
    if own_setting(name, "SLEEP"):
        marker = Path(setting("LOG")) / "grandchild.pid"
        subprocess.Popen([sys.executable, "-c", SLEEPER, str(marker)], start_new_session=bool(own_setting(name, "DETACH")))
        deadline = time.monotonic() + 20
        while not marker.is_file() and time.monotonic() < deadline:
            time.sleep(0.05)
        if own_setting(name, "REPARENT"):
            # Give the owner a poll to observe the detached child, then leave it holding
            # the output pipes so cancellation must use its retained process identity.
            time.sleep(0.5)
            return 0
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
