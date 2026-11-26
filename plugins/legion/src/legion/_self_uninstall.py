import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


# Hand-built, reason: an installed app cannot remove its running Python environment on Windows.
def run(app: Path, arguments: list[str], uv_copy: Path | None = None) -> int:
    app = app.resolve()
    home = app.parents[2]
    with tempfile.TemporaryDirectory(prefix="legion-uninstall-") as scratch:
        root = Path(scratch)
        project = root / "app"
        shutil.copytree(app, project, symlinks=True)
        environment = root / "env"
        command = [
            str(uv_copy) if uv_copy else "uv",
            "run",
            "--project",
            str(project),
            "--frozen",
            "--no-python-downloads",
            "--no-default-groups",
            "--quiet",
            "legion",
            "--home",
            str(home),
            *arguments,
        ]
        result = subprocess.run(command, env={**os.environ, "UV_PROJECT_ENVIRONMENT": str(environment)}, check=False)
        return result.returncode


if __name__ == "__main__":
    app = Path(sys.argv[1])
    if len(sys.argv) > 3 and sys.argv[2] == "--uv-copy":
        sys.exit(run(app, sys.argv[4:], Path(sys.argv[3])))
    sys.exit(run(app, sys.argv[2:]))
