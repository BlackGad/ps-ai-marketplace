from pathlib import Path

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
