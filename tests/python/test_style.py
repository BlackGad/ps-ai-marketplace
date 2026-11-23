import ast
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "plugins/legion/src"


@pytest.mark.parametrize("path", sorted(SOURCE.rglob("*.py")), ids=lambda path: path.relative_to(REPO).as_posix())
def test_no_docstrings(path: Path) -> None:
    tree = ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)) and ast.get_docstring(node) is not None:
            pytest.fail(f"{path.relative_to(REPO).as_posix()}:{node.body[0].lineno}: docstrings are forbidden; use a comment")
