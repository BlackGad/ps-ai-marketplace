
# Run the installed app's production Python CLI while keeping uv itself fake.
import sys
from pathlib import Path

project = Path(sys.argv[sys.argv.index("--project") + 1])
sys.path.insert(0, str(project / "src"))
sys.argv = sys.argv[sys.argv.index("legion"):]

from legion.cli import main

main()
