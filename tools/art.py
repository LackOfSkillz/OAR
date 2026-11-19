"""tools/art.py - turn GPT's PNGs into textures WoW can load.

Reads art/incoming/<name>.png (names and sizes in docs/ART_REQUESTS.md), crops and
scales each to its final size (power-of-two sides), writes 32-bit TGA files with
alpha to addon/Outrider/Art/<name>.tga, and rewrites addon/Outrider/Art/Manifest.lua
so Outrider knows which pictures exist (missing ones fall back to game art).

Plain Python, no Pillow: reads 8-bit non-interlaced PNGs (grey, grey+alpha, RGB,
RGBA, palette), which is what image generators produce.

    python tools/art.py            convert everything in art/incoming
    python tools/art.py --check    list what is delivered and what is missing
"""
import os
import struct
import sys
import zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INCOMING = os.path.join(ROOT, "art", "incoming")
OUT = os.path.join(ROOT, "addon", "Outrider", "Art")

# name: (width, height). Square art is centre-cropped to a square; the header
# is cropped to a 4:1 strip a little above the middle (VY) to keep the castle.
# Batch 4 headers (2026-11-19) come with the artwork centred in a 4:1 strip, so they crop at the middle.
VY = {"header": 0.35, "header_explore": 0.5, "header_character": 0.5, "header_town": 0.5, "header_social": 0.5, "header_outrider": 0.5}
SPECS = {
    "emblem": (128, 128),
    "header": (1024, 256),
    "kind_quest": (128, 128),
    "kind_dungeon": (128, 128),
    "kind_gear": (128, 128),
    "kind_profession": (128, 128),
    "kind_rare": (128, 128),
    "kind_gold": (128, 128),
    "kind_gather": (128, 128),
    "kind_errand": (128, 128),
    "page_help": (128, 128),
    "page_journey": (128, 128),
    "page_map": (128, 128),
    "page_waypoints": (128, 128),
    "page_rares": (128, 128),
    "page_rarealerts": (128, 128),
    "page_dungeons": (128, 128),
    "page_gear": (128, 128),
    "page_gearsets": (128, 128),
    "page_professions": (128, 128),
    "page_crafting": (128, 128),
    "page_macros": (128, 128),
    "page_money": (128, 128),
    "page_errands": (128, 128),
    "page_forecasts": (128, 128),
    "page_feed": (128, 128),
    "page_chat": (128, 128),
    "page_sharing": (128, 128),
    "page_settings": (128, 128),
    "page_modules": (128, 128),
    "page_characters": (128, 128),
    "page_advisor": (128, 128),
    "page_overview": (128, 128),
    "page_tools": (128, 128),
    "page_commands": (128, 128),
    "class_hunter": (128, 128),
    "class_warrior": (128, 128),
    "class_rogue": (128, 128),
    "class_mage": (128, 128),
    "class_priest": (128, 128),
    "class_warlock": (128, 128),
    "class_druid": (128, 128),
    "class_paladin": (128, 128),
    "class_shaman": (128, 128),
    "dungeon_thehallofthanes": (128, 128),
    "dungeon_ragefirechasm": (128, 128),
    "dungeon_ruinsoflordaeron": (128, 128),
    "dungeon_wailingcaverns": (128, 128),
    "dungeon_thedeadmines": (128, 128),
    "dungeon_shadowfangkeep": (128, 128),
    "dungeon_blackfathomdeeps": (128, 128),
    "dungeon_thestockade": (128, 128),
    "dungeon_excavationsitewetlands": (128, 128),
    "dungeon_cityofdalaran": (128, 128),
    "dungeon_gnomeregan": (128, 128),
    "dungeon_razorfenkraul": (128, 128),
    "dungeon_scarletmonastery": (128, 128),
    "dungeon_razorfendowns": (128, 128),
    "dungeon_uldaman": (128, 128),
    "dungeon_zulfarrak": (128, 128),
    "dungeon_maraudon": (128, 128),
    "dungeon_thetempleofatalhakkar": (128, 128),
    "dungeon_blackrockdepths": (128, 128),
    "dungeon_diremaul": (128, 128),
    "dungeon_blackrockspire": (128, 128),
    "dungeon_scholomance": (128, 128),
    "dungeon_stratholme": (128, 128),
    "dungeon_zulgurub": (128, 128),
    "dungeon_ruinsofahnqiraj": (128, 128),
    "dungeon_onyxiaslair": (128, 128),
    "dungeon_moltencore": (128, 128),
    "dungeon_blackwinglair": (128, 128),
    "dungeon_templeofahnqiraj": (128, 128),
    "dungeon_naxxramas": (128, 128),
    # Batch 4 (premium UI, 2026-11-18): the pages still on game icons
    "page_whatnow": (128, 128),
    "page_quests": (128, 128),
    "page_fishing": (128, 128),
    "page_census": (128, 128),
    "page_people": (128, 128),
    "page_alts": (128, 128),
    "page_status": (128, 128),
    # one hero banner per sidebar group
    "header_explore": (1024, 256),
    "header_character": (1024, 256),
    "header_town": (1024, 256),
    "header_social": (1024, 256),
    "header_outrider": (1024, 256),
    # world map and minimap pin glyphs (transparent)
    "pin_vendor": (64, 64),
    "pin_repair": (64, 64),
    "pin_trainer": (64, 64),
    "pin_flight": (64, 64),
    "pin_inn": (64, 64),
    "pin_mail": (64, 64),
    "pin_bank": (64, 64),
    "pin_auction": (64, 64),
    "pin_stable": (64, 64),
    "pin_spirit": (64, 64),
    "pin_ammo": (64, 64),
    "pin_rare": (64, 64),
    "pin_questgiver": (64, 64),
    "pin_turnin": (64, 64),
    "pin_objective": (64, 64),
    "pin_herb": (64, 64),
    "pin_ore": (64, 64),
    "pin_fish": (64, 64),
    "pin_dungeon": (64, 64),
    "pin_note": (64, 64),
    "pin_cluster": (64, 64),
    # ornaments and empty states
    "ornament_divider": (512, 32),
    "ornament_corner": (64, 64),
    "empty_quiet": (256, 128),
    "empty_search": (256, 128),
    "empty_nodata": (256, 128),
}


