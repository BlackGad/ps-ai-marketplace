import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


# Hand-built, reason: an installed app cannot remove its running Python environment on Windows.
def run(app: Path, arguments: list[str]) -> int:
    app = app.resolve()
    home = app.parents[2]
    with tempfile.TemporaryDirectory(prefix="legion-uninstall-") as scratch:
        root = Path(scratch)
        project = root / "app"
        shutil.copytree(app, project, symlinks=True)
        environment = root / "env"
        command = ["uv", "run", "--project", str(project), "--frozen", "--quiet", "legion", "--home", str(home), *arguments]
        result = subprocess.run(command, env={**os.environ, "UV_PROJECT_ENVIRONMENT": str(environment)}, check=False)
        return result.returncode


if __name__ == "__main__":
    sys.exit(run(Path(sys.argv[1]), sys.argv[2:]))
