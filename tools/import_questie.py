"""tools/import_questie.py -- private copy of Questie's service NPCs (decision D10).

Reads QuestieDB's Forever data (CBOR rows, base64, stored as TOC metadata in
QuestieDB_Forever.toc) and writes a load-on-demand data addon,
private/Outrider_Data_NPC/, that Outrider uses when present and ignores when not.
The output is git-ignored and stays on Gary's PC: it is NOT part of any public
release (Questie's licence only allows copying under GPLv3, see D10).

Usage:  py tools/import_questie.py [path\\to\\QuestieDB] [--deploy]
        default path: <addonsDir>\\QuestieDB from tools/local.json
        --deploy copies the result to <addonsDir>\\Outrider_Data_NPC
Every entry is marked verified = false (community data) until seen in game.
"""
import base64, json, os, re, shutil, struct, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "private", "Outrider_Data_NPC")

# Classic npcFlags (Forever uses the Classic rules table in QuestieDB).
FLAGS = [
    (4, "vendor"), (16, "trainer"), (32, "spirit_healer"), (128, "innkeeper"), (256, "bank"),
    (512, "guild_master"), (1024, "tabard"), (4096, "auction"), (8192, "stable_master"), (16384, "repair"),
]
# Flight masters come from the client itself (C_TaxiMap), so they are skipped here.
SPAWNS_BIT = 2 ** (7 - 1)
QUEST_STARTS_BIT = 2 ** (10 - 1)  # field 10: quests this NPC starts (Gary wants quest givers, 2026-11-11)
FACTION = {"A": "Alliance", "H": "Horde"}


# ---------------------------------------------------------------- CBOR (RFC 8949 subset)
class Cbor:
    def __init__(self, data):
        self.d, self.i = data, 0

    def byte(self):
        b = self.d[self.i]
        self.i += 1
        return b

    def take(self, n):
        v = self.d[self.i:self.i + n]
        self.i += n
        return v

    def length(self, info):
        if info < 24:
            return info
        size = {24: 1, 25: 2, 26: 4, 27: 8}.get(info)
        if size is None:
            if info == 31:
                return None  # indefinite
            raise ValueError("bad length info %d" % info)
        return int.from_bytes(self.take(size), "big")

    def item(self):
        b = self.byte()
        major, info = b >> 5, b & 31
        if major == 0:
            return self.length(info)
        if major == 1:
            return -1 - self.length(info)
        if major in (2, 3):
            n = self.length(info)
            if n is None:
                parts = []
                while self.d[self.i] != 0xFF:
                    parts.append(self.item())
                self.i += 1
                raw = b"".join(p if isinstance(p, bytes) else p.encode() for p in parts)
            else:
                raw = self.take(n)
            # The client's CBOR writer stores Lua strings as byte strings; read them as text.
            return raw.decode("utf-8", "replace")
        if major == 4:
            n = self.length(info)
            out = []
            if n is None:
                while self.d[self.i] != 0xFF:
                    out.append(self.item())
                self.i += 1
            else:
                out = [self.item() for _ in range(n)]
            return out
        if major == 5:
            n = self.length(info)
            out = {}
            if n is None:
                while self.d[self.i] != 0xFF:
                    k = self.item()
                    out[k] = self.item()
                self.i += 1
            else:
                for _ in range(n):
                    k = self.item()
                    out[k] = self.item()
            return out
        if major == 6:
            self.length(info)
            return self.item()  # ignore tags
        if major == 7:
            if info == 20:
                return False
            if info == 21:
                return True
            if info in (22, 23):
                return None
            if info == 25:
                h = int.from_bytes(self.take(2), "big")
                s, e, f = h >> 15, (h >> 10) & 31, h & 1023
                v = (f / 1024.0) * 2 ** -14 if e == 0 else (float("inf") if e == 31 else (1 + f / 1024.0) * 2 ** (e - 15))
                return -v if s else v
            if info == 26:
                return struct.unpack(">f", self.take(4))[0]
            if info == 27:
                return struct.unpack(">d", self.take(8))[0]
        raise ValueError("unsupported CBOR byte 0x%02x" % b)


def cbor(b64):
    return Cbor(base64.b64decode(b64)).item()


def lua_array(v):
    """CBOR arrays decode to lists; maps with int keys 1..n also mean arrays."""
    if isinstance(v, dict):
        return [v[k] for k in sorted(k for k in v if isinstance(k, int))]
    return v or []


# ---------------------------------------------------------------- input
def read_meta(toc):
    meta = {}
    with open(toc, encoding="utf-8", errors="replace") as f:
        for line in f:
            if line.startswith("## X-"):
                k, _, v = line[3:].partition(":")
                meta[k.strip()] = v.strip()
    def get(key):
        v = meta.get(key)
        m = v and re.match(r"^~(\d+)~$", v)
        if m:
            return "".join(meta[key + "-" + str(i)] for i in range(1, int(m.group(1)) + 1))
        return v
    return meta, get


