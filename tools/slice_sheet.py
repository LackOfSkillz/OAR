"""tools/slice_sheet.py - cut a GPT icon sheet into the single PNGs tools/art.py wants.

GPT sometimes delivers many requested pictures on one sheet with the file name
under each tile. The cells are given below (centre x per name, a y band per
row, measured from the 2026-11-16 sheet); inside each cell the object's bright
area is found and a square around it is cut, so small misplacements don't matter.

    python tools/slice_sheet.py <sheet.png> [--only page_,class_] [--preview out.png]
    python tools/slice_sheet.py <sheet.png> --grid 5x3 name1,name2,...   (an even grid, as the
        art packages in docs/ART_PACKAGE_*.md ask GPT for)

Writes art/incoming/<name>.png (existing files are kept unless --force), then run
python tools/art.py.
"""
import os
import struct
import sys
import zlib

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import art  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INCOMING = os.path.join(ROOT, "art", "incoming")

# (y0, y1) of each row's picture band (labels below are left out), then (name, centre x)
SHEET_2026_11_16 = [
    ((205, 362), [("kind_rare", 89), ("kind_gold", 255), ("kind_gather", 400), ("kind_errand", 568),
                  ("page_help", 739), ("page_journey", 890), ("page_map", 1037), ("page_waypoints", 1180),
                  ("page_rares", 1325), ("page_rarealerts", 1465)]),
    ((415, 572), [("page_dungeons", 89), ("page_gear", 255), ("page_gearsets", 431), ("page_professions", 597),
                  ("page_crafting", 755), ("page_macros", 905), ("page_money", 1080), ("page_errands", 1265),
                  ("page_forecasts", 1440)]),
    ((612, 768), [("page_feed", 85), ("page_chat", 248), ("page_sharing", 418), ("page_settings", 600),
                  ("page_modules", 763), ("page_characters", 935), ("page_advisor", 1101), ("page_overview", 1280),
                  ("page_tools", 1452)]),
    ((816, 970), [("page_commands", 82), ("class_hunter", 243), ("class_warrior", 398), ("class_rogue", 553),
                  ("class_mage", 702), ("class_priest", 855), ("class_warlock", 1008), ("class_druid", 1160),
                  ("class_paladin", 1310), ("class_shaman", 1462)]),
]


def lum(p):
    return 0.3 * p[0] + 0.59 * p[1] + 0.11 * p[2]


def cells(w):
    """(name, x0, x1, y0, y1): each cell reaches halfway to its neighbours."""
    out = []
    for (y0, y1), items in SHEET_2026_11_16:
        for i, (name, cx) in enumerate(items):
            left = 0 if i == 0 else (items[i - 1][1] + cx) // 2
            right = w if i == len(items) - 1 else (cx + items[i + 1][1]) // 2
            out.append((name, left + 4, right - 4, y0, y1))
    return out


def object_box(rows, x0, x1, y0, y1, thr=95):
    xs, ys = [], []
    for y in range(y0, y1):
        r = rows[y]
        for x in range(x0, x1):
            p = r[x]
            mx, mn = max(p[:3]), min(p[:3])
            if lum(p) > thr or (mx - mn > 70 and mx > 90):  # bright, or strongly coloured (glows)
                xs.append(x)
                ys.append(y)
    if len(xs) < 50:
        return None
    xs.sort()
    ys.sort()
    # ignore the outermost 1% (stray sparkles)
    k = len(xs) // 100
    return xs[k], xs[-1 - k], ys[k], ys[-1 - k]


