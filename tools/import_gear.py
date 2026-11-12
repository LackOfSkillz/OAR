"""tools/import_gear.py -- private gear sources pack from QuestieDB (P6-05, D10/D13).

Reads QuestieDB's Forever item and quest rows (same CBOR-in-TOC format as
tools/import_questie.py) and writes the load-on-demand data addon
private/Outrider_Data_Gear/: every weapon or armor item up to required level
60 with where it comes from:
  quest  - quests that reward it (quest level, faction from the race mask,
           position of the quest giver)
  vendor - NPCs that sell it (position)
  drop   - NPCs that drop it, only when 3 or fewer do (named drops)
Item stats are NOT copied: Outrider scores items in game with
C_Item.GetItemStats. Everything is verified = false (community data).
Private like the NPC pack: GPLv3 Questie data, git-ignored, not for release.

Usage:  py tools/import_gear.py [path\\to\\QuestieDB] [--deploy]
"""
import json, os, re, shutil, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import import_questie as q  # noqa: E402

ROOT = q.ROOT
OUT = os.path.join(ROOT, "private", "Outrider_Data_Gear")
HORDE, ALLIANCE = 2 | 16 | 32 | 128, 1 | 4 | 8 | 64
MAX_DROPPERS = 3


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
        droppers = q.lua_array(row("Item", iid, "2"))
        if 0 < len(droppers) <= MAX_DROPPERS:
            for nid in droppers:
                place = npc_place(nid)
                if place:
                    srcs.append(("drop", place[0], place[1], place[2], place[3], None, place[4], None))
        if srcs:
            out[iid] = (s.get(1), req, s.get(9), srcs)
            sources += len(srcs)

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
    if "--deploy" in sys.argv:
        target = os.path.join(cfg["addonsDir"], "Outrider_Data_Gear")
        if os.path.exists(target):
            shutil.rmtree(target)
        shutil.copytree(OUT, target)
        print("deployed to", target)


if __name__ == "__main__":
    main()
