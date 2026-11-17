"""tools/import_questie_quests.py -- private quest objectives pack (decision D10).

Gary, 2026-11-17: "build all of those quests into outrider using the Questie
database". Reads QuestieDB's Forever data (the same TOC metadata as
tools/import_questie.py) and writes a load-on-demand data addon,
private/Outrider_Data_Quests/, with, for every quest: its objectives (mobs to
kill, objects to use, items to collect, places to explore) and where each one
is: mob and object spawns, and for items the mobs and objects that drop them.
Git-ignored and private like Outrider_Data_NPC (Questie is GPLv3, D10).

Usage:  python tools/import_questie_quests.py [path\\to\\QuestieDB] [--deploy]
        default: the installed QuestieDB, else the saved Questie zip in private/questie-source
        --deploy copies the result to <addonsDir>\\Outrider_Data_Quests

QuestieDB fields used (from its db layout):
  Quest  S:{1 name, 4 requiredLevel, 5 questLevel}  10 objectives {1 creatures
         [[id,text]], 2 objects [[id,text]], 3 items [[id,text]], 5 kill credit
         [[[ids], rootId, text]]}  9 triggerEnd {text, {area: [[x,y]]}}
  Npc    S:{1 name}  7 spawns {area: [[x,y]]}
  Object S:{1 name}  4 spawns {area: [[x,y]]}
  Item   S:{1 name}  2 npcDrops [ids]  3 objectDrops [ids]
  Quest  3 finishedBy [[npc ids], [object ids]]   (the turn-in, for "?" markers)
  Object 2 questStarts [quest ids]  (wanted posters and other objects that give quests)
Every point is marked unverified community data in game.
"""
import json
import os
import re
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_questie as Q  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "private", "Outrider_Data_Quests")
MAX_POINTS = 30      # spawn points kept per mob or object per map
MAX_MAPS = 3         # maps kept per mob or object
MAX_DROPPERS = 25    # mobs or objects kept per item


