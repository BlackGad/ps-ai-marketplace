import json
import re
import struct

from conftest import REPO

SKILL = REPO / "plugins/legion/skills/legion-telegram"


def test_bundled_connection_test_image_is_a_96_by_96_png() -> None:
    image = (SKILL / "assets/test.png").read_bytes()
    assert image[:8] == b"\x89PNG\r\n\x1a\n"
    assert struct.unpack_from(">II", image, 16) == (96, 96)


def test_send_examples_keep_distinct_targets_and_explicit_formats() -> None:
    send = (SKILL / "references/send.md").read_text(encoding="utf-8")
    payloads = [json.loads(payload) for payload in re.findall(r"(?s)```json\s*(.*?)\s*```", send)]
    assert [str(payload["chat_id"]) for payload in payloads] == ["123", "456"]
    assert [payload["format"] for payload in payloads] == ["markdownv2", "text"]
    assert payloads[0]["text"] == r"Connection test\."
    usage = re.search(r"(?m)^legion telegram send .+$", send)
    assert usage
    required = re.sub(r"\[[^\]]*\]", "", usage[0])
    assert re.search(r"(?:^|\s)--format\s", required)
    assert "[formats.md](formats.md)" in send
    formats = (SKILL / "references/formats.md").read_text(encoding="utf-8").lower()
    assert "default each independently" in formats
    assert "format the notes name stays" in formats