def read_png(path):
    """Returns (width, height, rows) with rows as lists of (r, g, b, a)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG file")
    pos, idat, palette, trns = 8, [], None, None
    w = h = depth = ctype = interlace = None
    while pos < len(data):
        (length,) = struct.unpack(">I", data[pos:pos + 4])
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, interlace = struct.unpack(">IIBBBBB", body)
        elif kind == b"PLTE":
            palette = [tuple(body[i:i + 3]) for i in range(0, len(body), 3)]
        elif kind == b"tRNS":
            trns = body
        elif kind == b"IDAT":
            idat.append(body)
        elif kind == b"IEND":
            break
    if depth != 8 or interlace != 0:
        raise ValueError("only 8-bit, non-interlaced PNGs are supported (got depth %s, interlace %s)" % (depth, interlace))
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[ctype]
    raw = zlib.decompress(b"".join(idat))
    stride = w * channels
    rows, prev, p = [], bytearray(stride), 0
    for _ in range(h):
        ftype = raw[p]
        line = bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for i in range(stride):
            left = line[i - channels] if i >= channels else 0
            up = prev[i]
            ul = prev[i - channels] if i >= channels else 0
            if ftype == 1:
                line[i] = (line[i] + left) & 255
            elif ftype == 2:
                line[i] = (line[i] + up) & 255
            elif ftype == 3:
                line[i] = (line[i] + ((left + up) >> 1)) & 255
            elif ftype == 4:
                pa, pb, pc = abs(up - ul), abs(left - ul), abs(left + up - 2 * ul)
                pred = left if pa <= pb and pa <= pc else (up if pb <= pc else ul)
                line[i] = (line[i] + pred) & 255
        prev = line
        px = []
        for x in range(w):
            c = line[x * channels:(x + 1) * channels]
            if ctype == 0:
                px.append((c[0], c[0], c[0], 255))
            elif ctype == 4:
                px.append((c[0], c[0], c[0], c[1]))
            elif ctype == 2:
                px.append((c[0], c[1], c[2], 255))
            elif ctype == 6:
                px.append((c[0], c[1], c[2], c[3]))
            else:
                r, g, b = palette[c[0]]
                a = trns[c[0]] if trns and c[0] < len(trns) else 255
                px.append((r, g, b, a))
        rows.append(px)
    return w, h, rows


def crop(w, h, rows, aspect, vy=0.5):
    """Crop to width/height = aspect. vy picks the strip's vertical place
    (0 top, 0.5 centre, 1 bottom) when the picture is too tall."""
    if w / h > aspect:
        nw = int(round(h * aspect))
        x0 = (w - nw) // 2
        return nw, h, [r[x0:x0 + nw] for r in rows]
    nh = int(round(w / aspect))
    y0 = int((h - nh) * vy)
    return w, nh, rows[y0:y0 + nh]


def scale(w, h, rows, tw, th):
    """Box-filter downscale (alpha-weighted so edges don't go dark)."""
    out = []
    for ty in range(th):
        y0, y1 = ty * h // th, max(ty * h // th + 1, (ty + 1) * h // th)
        line = []
        for tx in range(tw):
            x0, x1 = tx * w // tw, max(tx * w // tw + 1, (tx + 1) * w // tw)
            sr = sg = sb = sa = n = 0
            for y in range(y0, y1):
                row = rows[y]
                for x in range(x0, x1):
                    r, g, b, a = row[x]
                    sr += r * a
                    sg += g * a
                    sb += b * a
                    sa += a
                    n += 1
            if sa:
                line.append((sr // sa, sg // sa, sb // sa, sa // n))
            else:
                line.append((0, 0, 0, 0))
        out.append(line)
    return out


def write_tga(path, w, h, rows):
    """Uncompressed 32-bit TGA, rows stored bottom-up (the classic layout)."""
    header = struct.pack("<BBBHHBHHHHBB", 0, 0, 2, 0, 0, 0, 0, 0, w, h, 32, 8)
    body = bytearray()
    for row in reversed(rows):
        for r, g, b, a in row:
            body += bytes((b, g, r, a))
    with open(path, "wb") as f:
        f.write(header + bytes(body))


def write_manifest(names):
    lines = [
        "-- Art/Manifest.lua (GENERATED by tools/art.py; do not edit)",
        "-- Which custom pictures are installed. ns.Art falls back to game art",
        "-- for anything not listed here.",
        "local _, ns = ...",
        "ns.ArtFiles = {",
    ]
    lines += ['  %s = true,' % n for n in sorted(names)]
    lines.append("}")
    with open(os.path.join(OUT, "Manifest.lua"), "w", newline="\n") as f:
        f.write("\n".join(lines) + "\n")


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(INCOMING, exist_ok=True)
    check = "--check" in sys.argv
    done = [n for n in SPECS if os.path.exists(os.path.join(OUT, n + ".tga"))]
    if check:
        for n in SPECS:
            src = os.path.exists(os.path.join(INCOMING, n + ".png"))
            print("%-16s %s" % (n, "installed" if n in done else ("waiting to convert" if src else "missing")))
        return 0
    failed = 0
    for name, (tw, th) in SPECS.items():
        src = os.path.join(INCOMING, name + ".png")
        if not os.path.exists(src):
            continue
        try:
            w, h, rows = read_png(src)
            w, h, rows = crop(w, h, rows, tw / th, VY.get(name, 0.5))
            rows = scale(w, h, rows, tw, th)
            write_tga(os.path.join(OUT, name + ".tga"), tw, th, rows)
            if name not in done:
                done.append(name)
            print("converted %s -> Art/%s.tga (%dx%d)" % (name, name, tw, th))
        except Exception as e:  # report and carry on with the others
            failed += 1
            print("FAILED %s: %s" % (name, e))
    write_manifest(done)
    missing = [n for n in SPECS if n not in done]
    print("%d installed, %d missing%s" % (len(done), len(missing), (": " + ", ".join(missing)) if missing else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