def square(rows, w, h, box, x0, x1, y0, y1, pad=0.16):
    bx0, bx1, by0, by1 = box
    side = int(max(bx1 - bx0, by1 - by0) * (1 + 2 * pad))
    side = min(side, x1 - x0, y1 - y0 + 10)
    cx, cy = (bx0 + bx1) // 2, (by0 + by1) // 2
    sx = max(x0, min(cx - side // 2, x1 - side))
    sy = max(0, min(cy - side // 2, h - side))
    return [r[sx:sx + side] for r in rows[sy:sy + side]], side


def picture_box(rows, x0, x1, y0, y1, dark=14, inset=4):
    """Grid sheets hold full-bleed square paintings on black gutters with a label
    under each: the painting is the run of rows and columns that are mostly not
    black (label rows are mostly black with a little white text)."""
    def filled(vals):
        return sum(1 for p in vals if lum(p) > dark) / float(len(vals))
    top_band = rows[y0:y0 + (y1 - y0) // 2]
    cols = [x for x in range(x0, x1) if filled([r[x] for r in top_band]) > 0.6]
    if len(cols) < 40:
        return None
    px0, px1 = cols[0], cols[-1]
    rws = [y for y in range(y0, y1) if filled(rows[y][px0:px1]) > 0.6]
    if len(rws) < 40:
        return None
    # the longest unbroken run of rows (a thin border line or a label is shorter)
    runs, start, prev = [], rws[0], rws[0]
    for y in rws[1:] + [None]:
        if y is None or y > prev + 2:
            runs.append((start, prev))
            start = y
        if y is not None:
            prev = y
    py0, py1 = max(runs, key=lambda r: r[1] - r[0])
    side = min(px1 - px0, py1 - py0) - 2 * inset
    sx, sy = px0 + inset + ((px1 - px0) - 2 * inset - side) // 2, py0 + inset
    return [r[sx:sx + side] for r in rows[sy:sy + side]], side


def write_png(path, rows):
    h, w = len(rows), len(rows[0])
    raw = bytearray()
    for r in rows:
        raw.append(0)
        for p in r:
            raw += bytes((p[0], p[1], p[2], 255))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    sheet = args[0]
    only = None
    if "--only" in args:
        only = args[args.index("--only") + 1].split(",")
    force = "--force" in args
    preview = args[args.index("--preview") + 1] if "--preview" in args else None
    w, h, rows = art.read_png(sheet)
    os.makedirs(INCOMING, exist_ok=True)
    tiles = []
    if "--grid" in args:
        # --grid COLSxROWS name1,name2,... : an even grid, read left to right,
        # top to bottom; each cell's painting is found by its edges, the label under it left out
        cols, nrows = (int(v) for v in args[args.index("--grid") + 1].lower().split("x"))
        names = args[args.index("--grid") + 2].split(",")
        cw, ch = w // cols, h // nrows
        cell_list = []
        for i, name in enumerate(names):
            cx, cy = i % cols, i // cols
            cell_list.append((name, cx * cw + 2, (cx + 1) * cw - 2, cy * ch + 2, (cy + 1) * ch - 2))
    else:
        cell_list = cells(w)
    for name, x0, x1, y0, y1 in cell_list:
        if only and not any(name.startswith(o) for o in only):
            continue
        if "--grid" in args:
            got = picture_box(rows, x0, x1, y0, y1)
            if not got:
                print("%-18s no picture found" % name)
                continue
            tile, side = got
        else:
            box = object_box(rows, x0, x1, y0, y1)
            if not box:
                print("%-18s no object found" % name)
                continue
            tile, side = square(rows, w, h, box, x0, x1, y0, y1)
        tiles.append((name, tile))
        out = os.path.join(INCOMING, name + ".png")
        if os.path.exists(out) and not force:
            print("%-18s kept (already in art/incoming)" % name)
            continue
        write_png(out, tile)
        print("%-18s %dx%d" % (name, side, side))
    if preview and tiles:
        # contact sheet: every tile scaled to 96 in rows of 9
        n, size = 9, 96
        sheet_rows = []
        for i in range(0, len(tiles), n):
            band = [[(0, 0, 0, 255)] * (n * size) for _ in range(size)]
            for j, (_, t) in enumerate(tiles[i:i + n]):
                sc = art.scale(len(t[0]), len(t), t, size, size)
                for y in range(size):
                    band[y][j * size:(j + 1) * size] = sc[y]
            sheet_rows += band
        write_png(preview, sheet_rows)
        print("preview:", preview)
    return 0


if __name__ == "__main__":
    sys.exit(main())