def find_questiedb(arg):
    cfg = json.load(open(os.path.join(ROOT, "tools", "local.json"), encoding="utf-8-sig"))
    path = arg or os.path.join(cfg["addonsDir"], "QuestieDB")
    if os.path.isdir(path):
        return path, cfg
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
    return os.path.join(tmp, "QuestieDB"), cfg


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    questiedb, cfg = find_questiedb(args[0] if args else None)
    meta, get = Q.read_meta(os.path.join(questiedb, "QuestieDB_Forever.toc"))
    area_map = Q.read_area_map(questiedb)
    version = meta.get("X-BUILD-COMMIT", "?")

    def row(kind, i, field):
        v = get("X-%s-%d-%s" % (kind, i, field))
        if v is None or v.startswith("~"):
            return None
        try:
            return Q.cbor(v)
        except Exception:
            return None

    def name(kind, i):
        s = row(kind, i, "S")
        return s.get(1) if isinstance(s, dict) else None

    def spawns(kind, i, field):
        """{uiMapID: [x, y, x, y, ...]} as map fractions"""
        sp = row(kind, i, field)
        out = {}
        if not isinstance(sp, dict):
            return out
        for area, pts in sp.items():
            ui = area_map.get(area)
            if not ui or len(out) >= MAX_MAPS:
                continue
            flat = []
            for p in Q.lua_array(pts):
                p = Q.lua_array(p)
                if len(p) < 2 or p[0] is None or p[1] is None or p[0] < 0:
                    continue
                x, y = p[0] / 100.0, p[1] / 100.0
                if 0 <= x <= 1 and 0 <= y <= 1:
                    flat += [x, y]
                if len(flat) >= MAX_POINTS * 2:
                    break
            if flat:
                out[ui] = flat
        return out

    quest_ids = sorted({int(m.group(1)) for k in meta for m in [re.match(r"^X-Quest-(\d+)-S$", k)] if m})
    quests, npcs, objects, items = {}, {}, {}, {}

    def need_npc(i):
        if i not in npcs:
            npcs[i] = (name("Npc", i), spawns("Npc", i, "7"))
        return bool(npcs[i][1])

    def need_object(i):
        if i not in objects:
            objects[i] = (name("Object", i), spawns("Object", i, "4"))
        return bool(objects[i][1])

    def need_item(i):
        if i not in items:
            drops_n = [d for d in Q.lua_array(row("Item", i, "2") or []) if isinstance(d, int)][:MAX_DROPPERS]
            drops_o = [d for d in Q.lua_array(row("Item", i, "3") or []) if isinstance(d, int)][:MAX_DROPPERS]
            items[i] = (name("Item", i), [d for d in drops_n if need_npc(d)], [d for d in drops_o if need_object(d)])
        return bool(items[i][1] or items[i][2])

    for qid in quest_ids:
        s = row("Quest", qid, "S")
        if not isinstance(s, dict):
            continue
        objs = []
        o = row("Quest", qid, "10")
        if isinstance(o, dict):
            for e in Q.lua_array(o.get(1) or []):
                e = Q.lua_array(e)
                if e and isinstance(e[0], int) and need_npc(e[0]):
                    objs.append(("npc", e[0], e[1] if len(e) > 1 and isinstance(e[1], str) else None))
            for e in Q.lua_array(o.get(2) or []):
                e = Q.lua_array(e)
                if e and isinstance(e[0], int) and need_object(e[0]):
                    objs.append(("object", e[0], e[1] if len(e) > 1 and isinstance(e[1], str) else None))
            for e in Q.lua_array(o.get(3) or []):
                e = Q.lua_array(e)
                if e and isinstance(e[0], int) and need_item(e[0]):
                    objs.append(("item", e[0], e[1] if len(e) > 1 and isinstance(e[1], str) else None))
            for e in Q.lua_array(o.get(5) or []):
                e = Q.lua_array(e)
                ids = [i for i in Q.lua_array(e[0]) if isinstance(i, int)] if e else []
                ids = [i for i in ids[:MAX_DROPPERS] if need_npc(i)]
                if ids:
                    text = e[2] if len(e) > 2 and isinstance(e[2], str) else None
                    for i in ids:
                        objs.append(("npc", i, text))
        trig = row("Quest", qid, "9")
        explore = None
        if isinstance(trig, (dict, list)):
            t = Q.lua_array(trig) if not isinstance(trig, dict) else [trig.get(1), trig.get(2)]
            text, where = (t + [None, None])[:2]
            if isinstance(where, dict):
                for area, pts in where.items():
                    ui = area_map.get(area)
                    p = Q.lua_array(Q.lua_array(pts)[0]) if Q.lua_array(pts) else []
                    if ui and len(p) >= 2 and p[0] is not None:
                        explore = (text if isinstance(text, str) else None, ui, p[0] / 100.0, p[1] / 100.0)
                        break
        fin = row("Quest", qid, "3")
        fin = Q.lua_array(fin) if fin else []
        fin_npcs = [i for i in Q.id_list(fin[0]) if need_npc(i)] if len(fin) > 0 and fin[0] else []
        fin_objs = [i for i in Q.id_list(fin[1]) if need_object(i)] if len(fin) > 1 and fin[1] else []
        quests[qid] = (s.get(1) or "?", s.get(5) or 0, objs, explore, fin_npcs, fin_objs)

    # objects that start quests (wanted posters...), in NPCPack's quest format
    starters = {}
    obj_ids = sorted({int(m.group(1)) for k in meta for m in [re.match(r"^X-Object-(\d+)-2$", k)] if m})
    for oid in obj_ids:
        qs = []
        for qid in Q.id_list(row("Object", oid, "2")):
            qsrow = row("Quest", qid, "S")
            if not isinstance(qsrow, dict):
                continue
            pa, pl = row("Quest", qid, "13"), row("Quest", qid, "12")
            req = qsrow.get(4) or 1
            qs.append((qid, qsrow.get(1) or "?", req, qsrow.get(5) or req, Q.race_faction(qsrow.get(6)), qsrow.get(7) or 0,
                       Q.id_list(pa) if pa else [], Q.id_list(pl) if pl else [], qsrow.get(6) or 0))
        if qs and need_object(oid):
            starters[oid] = qs

    s = Q.lua_str
    os.makedirs(OUT, exist_ok=True)
    with open(os.path.join(OUT, "Outrider_Data_Quests.toc"), "w", encoding="utf-8", newline="\r\n") as f:
        f.write("## Interface: 16001\n## Title: Outrider Data: Quests (private)\n")
        f.write("## Notes: Private copy of quest objectives from QuestieDB (GPLv3, see Outrider DECISIONS D10). Not for redistribution.\n")
        f.write("## LoadOnDemand: 1\n## X-Source: QuestieDB %s\n\nData.lua\n" % version)

    def spawn_text(sp):
        return "{" + ",".join("[%d]={%s}" % (ui, ",".join("%.4f" % v for v in pts)) for ui, pts in sorted(sp.items())) + "}"

    with open(os.path.join(OUT, "Data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/import_questie_quests.py from QuestieDB %s. Private copy (D10), do not redistribute.\n" % version)
        f.write("-- Source: QuestieDB (https://github.com/Questie/Questie), GPLv3 per its LICENSE.md. Community data, unverified.\n")
        f.write("-- quests[id] = { name, level, { {kind, id, text}, ... }, explore = {text, uiMapID, x, y}, fin = {npc ids}, finObj = {object ids} }\n")
        f.write("-- starters[objectID] = { {questID, name, requiredLevel, questLevel, faction, classMask, {preAny}, {preAll}, raceMask} }\n")
        f.write("-- npcs/objects[id] = { name, { [uiMapID] = {x, y, x, y, ...} } }; items[id] = { name, {npc ids}, {object ids} }\n")
        f.write("Outrider_DataQuests = { source = %s,\n" % s("QuestieDB " + version))
        f.write("quests = {\n")
        for qid, (qn, lvl, objs, explore, fin_npcs, fin_objs) in sorted(quests.items()):
            ot = ",".join("{%s,%d,%s}" % (s(k), i, s(t) if t else "nil") for k, i, t in objs)
            ex = ""
            if explore:
                ex = ",explore={%s,%d,%.4f,%.4f}" % (s(explore[0]) if explore[0] else "nil", explore[1], explore[2], explore[3])
            if fin_npcs:
                ex += ",fin={%s}" % ",".join(map(str, fin_npcs))
            if fin_objs:
                ex += ",finObj={%s}" % ",".join(map(str, fin_objs))
            f.write("[%d]={%s,%d,{%s}%s},\n" % (qid, s(qn), lvl or 0, ot, ex))
        f.write("},\nnpcs = {\n")
        for i, (n, sp) in sorted(npcs.items()):
            if sp:
                f.write("[%d]={%s,%s},\n" % (i, s(n or "?"), spawn_text(sp)))
        f.write("},\nobjects = {\n")
        for i, (n, sp) in sorted(objects.items()):
            if sp:
                f.write("[%d]={%s,%s},\n" % (i, s(n or "?"), spawn_text(sp)))
        f.write("},\nitems = {\n")
        for i, (n, dn, do) in sorted(items.items()):
            if dn or do:
                f.write("[%d]={%s,{%s},{%s}},\n" % (i, s(n or "?"), ",".join(map(str, dn)), ",".join(map(str, do))))
        f.write("},\nstarters = {\n")
        for oid, qs in sorted(starters.items()):
            f.write("[%d]={%s},\n" % (oid, ",".join("{%d,%s,%d,%d,%s,%d,{%s},{%s},%d}" % (
                qid, s(qn), req, lvl, s({"H": "Horde", "A": "Alliance"}[qf]) if qf else "nil", cls,
                ",".join(map(str, pa)), ",".join(map(str, pl)), races) for qid, qn, req, lvl, qf, cls, pa, pl, races in qs)))
        f.write("} }\n")
    size = os.path.getsize(os.path.join(OUT, "Data.lua"))
    print("objects that start quests: %d" % len(starters))
    print("quests %d with objectives, mobs %d, objects %d, items %d, Data.lua %d KB" % (
        len(quests), sum(1 for v in npcs.values() if v[1]), sum(1 for v in objects.values() if v[1]),
        sum(1 for v in items.values() if v[1] or v[2]), size // 1024))
    q = quests.get(3741)
    print("  Hilary's Necklace:", q and q[2])
    if "--deploy" in sys.argv:
        target = os.path.join(cfg["addonsDir"], "Outrider_Data_Quests")
        if os.path.exists(target):
            shutil.rmtree(target)
        shutil.copytree(OUT, target)
        print("deployed to", target)


if __name__ == "__main__":
    main()
