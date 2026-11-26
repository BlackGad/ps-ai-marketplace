import ast
import io
import tokenize
import subprocess
import sys
from pathlib import Path

import pytest

REPO = Path(__file__).resolve().parents[2]
SOURCE = REPO / "plugins/legion/src"
HOOKS = REPO / "plugins/legion/hooks"


def test_mcp_sdk_imports_stay_in_mcp_package() -> None:
    for path in SOURCE.rglob("*.py"):
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8-sig"))):
            names = [alias.name for alias in node.names] if isinstance(node, ast.Import) else [node.module or ""] if isinstance(node, ast.ImportFrom) else []
            if any(name == "mcp" or name.startswith("mcp.") for name in names):
                assert path.is_relative_to(SOURCE / "legion/mcp"), path


def test_hook_and_cli_import_no_mcp() -> None:
    script = "import sys, legion.cli, legion.hook\nassert not any(name == 'mcp' or name.startswith('mcp.') for name in sys.modules)"
    result = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, check=False)
    assert result.returncode == 0, result.stderr


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


def test_long_imports_are_parenthesized() -> None:
    for folder in (SOURCE, HOOKS, REPO / "tests/python", REPO / "tests/integration"):
        for path in folder.rglob("*.py"):
            source = path.read_text(encoding="utf-8-sig")
            for node in ast.walk(ast.parse(source, filename=str(path))):
                if isinstance(node, ast.Import) and len(node.names) > 3:
                    raise AssertionError(f"{path.relative_to(REPO)}:{node.lineno} import of more than three names; split it into one import per line")
                if isinstance(node, ast.ImportFrom) and len(node.names) > 3:
                    assert "(" in (ast.get_source_segment(source, node) or ""), f"{path.relative_to(REPO)}:{node.lineno}"


# Path.replace takes one argument (str.replace takes two). _installed_runtime moves whole folders aside and back; that is not a file write.
def test_no_handwritten_temp_replace() -> None:
    exempt = {"_atomic_write.py", "_installed_runtime.py"}
    for path in SOURCE.rglob("*.py"):
        if path.name in exempt:
            continue
        for node in ast.walk(ast.parse(path.read_text(encoding="utf-8-sig"), filename=str(path))):
            if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute):
                name = node.func.attr
                one_argument_replace = name == "replace" and len(node.args) == 1 and not node.keywords
                if one_argument_replace or name in ("mkstemp", "NamedTemporaryFile") or (name == "replace" and ast.unparse(node.func.value) == "os"):
                    pytest.fail(f"{path.relative_to(REPO).as_posix()}:{node.lineno}: write through core/_atomic_write.py instead of a temporary file and replace")
