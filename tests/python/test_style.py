import ast
import io
import tokenize
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "plugins/legion/src"
HOOKS = REPO / "plugins/legion/hooks"


def test_python_files_have_no_inline_suppressions() -> None:
    for path in [*SOURCE.rglob("*.py"), *HOOKS.rglob("*.py"), *(REPO / "tests/python").rglob("*.py")]:
        comments = (token for token in tokenize.generate_tokens(io.StringIO(path.read_text(encoding="utf-8-sig")).readline) if token.type == tokenize.COMMENT)
        for token in comments:
            for suppression in ("noqa", "type: ignore", "pyright: ignore"):
                assert suppression not in token.string, f"{path.relative_to(REPO)}:{token.start[0]}"


# The autouse fence shares the test's monkeypatch, so undo() would also lift the fence; use pytest.MonkeyPatch.context().
def test_tests_never_undo_the_shared_monkeypatch() -> None:
    for path in (REPO / "tests/python").rglob("*.py"):
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr == "undo" and isinstance(node.func.value, ast.Name) and node.func.value.id == "monkeypatch":
                pytest.fail(f"{path.relative_to(REPO).as_posix()}:{node.lineno}: monkeypatch.undo() also undoes the fence")


@pytest.mark.parametrize("path", sorted([*SOURCE.rglob("*.py"), *HOOKS.glob("*.py"), *(REPO / "tests/python").rglob("*.py")]), ids=lambda path: path.relative_to(REPO).as_posix())
def test_no_docstrings(path: Path) -> None:
    tree = ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.ClassDef, ast.FunctionDef, ast.AsyncFunctionDef)) and ast.get_docstring(node) is not None:
            pytest.fail(f"{path.relative_to(REPO).as_posix()}:{node.body[0].lineno}: docstrings are forbidden; use a comment")
