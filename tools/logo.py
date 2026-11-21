"""tools/logo.py - the CurseForge project logo from Outrider's emblem art.

CurseForge asks for a square PNG of at least 400x400 that isn't the game's logo
(Project Submission Guide, read 2026-11-21). Reads art/incoming/emblem.png (the
emblem Outrider already shows in game), scales it to SIZE, lays it on the
addon's dark panel colour so it reads on CurseForge's light and dark pages, and
writes docs/curseforge/logo.png. Plain Python, no Pillow (reuses tools/art.py).

    python tools/logo.py
"""
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "art", "incoming", "emblem.png")
OUT = os.path.join(ROOT, "docs", "curseforge", "logo.png")
SIZE = 400
BACK = (20, 22, 28)  # the dark panel colour behind the emblem


def write_png(path, w, h, rows):
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for r, g, b in row:
            raw += bytes((r, g, b))

    def chunk(kind, body):
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def main():
    w, h, rows = art.read_png(SRC)
    w, h, rows = art.crop(w, h, rows, 1.0)
    rows = art.scale(w, h, rows, SIZE, SIZE)
    flat = []
    for row in rows:
        line = []
        for r, g, b, a in row:
            line.append(tuple((c * a + k * (255 - a)) // 255 for c, k in zip((r, g, b), BACK)))
        flat.append(line)
    write_png(OUT, SIZE, SIZE, flat)
    print("wrote", OUT)


if __name__ == "__main__":
    main()
