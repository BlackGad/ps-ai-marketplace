import codecs
from dataclasses import dataclass


_MARKS = (
    (codecs.BOM_UTF32_LE, "utf-32-le"),
    (codecs.BOM_UTF32_BE, "utf-32-be"),
    (codecs.BOM_UTF8, "utf-8"),
    (codecs.BOM_UTF16_LE, "utf-16-le"),
    (codecs.BOM_UTF16_BE, "utf-16-be"),
)


@dataclass(frozen=True)
class TextFormat:
    encoding: str
    bom: bytes
    newline: str


def decode_text(data: bytes) -> tuple[str, TextFormat]:
    # The UTF-32LE mark starts with the UTF-16LE mark.
    for mark in _MARKS:
        if data.startswith(mark[0]):
            bom, encoding = mark
            break
    else:
        bom, encoding = b"", "utf-8"
    text = data[len(bom) :].decode(encoding)
    return text, TextFormat(encoding, bom, "\r\n" if "\r\n" in text else "\n")


def encode_text(text: str, format: TextFormat, *, normalize_newlines: bool = False) -> bytes:
    if normalize_newlines:
        text = text.replace("\r\n", "\n").replace("\n", format.newline)
    return format.bom + text.encode(format.encoding)
