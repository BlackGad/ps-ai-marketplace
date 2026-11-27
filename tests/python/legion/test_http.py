import socket
from pathlib import Path

import httpx
import pytest

from legion.core import _http
from legion.core._http import HttpsError, https_client


def moved(location: str) -> httpx.Response:
    return httpx.Response(302, headers={"location": location})


def test_a_redirect_that_stays_on_https_is_followed() -> None:
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.host == "vendor.test":
            return moved("https://cdn.test/install.ps1")
        return httpx.Response(200, text="script")

    with https_client(5, httpx.MockTransport(handler)) as client:
        response = client.get("https://vendor.test/install.ps1")
    assert (response.text, str(response.url)) == ("script", "https://cdn.test/install.ps1")


def test_a_redirect_to_plain_http_is_refused_before_connecting() -> None:
    requested: list[str] = []

    def handler(request: httpx.Request) -> httpx.Response:
        requested.append(str(request.url))
        return moved("http://cdn.test/install.ps1")

    with https_client(5, httpx.MockTransport(handler)) as client, pytest.raises(HttpsError, match="not https"):
        client.get("https://vendor.test/install.ps1")
    assert requested == ["https://vendor.test/install.ps1"]


def test_a_plain_http_start_url_is_refused() -> None:
    with https_client(5, httpx.MockTransport(lambda _request: httpx.Response(200))) as client, pytest.raises(HttpsError, match="not https"):
        client.get("http://vendor.test/file")


def test_download_streams_the_body_to_the_file(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    transport = httpx.MockTransport(lambda _request: httpx.Response(200, content=b"zip bytes"))
    monkeypatch.setattr(_http, "https_client", lambda timeout: https_client(timeout, transport))
    target = tmp_path / "file.zip"
    _http.download("https://vendor.test/file.zip", target, 5)
    assert target.read_bytes() == b"zip bytes"


def test_a_failed_status_raises_for_text_and_downloads(monkeypatch: pytest.MonkeyPatch, tmp_path: Path) -> None:
    transport = httpx.MockTransport(lambda _request: httpx.Response(404))
    monkeypatch.setattr(_http, "https_client", lambda timeout: https_client(timeout, transport))
    with pytest.raises(httpx.HTTPStatusError):
        _http.get_bytes("https://vendor.test/missing", 5)
    with pytest.raises(httpx.HTTPStatusError):
        _http.download("https://vendor.test/missing", tmp_path / "file", 5)


def test_the_socket_fence_blocks_address_resolution() -> None:
    with pytest.raises(OSError, match="test socket fence denied a connection"):
        socket.getaddrinfo("127.0.0.1", 443, flags=socket.AI_NUMERICHOST)


def test_the_socket_fence_blocks_direct_connections() -> None:
    # An out-of-range port also prevents a connection if the fence is missing.
    with socket.socket() as sock:
        with pytest.raises(OSError, match="test socket fence denied a connection"):
            sock.connect(("127.0.0.1", 65536))
        with pytest.raises(OSError, match="test socket fence denied a connection"):
            sock.connect_ex(("127.0.0.1", 65536))
