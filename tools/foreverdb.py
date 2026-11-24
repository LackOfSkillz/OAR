"""tools/foreverdb.py -- read the ForeverDB release (GPLv3 merged WoW Forever data).

ForeverDB (https://github.com/foreverfraddons/forever-db) merges the WoW Forever
client tables, AllTheThings, QuestieDB (Forever), VMaNGOS, cMaNGOS classic-db,
pfQuest, Drop Tables (CC BY-SA 4.0) and in-game recordings; see its
LICENSE-DATA.txt, saved next to the download in private/foreverdb-source.

    py tools/foreverdb.py --fetch    download the newest release (gh CLI)

Other importers call load() and the helpers below. Everything stays
verified = false until seen in game.
"""
import gzip, json, os, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "private", "foreverdb-source")
FILE = os.path.join(SRC, "forever.json.gz")
REPO = "foreverfraddons/forever-db"
GEAR_CLASSES = (2, 4)
RARE_RANKS = (2, 4)

_cache = None


def fetch():
    os.makedirs(SRC, exist_ok=True)
    subprocess.check_call(["gh", "release", "download", "latest", "-R", REPO, "-p", "forever.json.gz",
                           "-p", "report.md", "--clobber", "-D", SRC])
    lic = subprocess.check_output(["gh", "api", "repos/%s/contents/LICENSE-DATA.txt" % REPO, "--jq", ".content"])
    import base64
    open(os.path.join(SRC, "LICENSE-DATA.txt"), "wb").write(base64.b64decode(lic))


def load():
    global _cache
    if _cache is None:
        if not os.path.exists(FILE):
            return None
        _cache = json.load(gzip.open(FILE, "rt", encoding="utf-8"))
    return _cache


def version(d):
    m = d.get("meta", {})
    return "ForeverDB %s (%s)" % (m.get("build", "?"), m.get("hash", "?"))


_maps = None


def world_to_map(d, cont, wx, wy):
    """World position on a continent -> (uiMap, x, y), with the client's map bounds."""
    global _maps
    if _maps is None:
        import import_travel
        _maps = import_travel.Maps(d)
    return _maps.to_map(cont, wx, wy)


def place(d, key):
    """First Forever map spot of 'c123' (creature) or 'o45' (object): (uiMap, x, y) 0..1, or None.
    Hand-fixed spots (spm) first, then every map spot (spz), then a world spot (spw) turned into a map spot."""
    for table in ("spm", "spz"):
        for ui, pts in (d[table].get(key) or {}).items():
            if pts and len(pts) >= 2:
                return int(ui), pts[0] / 1000.0, pts[1] / 1000.0
    for w in d["spw"].get(key) or []:
        if len(w) >= 3:
            p = world_to_map(d, w[0], w[1], w[2])
            if p:
                return p
    return None


_inst = None


def entrance(d, key):
    """For a creature that lives inside a dungeon: (dungeon name, uiMap, x, y) of its entrance, or None."""
    global _inst
    if _inst is None:
        _inst = {}
        for area, row in d["dng"].items():
            a = d["area"].get(area)
            if a and row[2]:
                _inst.setdefault(a[1], (row[0], row[2][0], row[2][1] / 1000.0, row[2][2] / 1000.0))
    for w in d["spw"].get(key) or []:
        if w and w[0] in _inst:
            return _inst[w[0]]
    return None


def faction(d, nid):
    f = d["nfac"].get(str(nid))
    return {"A": "Alliance", "H": "Horde"}.get(f)


def npc(d, nid):
    """(name, minLevel, maxLevel, rank) or None."""
    r = d["npc"].get(str(nid))
    return (r[0], r[2], r[3], r[4] or 0) if r else None


def item(d, iid):
    """(name, quality, reqLevel, itemLevel, class, subclass) or None."""
    r = d["item"].get(str(iid))
    if not r:
        return None
    r = list(r) + [None] * (6 - len(r))
    return (r[0], r[1], r[2] or 0, r[3] or 0, r[4], r[5])


def pct(chance):
    """chance per 10000 -> '2.4%' ('' when unknown)."""
    if not chance:
        return ""
    v = chance / 100.0
    return ("%.0f%%" if v >= 10 else "%.1f%%" if v >= 1 else "%.2f%%") % v


if __name__ == "__main__":
    if "--fetch" in sys.argv:
        fetch()
    d = load()
    print(version(d) if d else "no ForeverDB download; run with --fetch")