def read_area_map(questiedb):
    path = os.path.join(questiedb, "support", "Forever", "Zones", "areaIdToUiMapId.lua")
    out = {}
    with open(path, encoding="utf-8") as f:
        for m in re.finditer(r"\[(\d+)\]\s*=\s*(\d+)", f.read()):
            out[int(m.group(1))] = int(m.group(2))
    return out


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ") + '"'


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    deploy = "--deploy" in sys.argv
    cfg = json.load(open(os.path.join(ROOT, "tools", "local.json"), encoding="utf-8-sig"))
    questiedb = args[0] if args else os.path.join(cfg["addonsDir"], "QuestieDB")
    if not os.path.isdir(questiedb):
        # Questie uninstalled: fall back to the saved download (private/questie-source, D10).
        import glob, tempfile, zipfile
        zips = sorted(glob.glob(os.path.join(ROOT, "private", "questie-source", "Questie-*.zip")))
        if not zips:
            sys.exit("No QuestieDB installed and no saved Questie zip in private/questie-source")
        tmp = tempfile.mkdtemp(prefix="questiedb_")
        with zipfile.ZipFile(zips[-1]) as z:
            for name in z.namelist():
                if name.startswith("QuestieDB/") and (name.endswith("QuestieDB_Forever.toc")
                                                     or "/support/Forever/Zones/" in name):
                    z.extract(name, tmp)
        questiedb = os.path.join(tmp, "QuestieDB")
        print("using saved download", os.path.basename(zips[-1]))
    toc = os.path.join(questiedb, "QuestieDB_Forever.toc")
    meta, get = read_meta(toc)
    area_map = read_area_map(questiedb)
    version = meta.get("X-BUILD-COMMIT", "?")

    ids = cbor(get("X-Npc-IDS")) if get("X-Npc-IDS") and not get("X-Npc-IDS").startswith("~") else None
    # The ID list is compressed with the client's DecompressString in game; we
    # don't need it: every NPC has an X-Npc-<id>-S row, so scan the keys.
    npc_ids = sorted({int(m.group(1)) for k in meta for m in [re.match(r"^X-Npc-(\d+)-S$", k)] if m})

    by_map, kept, skipped_area = {}, 0, 0
    for nid in npc_ids:
        row = cbor(get("X-Npc-%d-S" % nid))
        if not isinstance(row, dict):
            continue
        flags = row.get(15) or 0
        kinds = [k for bit, k in FLAGS if flags & bit]
        if (row.get("p", 0) // QUEST_STARTS_BIT) % 2:
            kinds.append("quest_giver")
        if not kinds:
            continue
        if not (row.get("p", 0) // SPAWNS_BIT) % 2:
            continue
        spawns = cbor(get("X-Npc-%d-7" % nid))
        if not isinstance(spawns, dict):
            continue
        name, title = row.get(1), row.get(14)
        faction = FACTION.get(row.get(13))
        for area, points in spawns.items():
            ui = area_map.get(area)
            if not ui:
                skipped_area += 1
                continue
            pts = lua_array(points)
            if not pts:
                continue
            p = lua_array(pts[0])
            if len(p) < 2 or p[0] is None or p[0] < 0:
                continue
            x, y = p[0] / 100.0, p[1] / 100.0
            if not (0 <= x <= 1 and 0 <= y <= 1):
                continue
            for kind in kinds:
                by_map.setdefault(ui, []).append((nid, kind, x, y, name, title, faction))
                kept += 1

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Outrider_Data_NPC.toc"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write("## Interface: 16001\n## Title: Outrider Data: NPCs (private)\n")
        f.write("## Notes: Private copy of service NPCs from QuestieDB (GPLv3, see Outrider DECISIONS D10). Not for redistribution.\n")
        f.write("## LoadOnDemand: 1\n## X-Source: QuestieDB %s\n\nData.lua\n" % version)
    with open(os.path.join(OUT, "Data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/import_questie.py from QuestieDB %s. Private copy (D10), do not redistribute.\n" % version)
        f.write("-- Source: QuestieDB (https://github.com/Questie/Questie), GPLv3 per its LICENSE.md.\n")
        f.write("-- { npcID, kind, x, y, name, title, faction } per uiMapID; x, y are map fractions. verified = false.\n")
        f.write("Outrider_DataNPC = { source = %s, maps = {\n" % lua_str("QuestieDB " + version))
        for ui in sorted(by_map):
            f.write("[%d]={\n" % ui)
            for nid, kind, x, y, name, title, faction in by_map[ui]:
                f.write("{%d,%s,%.4f,%.4f,%s,%s,%s},\n" % (nid, lua_str(kind), x, y,
                    lua_str(name) if name else "nil", lua_str(title) if title else "nil",
                    lua_str(faction) if faction else "nil"))
            f.write("},\n")
        f.write("} }\n")
    size = os.path.getsize(os.path.join(OUT, "Data.lua"))
    print("NPCs scanned %d, places kept %d on %d maps, spawns in unmapped areas skipped %d, Data.lua %d KB"
          % (len(npc_ids), kept, len(by_map), skipped_area, size // 1024))
    for ui in (2521, 1412):
        print("  map %d: %d places" % (ui, len(by_map.get(ui, []))))
    if deploy:
        target = os.path.join(cfg["addonsDir"], "Outrider_Data_NPC")
        if os.path.exists(target):
            shutil.rmtree(target)
        shutil.copytree(OUT, target)
        print("deployed to", target)


if __name__ == "__main__":
    main()
