# Child interpreters cannot inherit pytest mocks. Deny before DNS or connect and record even a swallowed error.
import os
import socket
from collections.abc import Buffer
from pathlib import Path
from typing import NoReturn


def deny(*_args: object, **_kwargs: object) -> NoReturn:
    with Path(os.environ["PYTHON_TEST_SOCKET_RECORD"]).open("a", encoding="utf-8") as record:
        record.write("socket connection attempted\n")
    raise OSError("test socket fence denied a connection")


class Socket(socket.socket):
    def connect(self, address: tuple[object, ...] | str | Buffer) -> None:
        if self.family in (socket.AF_INET, socket.AF_INET6):
            deny(address)
        super().connect(address)

    def connect_ex(self, address: tuple[object, ...] | str | Buffer) -> int:
        if self.family in (socket.AF_INET, socket.AF_INET6):
            deny(address)
        return super().connect_ex(address)


socket.socket = Socket
socket.getaddrinfo = deny
