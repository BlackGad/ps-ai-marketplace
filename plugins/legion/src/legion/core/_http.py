# The one HTTPS client: certificates from the operating system store, redirects followed only over https.

import ssl
from pathlib import Path
from typing import Optional

import httpx
import truststore


class HttpsError(Exception):
    pass


# Runs before every request, including each redirect hop, so a hop to plain http never connects.
def _require_https(request: httpx.Request) -> None:
    if request.url.scheme != "https":
        raise HttpsError(f"refusing a URL that is not https: {request.url}")


def https_client(timeout: float, transport: Optional[httpx.BaseTransport] = None) -> httpx.Client:
    return httpx.Client(
        verify=truststore.SSLContext(ssl.PROTOCOL_TLS_CLIENT),
        follow_redirects=True,
        timeout=timeout,
        transport=transport,
        event_hooks={"request": [_require_https]},
    )


def get_bytes(url: str, timeout: float) -> bytes:
    with https_client(timeout) as client:
        response = client.get(url)
        response.raise_for_status()
        return response.content


def download(url: str, path: Path, timeout: float) -> None:
    with https_client(timeout) as client, client.stream("GET", url) as response:
        response.raise_for_status()
        with path.open("wb") as file:
            for block in response.iter_bytes():
                file.write(block)
