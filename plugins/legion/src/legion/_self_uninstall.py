# Owner commands written by 0.18.x call this script. Remove it at 1.0.

import hashlib
import os
import subprocess
import sys
from pathlib import Path


def main() -> int:
    app = Path(os.path.normpath(Path(sys.argv[1]).absolute()))
    home = app.parents[2]
    arguments = sys.argv[2:]
    uv = "uv"
    if arguments[:1] == ["--uv-copy"]:
        _, uv, *arguments = arguments

    # Match python_environment without importing the app's dependencies.
    key = str(app.resolve()).rstrip("/\\")
    if sys.platform == "win32":
        key = key.lower()
    digest = hashlib.sha256(key.encode("utf-8")).hexdigest()[:12]
    environment = home / ".legion" / "python" / f"env-{digest}"

    command = [uv, "run", "--project", str(app), "--frozen", "--quiet", "legion", "--home", str(home), *arguments]
    return subprocess.run(command, env={**os.environ, "UV_PROJECT_ENVIRONMENT": str(environment)}, check=False).returncode


if __name__ == "__main__":
    sys.exit(main())
