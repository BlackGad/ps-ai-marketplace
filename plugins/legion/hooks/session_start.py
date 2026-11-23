# Session-start hook entry: runs the plugin copy's own code with the standard library only.
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "src"))

from legion._hook import main

sys.exit(main(sys.argv[1:]))
