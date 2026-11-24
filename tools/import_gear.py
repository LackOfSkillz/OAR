"""tools/import_gear.py -- private gear sources pack from QuestieDB (P6-05, D10/D13).

Reads QuestieDB's Forever item and quest rows (same CBOR-in-TOC format as
tools/import_questie.py) and writes the load-on-demand data addon
private/Outrider_Data_Gear/: every weapon or armor item up to required level
60 with where it comes from:
  quest  - quests that reward it (quest level, faction from the race mask,
           position of the quest giver)
  vendor - NPCs that sell it (position)
  drop   - NPCs that drop it, only when 5 or fewer do (named drops)
  rare   - rare creatures that drop it, even when many others do too
  dungeon - dungeon and raid bosses (the entrance is the waypoint; the boss
           name says where inside), when most droppers live in one instance
  chest  - objects (chests, crates) that hold it, when 5 or fewer do
Item stats are NOT copied: Outrider scores items in game with
C_Item.GetItemStats. Everything is verified = false (community data).
Private like the NPC pack: GPLv3 Questie data, git-ignored, not for release.

Usage:  py tools/import_gear.py [path\\to\\QuestieDB] [--deploy]
"""
import json, os, re, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_questie as q  # noqa: E402
import import_dungeons as dg  # noqa: E402
import import_reagents as rg  # noqa: E402
import foreverdb as fdb  # noqa: E402

ROOT = q.ROOT
OUT = os.path.join(ROOT, "private", "Outrider_Data_Gear")
HORDE, ALLIANCE = 2 | 16 | 32 | 128, 1 | 4 | 8 | 64
MAX_DROPPERS = 5      # named drops: kept when this few creatures drop it
KEEP_DROPPERS = 3     # how many of them are listed
MAX_OBJECTS = 5
RARE_RANKS = (2, 4)   # rare elite, rare


def faction_of(mask):
    if not mask:
        return None
    h, a = mask & HORDE, mask & ALLIANCE
    if h and not a:
        return "Horde"
    if a and not h:
        return "Alliance"
    return None


def questiedb_dir(cfg, args):
    path = args[0] if args else os.path.join(cfg["addonsDir"], "QuestieDB")
    if os.path.isdir(path):
        return path
    import glob, tempfile, zipfile
    zips = sorted(glob.glob(os.path.join(ROOT, "private", "questie-source", "Questie-*.zip")))
    if not zips:
        sys.exit("No QuestieDB installed and no saved Questie zip in private/questie-source")
    tmp = tempfile.mkdtemp(prefix="questiedb_")
    with zipfile.ZipFile(zips[-1]) as z:
        for name in z.namelist():
            if name.startswith("QuestieDB/") and (name.endswith("QuestieDB_Forever.toc") or "/support/Forever/Zones/" in name):
                z.extract(name, tmp)
    print("using saved download", os.path.basename(zips[-1]))
    return os.path.join(tmp, "QuestieDB")


GEAR_CLASSES, RARE_RANKS = fdb.GEAR_CLASSES, fdb.RARE_RANKS
FDB_KEEP = 3          # named sources kept per kind from ForeverDB
FDB_WORLD_BELOW = 100 # a world drop whose best named dropper is under 1% (per 10000) shows as "world drop"


