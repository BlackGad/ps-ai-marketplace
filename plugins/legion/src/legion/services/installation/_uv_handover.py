# Run with the base Python after Legion exits. This helper uses only the standard library.

import os
import shutil
import subprocess
import sys
import time
from pathlib import Path

if sys.platform == "win32":
    import _winapi


def wait_for_exit(pid: int, timeout: float) -> None:
    if sys.platform == "win32":
        try:
            handle = _winapi.OpenProcess(_winapi.SYNCHRONIZE, False, pid)
        except OSError as error:
            if error.winerror == 87:  # ERROR_INVALID_PARAMETER: the process has already exited.
                return
            raise
        try:
            if _winapi.WaitForSingleObject(handle, int(timeout * 1000)) == _winapi.WAIT_OBJECT_0:
                return
        finally:
            _winapi.CloseHandle(handle)
    else:
        deadline = time.monotonic() + timeout
        while True:
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                return
            if time.monotonic() >= deadline:
                break
            time.sleep(0.2)
    raise TimeoutError("Timed out waiting for the legion command to exit")


def main() -> int:
    pids, timeout, remove_count, *words = sys.argv[1:]
    count = int(remove_count)
    try:
        deadline = time.monotonic() + float(timeout)
        for pid in pids.split(","):
            wait_for_exit(int(pid), max(0.0, deadline - time.monotonic()))
        result = subprocess.run(words[count:], check=False)
        print(f"uv tool command exited {result.returncode}", flush=True)
        return result.returncode
    except OSError as error:
        print(f"uv tool handover failed: {error}", file=sys.stderr, flush=True)
        return 1
    finally:
        for path in map(Path, words[:count]):
            try:
                if path.is_dir():
                    shutil.rmtree(path)
                else:
                    path.unlink(missing_ok=True)
            except OSError as error:
                print(f"uv tool handover could not remove {path}: {error}", file=sys.stderr, flush=True)


if __name__ == "__main__":
    sys.exit(main())
