# Child interpreters cannot inherit pytest mocks. Deny before DNS or connect and record even a swallowed error.
import os
import socket
from contextvars import ContextVar
from collections.abc import Buffer
from pathlib import Path
from typing import Any, NoReturn

_in_socketpair: ContextVar[bool] = ContextVar("in_socketpair", default=False)
_socketpair = socket.socketpair


# Windows asyncio uses Python's loopback socketpair implementation for its internal wakeup pipe.
# Only that stdlib operation may connect locally; ordinary loopback calls remain denied.
def socketpair(*args: Any, **kwargs: Any) -> tuple[socket.socket, socket.socket]:
    token = _in_socketpair.set(True)
    try:
        return _socketpair(*args, **kwargs)
    finally:
        _in_socketpair.reset(token)


def deny(*_args: object, **_kwargs: object) -> NoReturn:
    with Path(os.environ["PYTHON_TEST_SOCKET_RECORD"]).open("a", encoding="utf-8") as record:
        record.write("socket connection attempted\n")
    raise OSError("test socket fence denied a connection")


class Socket(socket.socket):
    def connect(self, address: tuple[object, ...] | str | Buffer) -> None:
        internal = _in_socketpair.get() and isinstance(address, tuple) and address[0] in ("127.0.0.1", "::1")
        if self.family in (socket.AF_INET, socket.AF_INET6) and not internal:
            deny(address)
        super().connect(address)

    def connect_ex(self, address: tuple[object, ...] | str | Buffer) -> int:
        if self.family in (socket.AF_INET, socket.AF_INET6):
            deny(address)
        return super().connect_ex(address)


socket.socket = Socket
socket.socketpair = socketpair
socket.getaddrinfo = deny