def augment_foreverdb(out, counts):
    """Forever's own item names and levels, and what QuestieDB lacks: drop
    chances, world drops, Forever vendors and quest rewards, chests and
    containers (ForeverDB, GPLv3). Returns the source label or None."""
    d = fdb.load()
    if not d:
        print("no ForeverDB download (py tools/foreverdb.py --fetch): QuestieDB only")
        return None
    added = {}

    def note(k):
        added[k] = added.get(k, 0) + 1

    for key, row in d["item"].items():
        iid = int(key)
        info = fdb.item(d, iid)
        name, quality, req, ilvl, cls, sub = info
        if cls not in GEAR_CLASSES or quality is None or quality < 1 or req > 60 or (req <= 1 and ilvl > 70):
            continue
        old = out.get(iid)
        srcs = list(old[3]) if old else []
        whos = {(x[0], str(x[4]).split(" (")[0]) for x in srcs}

        def add(src):
            k = (src[0], str(src[4]).split(" (")[0])
            if k in whos:
                # same source: put the drop chance on the one we have
                for i, x in enumerate(srcs):
                    if (x[0], str(x[4]).split(" (")[0]) == k and "%" not in str(x[4]) and "%" in str(src[4]):
                        srcs[i] = x[:4] + (src[4],) + x[5:]
                return
            whos.add(k)
            srcs.append(src)
            note(src[0])

        drops = sorted(d["drop"].get(key) or [], key=lambda r: -(r[1] or 0))
        named = [r for r in drops if (r[1] or 0) >= FDB_WORLD_BELOW] if key in d["world"] else drops[:6]
        kept = 0
        for nid, chance in named:
            if kept >= FDB_KEEP:
                break
            n = fdb.npc(d, nid)
            at = fdb.place(d, "c%d" % nid)
            if n and at:
                kind = "rare" if n[3] in RARE_RANKS else "drop"
                who = n[0] + (" (%s)" % fdb.pct(chance) if chance else "")
                add((kind, at[0], at[1], at[2], who, None, fdb.faction(d, nid), None))
                kept += 1
        if key in d["world"] and kept == 0:
            add(("world", 0, 0.0, 0.0, "creatures level %d and up" % d["world"][key], None, None, None))
        for oid, chance in (d["odrop"].get(key) or [])[:FDB_KEEP]:
            o = d["obj"].get(str(oid))
            at = fdb.place(d, "o%d" % oid)
            if o and at and o[0]:
                add(("chest", at[0], at[1], at[2], o[0] + (" (%s)" % fdb.pct(chance) if chance else ""), None, None, None))
        # containers: only a real chance from a few (lockboxes and grab bags hold hundreds of items)
        boxes = d["idrop"].get(key) or []
        for cid, chance in (boxes if len(boxes) <= 2 else [])[:2]:
            c = fdb.item(d, cid)
            if c and (chance or 0) >= 500:
                add(("container", 0, 0.0, 0.0, c[0] + (" (%s)" % fdb.pct(chance) if chance else ""), None, None, None))
        vk = 0
        for nid in d["vend"].get(key) or []:
            if vk >= FDB_KEEP:
                break
            n = fdb.npc(d, nid)
            at = fdb.place(d, "c%d" % nid)
            if n and at:
                add(("vendor", at[0], at[1], at[2], n[0], None, fdb.faction(d, nid), None))
                vk += 1
        for qid in (d["rew"].get(key) or [])[:FDB_KEEP]:
            qt = d["quest"].get(str(qid))
            givers = d["qg"].get(str(qid)) or []
            at, gname, gfac = None, None, None
            for g in givers:
                at = fdb.place(d, g)
                if at:
                    if g.startswith("c"):
                        n = fdb.npc(d, int(g[1:]))
                        gname, gfac = (n[0] if n else None), fdb.faction(d, int(g[1:]))
                    else:
                        o = d["obj"].get(g[1:])
                        gname = o[0] if o else None
                    break
            if qt and at and not any(x[0] == "quest" and x[7] and x[7][0] == qid for x in srcs):
                srcs.append(("quest", at[0], at[1], at[2], qt[0], qt[1] or None, gfac, (qid, qt[2] or 1, [], [])))
                note("quest")
        if srcs:
            out[iid] = (name, req, ilvl, srcs)
    print("ForeverDB added:", ", ".join("%s %d" % kv for kv in sorted(added.items())))
    return fdb.version(d)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    cfg = json.load(open(os.path.join(ROOT, "tools", "local.json"), encoding="utf-8-sig"))
    qdb = questiedb_dir(cfg, args)
    meta, get = q.read_meta(os.path.join(qdb, "QuestieDB_Forever.toc"))
    area_map = q.read_area_map(qdb)
    version = meta.get("X-BUILD-COMMIT", "?")

    def row(kind, i, field="S"):
        v = get("X-%s-%d-%s" % (kind, i, field))
        return q.cbor(v) if v else None

    npc_cache = {}

    def npc_place(nid):
        if nid in npc_cache:
            return npc_cache[nid]
        place = None
        s = row("Npc", nid)
        spawns = row("Npc", nid, "7")
        if isinstance(s, dict) and isinstance(spawns, dict):
            for area, points in spawns.items():
                ui = area_map.get(area)
                pts = q.lua_array(points)
                if not ui or not pts:
                    continue
                p = q.lua_array(pts[0])
                if len(p) >= 2 and p[0] is not None and p[0] >= 0:
                    x, y = p[0] / 100.0, p[1] / 100.0
                    if 0 <= x <= 1 and 0 <= y <= 1:
                        place = (ui, x, y, s.get(1), q.FACTION.get(s.get(13)))
                        break
        npc_cache[nid] = place
        return place

    # creatures by the dungeon they live in (same rule as import_dungeons.py)
    dungeons = dg.read_dungeons(qdb)
    area_to_dungeon = {a: did for did, d in dungeons.items() for a in d["areas"]}
    entrance = {}
    for did, d in dungeons.items():
        loc = d["locs"][0] if d["locs"] else None
        ui = loc and area_map.get(loc[0])
        if ui:
            entrance[did] = (ui, loc[1] / 100.0, loc[2] / 100.0)
    home_cache = {}

    def npc_home(nid):
        if nid not in home_cache:
            spawns = row("Npc", nid, "7")
            homes = {area_to_dungeon[a] for a in spawns if a in area_to_dungeon} if isinstance(spawns, dict) else set()
            home_cache[nid] = homes.pop() if len(homes) == 1 else None
        return home_cache[nid]

    def npc_rank(nid):
        s = row("Npc", nid)
        return (s.get(6) or 0) if isinstance(s, dict) else 0

    obj_cache = {}

    def object_place(oid):
        if oid not in obj_cache:
            s = row("Object", oid)
            sp = rg.spawns_of(get("X-Object-%d-4" % oid), area_map) if isinstance(s, dict) else {}
            place = None
            for ui, pts in sp.items():
                if pts:
                    place = (ui, pts[0][0], pts[0][1], s.get(1))
                    break
            obj_cache[oid] = place
        return obj_cache[oid]

    counts = {}
    item_ids = sorted({int(m.group(1)) for k in meta for m in [re.match(r"^X-Item-(\d+)-S$", k)] if m})
    out, sources = {}, 0
    for iid in item_ids:
        s = row("Item", iid)
        if not isinstance(s, dict) or s.get(12) not in (2, 4):
            continue
        req = s.get(10) or 0
        if req > 60:
            continue
        srcs = []
        for qid in q.lua_array(row("Item", iid, "6")):
            qs = row("Quest", qid)
            if not isinstance(qs, dict):
                continue
            starters = q.lua_array(row("Quest", qid, "2"))
            npcs = q.lua_array(starters[0]) if starters else []
            place = npc_place(npcs[0]) if npcs else None
            if place:
                pa = get("X-Quest-%d-13" % qid)  # preQuestSingle: any one done
                pl = get("X-Quest-%d-12" % qid)  # preQuestGroup: all done
                req = qs.get(4) or 1
                srcs.append(("quest", place[0], place[1], place[2], qs.get(1), qs.get(5) or req, faction_of(qs.get(6)),
                             (qid, req, q.id_list(q.cbor(pa)) if pa else [], q.id_list(q.cbor(pl)) if pl else [])))
        for nid in q.lua_array(row("Item", iid, "14"))[:4]:
            place = npc_place(nid)
            if place:
                srcs.append(("vendor", place[0], place[1], place[2], place[3], None, place[4], None))
        droppers = [n for n in q.lua_array(row("Item", iid, "2")) if isinstance(n, int)]
        inside = [n for n in droppers if npc_home(n)]
        if inside and len(inside) / len(droppers) >= dg.INSIDE_SHARE:
            for nid in inside[:KEEP_DROPPERS]:
                did = npc_home(nid)
                ent = entrance.get(did)
                ns_ = row("Npc", nid)
                if ent and isinstance(ns_, dict):
                    who = "%s (%s)" % (ns_.get(1), dungeons[did]["name"])
                    srcs.append(("dungeon", ent[0], ent[1], ent[2], who, None, None, None))
        elif droppers:
            listed = set()
            if len(droppers) <= MAX_DROPPERS:
                for nid in droppers:
                    if len(listed) >= KEEP_DROPPERS:
                        break
                    place = npc_place(nid)
                    if place:
                        listed.add(nid)
                        kind = "rare" if npc_rank(nid) in RARE_RANKS else "drop"
                        srcs.append((kind, place[0], place[1], place[2], place[3], None, place[4], None))
            rares = 0
            for nid in droppers:
                if rares >= 2:
                    break
                if nid not in listed and npc_rank(nid) in RARE_RANKS:
                    place = npc_place(nid)
                    if place:
                        rares += 1
                        srcs.append(("rare", place[0], place[1], place[2], place[3], None, place[4], None))
        objects = [o for o in q.lua_array(row("Item", iid, "3")) if isinstance(o, int)]
        if 0 < len(objects) <= MAX_OBJECTS:
            for oid in objects[:2]:
                place = object_place(oid)
                if place and place[3]:
                    srcs.append(("chest", place[0], place[1], place[2], place[3], None, None, None))
        for k in {x[0] for x in srcs}:
            counts[k] = counts.get(k, 0) + 1
        if srcs:
            out[iid] = (s.get(1), req, s.get(9), srcs)
            sources += len(srcs)

    fsrc = augment_foreverdb(out, counts)
    if fsrc:
        version = version + " + " + fsrc
        sources = sum(len(v[3]) for v in out.values())

    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Outrider_Data_Gear.toc"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write("## Interface: 16001\n## Title: Outrider Data: Gear sources (private)\n")
        f.write("## Notes: Private copy of item sources from QuestieDB (GPLv3, see Outrider DECISIONS D10/D13). Not for redistribution.\n")
        f.write("## LoadOnDemand: 1\n## X-Source: QuestieDB %s\n\nData.lua\n" % version)
    with open(os.path.join(OUT, "Data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/import_gear.py from QuestieDB %s. Private copy (D10/D13), do not redistribute.\n" % version)
        f.write("-- Source: QuestieDB (https://github.com/Questie/Questie), GPLv3 per its LICENSE.md.\n")
        f.write("-- [itemID] = { name, reqLevel, itemLevel, { {kind, mapID, x, y, who, questLevel, faction"
                "[, questID, questReqLevel, {preAny}, {preAll}]}, ... } }. verified = false.\n")
        f.write("Outrider_DataGear = { source = %s, items = {\n" % q.lua_str("QuestieDB " + version))
        for iid in sorted(out):
            name, req, ilvl, srcs = out[iid]
            parts = []
            for kind, ui, x, y, who, qlvl, fac, quest in srcs:
                qtext = ""
                if quest:  # questID, requiredLevel, {preAny}, {preAll}
                    qid, qreq, pa, pl = quest
                    qtext = ",%d,%d,{%s},{%s}" % (qid, qreq, ",".join(str(i) for i in pa), ",".join(str(i) for i in pl))
                parts.append("{%s,%d,%.4f,%.4f,%s,%s,%s%s}" % (q.lua_str(kind), ui, x, y,
                    q.lua_str(who) if who else "nil", str(qlvl) if qlvl else "nil", q.lua_str(fac) if fac else "nil", qtext))
            f.write("[%d]={%s,%d,%s,{%s}},\n" % (iid, q.lua_str(name or "?"), req, str(ilvl or 0), ",".join(parts)))
        f.write("} }\n")
    size = os.path.getsize(os.path.join(OUT, "Data.lua"))
    print("gear items with sources %d, sources %d, Data.lua %d KB" % (len(out), sources, size // 1024))
    per = {}
    for v in out.values():
        for k in {x[0] for x in v[3]}:
            per[k] = per.get(k, 0) + 1
    print("items per source kind:", ", ".join("%s %d" % kv for kv in sorted(per.items())))
    if "--deploy" in sys.argv:
        target = os.path.join(cfg["addonsDir"], "Outrider_Data_Gear")
        if os.path.exists(target):
            shutil.rmtree(target)
        shutil.copytree(OUT, target)
        print("deployed to", target)


if __name__ == "__main__":
    main()
