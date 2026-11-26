# The one HTTPS client: certificates from the operating system store, redirects followed only over https.

import ssl
from pathlib import Path
from typing import Optional

import httpx
import truststore


class HttpsError(Exception):
    pass


# Plain words for a failed transfer, or None when the error is not one of this helper's.
def failure_text(error: Exception) -> Optional[str]:
    if isinstance(error, HttpsError):
        return str(error)
    if isinstance(error, httpx.HTTPStatusError):
        return f"HTTP {error.response.status_code}"
    if isinstance(error, httpx.HTTPError):
        return str(error) or type(error).__name__
    return None


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
