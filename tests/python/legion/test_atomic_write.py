import os
import stat
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path
from typing import Any

import pytest

from legion.core._atomic_write import atomic_write_bytes


def test_failed_replace_preserves_the_target_and_removes_the_temp_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    target = tmp_path / "data"
    target.write_bytes(b"old")

    def deny_replace(source: Path, destination: Path) -> None:
        assert source.parent == destination.parent == tmp_path
        assert source.read_bytes() == b"new"
        raise OSError("replace denied")

    monkeypatch.setattr(Path, "replace", deny_replace)
    with pytest.raises(OSError, match="replace denied"):
        atomic_write_bytes(target, b"new")
    assert target.read_bytes() == b"old"
    assert list(tmp_path.iterdir()) == [target]


@pytest.mark.skipif(os.name != "nt", reason="Windows refuses to replace a read-only file")
def test_read_only_target_leaves_no_temp_file(tmp_path: Path) -> None:
    target = tmp_path / "data"
    target.write_bytes(b"old")
    target.chmod(stat.S_IREAD)
    try:
        with pytest.raises(OSError):
            atomic_write_bytes(target, b"new")
        assert target.read_bytes() == b"old"
        assert not target.stat().st_mode & stat.S_IWRITE
        assert list(tmp_path.iterdir()) == [target]
    finally:
        for file in tmp_path.iterdir():
            file.chmod(stat.S_IWRITE)


def test_partial_write_preserves_the_target_and_removes_the_temp_file(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    target = tmp_path / "data"
    target.write_bytes(b"old")
    open_temp = tempfile.NamedTemporaryFile

    @contextmanager
    def interrupted_open(*args: Any, **kwargs: Any) -> Iterator[object]:
        with open_temp(*args, **kwargs) as stream:
            write = stream.write

            def interrupted_write(data: bytes) -> None:
                write(data[:1])
                raise OSError("disk full")

            monkeypatch.setattr(stream, "write", interrupted_write)
            yield stream

    monkeypatch.setattr(tempfile, "NamedTemporaryFile", interrupted_open)
    with pytest.raises(OSError, match="disk full"):
        atomic_write_bytes(target, b"new")
    assert target.read_bytes() == b"old"
    assert list(tmp_path.iterdir()) == [target]
