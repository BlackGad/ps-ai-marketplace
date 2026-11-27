import json
import os
import queue
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import (
    Any,
    Optional,
)


# A protocol-speaking fake host. Readiness is initialize + tools/list, never a fixed sleep.
class Connection:
    def __init__(self, home: Path, command: Optional[list[str]] = None) -> None:
        self.error = (home / "mcp-stderr.log").open("wb")
        self.process = subprocess.Popen(command or [sys.executable, "-m", "legion.cli", "--home", str(home), "mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=self.error)
        self.messages: queue.Queue[dict[str, Any]] = queue.Queue()
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _read(self) -> None:
        assert self.process.stdout is not None
        for line in self.process.stdout:
            self.messages.put(json.loads(line))

    def send(self, method: str, params: Optional[dict[str, Any]] = None, request: Optional[int] = None) -> None:
        message: dict[str, Any] = {"jsonrpc": "2.0", "method": method}
        if params is not None:
            message["params"] = params
        if request is not None:
            message["id"] = request
        assert self.process.stdin is not None
        self.process.stdin.write((json.dumps(message) + "\n").encode())
        self.process.stdin.flush()

    def receive(self, request: int) -> dict[str, Any]:
        deadline = time.monotonic() + 30
        while True:
            message = self.messages.get(timeout=max(0.01, deadline - time.monotonic()))
            if message.get("id") == request:
                return message

    def ready(self) -> None:
        self.send("initialize", {"protocolVersion": "2025-06-18", "capabilities": {}, "clientInfo": {"name": "fake-host", "version": "1"}}, 1)
        assert "result" in self.receive(1)
        self.send("notifications/initialized")
        self.send("tools/list", request=2)
        assert {tool["name"] for tool in self.receive(2)["result"]["tools"]} == {"status", "limits"}

    def eof(self) -> None:
        assert self.process.stdin is not None
        self.process.stdin.close()

    def close(self) -> None:
        if self.process.poll() is None:
            self.eof()
            try:
                self.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait(timeout=5)
        self.reader.join(timeout=5)
        assert self.process.stdout is not None
        self.process.stdout.close()
        self.error.close()


# Killing this fake host closes its pipe to the server, without a graceful disconnect.
if __name__ == "__main__":
    connection = Connection(Path(sys.argv[1]))
    try:
        connection.ready()
        connection.send("tools/call", {"name": "limits", "arguments": {"accounts": ["claude-a"]}}, 3)
        pid = Path(sys.argv[2])
        pid.write_text(str(connection.process.pid), encoding="utf-8")
        pid.with_suffix(".ready").touch()
        os.read(sys.stdin.fileno(), 1)
    finally:
        connection.close()
