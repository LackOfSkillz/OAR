"""tools/import_dungeons.py
Builds the private load-on-demand addon Outrider_Data_Dungeons from the saved
QuestieDB Forever download (D10, GPLv3; Gary's own use and family installs):
every dungeon and raid in QuestieDB's Forever dungeon table, its entrance, the
creatures that live inside, and the gear each one drops that drops nowhere
much else (so world-drop greens don't flood the list).

  Outrider_DataDungeons = { source, dungeons = { [areaID] = {
      name, map, x, y,                      -- entrance (uiMapID, 0..1)
      bosses = { {npcID, name, level, rank, {itemID, ...}}, ... },
      items = { [itemID] = {name, reqLevel, itemLevel, class, subclass} } } } }

Everything is verified = false until seen in game.
    py tools/import_dungeons.py [--deploy]
"""
import os, re, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_questie as q

OUT = os.path.join(q.ROOT, "private", "Outrider_Data_Dungeons")
GEAR_CLASSES = (2, 4)          # weapon, armor
INSIDE_SHARE = 0.6             # an item counts as a dungeon drop when this share of its droppers live inside


def questiedb_dir():
    import glob, tempfile, zipfile
    zips = sorted(glob.glob(os.path.join(q.ROOT, "private", "questie-source", "Questie-*.zip")))
    if not zips:
        sys.exit("No saved Questie zip in private/questie-source")
    tmp = tempfile.mkdtemp(prefix="questiedb_")
    with zipfile.ZipFile(zips[-1]) as z:
        for name in z.namelist():
            if name.startswith("QuestieDB/") and (name.endswith("QuestieDB_Forever.toc") or "/support/Forever/Zones/" in name):
                z.extract(name, tmp)
    return os.path.join(tmp, "QuestieDB")


def read_dungeons(qdb):
    path = os.path.join(qdb, "support", "Forever", "Zones", "dungeons.lua")
    text = open(path, encoding="utf-8").read()
    out = {}
    pat = re.compile(r'\[(\d+)\]\s*=\s*\{"((?:[^"\\]|\\.)*)",\s*(\{[^}]*\}|nil),\s*(\d+),\s*\{(.*?)\}\s*\}\s*,', re.S)
    for m in pat.finditer(text):
        area = int(m.group(1))
        alts = [int(x) for x in re.findall(r"\d+", m.group(3))] if m.group(3) != "nil" else []
        locs = re.findall(r"\{\s*(\d+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\}", m.group(5))
        out[area] = {"name": m.group(2), "areas": set([area] + alts), "parent": int(m.group(4)),
                     "locs": [(int(a), float(x), float(y)) for a, x, y in locs]}
    return out


def main():
    deploy = "--deploy" in sys.argv
    qdb = questiedb_dir()
    meta, get = q.read_meta(os.path.join(qdb, "QuestieDB_Forever.toc"))
    area_map = q.read_area_map(qdb)
    version = meta.get("X-BUILD-COMMIT", "?")
    dungeons = read_dungeons(qdb)

    def dec(key):
        v = get(key)
        try:
            return q.cbor(v) if v else None
        except Exception:
            return None

    # creatures by the dungeon they live in
    area_to_dungeon = {}
    for did, d in dungeons.items():
        for a in d["areas"]:
            area_to_dungeon[a] = did
    npc_ids = sorted({int(m.group(1)) for k in meta for m in [re.match(r"^X-Npc-(\d+)-S$", k)] if m})
    npc_home, npc_info = {}, {}
    for nid in npc_ids:
        spawns = dec("X-Npc-%d-7" % nid)
        if not isinstance(spawns, dict):
            continue
        homes = {area_to_dungeon[a] for a in spawns if a in area_to_dungeon}
        if len(homes) == 1:
            row = dec("X-Npc-%d-S" % nid) or {}
            npc_home[nid] = homes.pop()
            npc_info[nid] = (row.get(1) or ("NPC %d" % nid), row.get(5) or row.get(4) or 0, row.get(6) or 0)

    # gear dropped mostly inside one dungeon
    item_ids = sorted({int(m.group(1)) for k in meta for m in [re.match(r"^X-Item-(\d+)-S$", k)] if m})
    per = {did: {"bosses": {}, "items": {}} for did in dungeons}
    kept = 0
    for iid in item_ids:
        s = dec("X-Item-%d-S" % iid)
        if not isinstance(s, dict) or s.get(12) not in GEAR_CLASSES:
            continue
        drops = q.id_list(dec("X-Item-%d-2" % iid) or [])
        if not drops:
            continue
        inside = [n for n in drops if n in npc_home]
        if not inside or len(inside) / len(drops) < INSIDE_SHARE:
            continue
        for nid in inside:
            did = npc_home[nid]
            b = per[did]["bosses"].setdefault(nid, [])
            b.append(iid)
            per[did]["items"][iid] = (s.get(1) or "", s.get(10) or 0, s.get(9) or 0, s.get(12) or 0, s.get(13) or 0)
        kept += 1

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Outrider_Data_Dungeons.toc"), "w", encoding="utf-8", newline="\n") as f:
        f.write("## Interface: 16001\n## Title: Outrider Data: dungeons (private)\n")
        f.write("## Notes: Dungeons, bosses and their gear from QuestieDB (GPLv3, see Outrider DECISIONS D10).\n")
        f.write("## LoadOnDemand: 1\n## X-Source: QuestieDB %s\n\nData.lua\n" % version)
    n_d = 0
    with open(os.path.join(OUT, "Data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- Generated by tools/import_dungeons.py from QuestieDB %s. verified = false.\n" % version)
        f.write("Outrider_DataDungeons = { source = %s, dungeons = {\n" % q.lua_str("QuestieDB " + version))
        for did in sorted(dungeons):
            d, p = dungeons[did], per[did]
            if not p["bosses"]:
                continue
            loc = d["locs"][0] if d["locs"] else None
            ui = loc and area_map.get(loc[0])
            entrance = ("map = %d, x = %.4f, y = %.4f, " % (ui, loc[1] / 100, loc[2] / 100)) if ui else ""
            f.write("[%d] = { name = %s, %sbosses = {\n" % (did, q.lua_str(d["name"]), entrance))
            for nid in sorted(p["bosses"], key=lambda n: npc_info[n][1]):
                name, lvl, rank = npc_info[nid]
                f.write("  {%d,%s,%d,%d,{%s}},\n" % (nid, q.lua_str(name), lvl, rank, ",".join(str(i) for i in sorted(set(p["bosses"][nid])))))
            f.write("}, items = {\n")
            for iid in sorted(p["items"]):
                nm, req, il, cl, sub = p["items"][iid]
                f.write("  [%d] = {%s,%d,%d,%d,%d},\n" % (iid, q.lua_str(nm), req, il, cl, sub))
            f.write("} },\n")
            n_d += 1
        f.write("} }\n")
    print("dungeon pack: %d dungeons, %d gear items" % (n_d, kept))
    if deploy:
        import shutil, json
        cfg = json.load(open(os.path.join(q.ROOT, "tools", "local.json"), encoding="utf-8-sig"))
        dest = os.path.join(cfg["addonsDir"], "Outrider_Data_Dungeons")
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        shutil.copytree(OUT, dest)
        print("deployed to", dest)


if __name__ == "__main__":
    main()
