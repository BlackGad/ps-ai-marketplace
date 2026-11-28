from pathlib import Path

from legion.core._run import run_command


def export_constraints(plugin: Path, uv: str) -> str:
    arguments = ["export", "--frozen", "--no-default-groups", "--extra", "mcp", "--no-emit-project", "--no-hashes"]
    result = run_command(uv, arguments, cwd=plugin, timeout=60)
    if result.exit_code != 0:
        raise RuntimeError(f"uv export failed for {plugin}: {result.error.strip()}")
    return result.output
