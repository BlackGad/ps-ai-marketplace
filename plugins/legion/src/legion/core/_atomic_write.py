import os
import stat
import tempfile
from collections.abc import Callable
from pathlib import Path
from typing import Optional


class AtomicWriteError(OSError):
    def __init__(self, failure: OSError, *, replacing: bool, cleanup_failure: Optional[OSError]) -> None:
        super().__init__(str(failure))
        self.failure = failure
        self.replacing = replacing
        self.cleanup_failure = cleanup_failure


class FileChangedError(OSError):
    pass


# verify runs after the temporary file is staged and just before the replace; False keeps the current file.
def atomic_write_bytes(path: Path, data: bytes, *, keep_mode: bool = True, add_mode: int = 0, verify: Optional[Callable[[], bool]] = None) -> None:
    temp: Optional[Path] = None
    copied_read_only = False
    replacing = False
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile("wb", dir=path.parent, prefix=f".{path.name}.", suffix=".tmp", delete=False) as stream:
            temp = Path(stream.name)
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        if keep_mode and path.is_file():
            mode = path.stat().st_mode | add_mode
            temp.chmod(mode)
            copied_read_only = not mode & stat.S_IWRITE
        elif add_mode:
            temp.chmod(temp.stat().st_mode | add_mode)
        if verify is not None and not verify():
            raise FileChangedError(f"{path} changed while it was being written")
        replacing = True
        temp.replace(path)
    except OSError as failure:
        cleanup_failure: Optional[OSError] = None
        if temp is not None:
            try:
                # Windows refuses to unlink a temporary file with the copied read-only mode.
                if os.name == "nt" and copied_read_only:
                    temp.chmod(stat.S_IWRITE)
                temp.unlink(missing_ok=True)
            except OSError as error:
                cleanup_failure = error
        raise AtomicWriteError(failure, replacing=replacing, cleanup_failure=cleanup_failure) from failure
