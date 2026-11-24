"""tools/import_crafting.py -- what every recipe makes and where you learn it.

Sources (Gary, 2026-11-23: "Yes, import it"):
  * WoW Forever's own client tables, exported by wago.tools for the Forever
    build (Blizzard's game data, the same kind ForeverDB ships):
      SpellEffect      Effect 24 = create item: recipe spell -> item, count
      SkillLineAbility profession, skill to learn, yellow and grey levels
      SpellReagents    what it takes
  * AllTheThings' Forever profession lists (MIT, github.com/ATTWoWAddon/AllTheThings,
    .contrib/.db/forever/profession db): learned from the trainer, from a
    recipe item (which one) or from a quest.
  * ForeverDB (GPLv3): recipe item names, vendors and drops with their spots.

    py tools/import_crafting.py [--fetch]

--fetch downloads the client tables and the ATT lists into private/ (saved
with where they came from). Writes private/Outrider_Data_Crafting.
Everything verified = false until seen in game.
"""
import csv, json, os, re, sys, urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import foreverdb as fdb  # noqa: E402

ROOT = fdb.ROOT
OUT = os.path.join(ROOT, "private", "Outrider_Data_Crafting")
WAGO = os.path.join(ROOT, "private", "wago-source")
ATT = os.path.join(ROOT, "private", "att-source")
BUILD = "1.60.1.71037"
TABLES = ("SpellEffect", "SkillLineAbility", "SpellReagents", "ItemSparse")
ATT_FILES = ("alchemy", "blacksmithing", "cooking", "enchanting", "engineering", "first aid", "leatherworking",
             "poison", "tailoring")
ATT_REPO = "ATTWoWAddon/AllTheThings"
ATT_DIR = ".contrib/.db/forever/profession db"
CREATE_ITEM = 24
PROFESSIONS = {164: "Blacksmithing", 165: "Leatherworking", 171: "Alchemy", 197: "Tailoring", 202: "Engineering",
               333: "Enchanting", 185: "Cooking", 129: "First Aid", 40: "Poisons", 186: "Mining", 356: "Fishing"}
KEEP = 3


def fetch():
    os.makedirs(WAGO, exist_ok=True)
    os.makedirs(ATT, exist_ok=True)
    ua = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Outrider data import"}
    for t in TABLES:
        url = "https://wago.tools/db2/%s/csv?build=%s" % (t, BUILD)
        with urllib.request.urlopen(urllib.request.Request(url, headers=ua), timeout=120) as r:
            open(os.path.join(WAGO, t + ".csv"), "wb").write(r.read())
        print("fetched", t)
    open(os.path.join(WAGO, "SOURCE.txt"), "w").write(
        "WoW Forever client tables (Blizzard Entertainment game data), build %s, exported by https://wago.tools/db2\n" % BUILD)
    import subprocess, base64
    for name in ATT_FILES + ("LICENSE",):
        path = "LICENSE" if name == "LICENSE" else "%s/%s.lua" % (ATT_DIR, name)
        data = subprocess.check_output(["gh", "api", "repos/%s/contents/%s" % (ATT_REPO, path.replace(" ", "%20")), "--jq", ".content"])
        open(os.path.join(ATT, (name if name == "LICENSE" else name + ".lua")), "wb").write(base64.b64decode(data))
    print("fetched AllTheThings profession lists")


def rows(table):
    path = os.path.join(WAGO, table + ".csv")
    if not os.path.exists(path):
        sys.exit("missing %s: run with --fetch" % path)
    return list(csv.DictReader(open(path, encoding="utf-8")))


def att_learn():
    """spellID -> ("trainer" | "item" | "quest", recipe item id or 0)"""
    out = {}
    for name in ATT_FILES:
        path = os.path.join(ATT, name + ".lua")
        if not os.path.exists(path):
            continue
        section = None
        for line in open(path, encoding="utf-8"):
            m = re.match(r"^---\s*(\w+)\s*---", line.strip())
            if m:
                section = m.group(1).lower()
                continue
            m = re.match(r"^\s*i\((\d+),\s*(\d+)\)", line)
            if m and section:
                item, spell = int(m.group(1)), int(m.group(2))
                kind = {"trainer": "trainer", "item": "item", "quest": "quest"}.get(section)
                if kind and spell not in out:
                    out[spell] = (kind, item)
    return out


def lua_str(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def main():
    if "--fetch" in sys.argv:
        fetch()
    d = fdb.load()
    makes = {}
    for r in rows("SpellEffect"):
        if r["Effect"] == str(CREATE_ITEM) and r["EffectItemType"] not in ("", "0"):
            sp = int(r["SpellID"])
            if sp not in makes:
                makes[sp] = (int(r["EffectItemType"]), max(1, int(float(r["EffectBasePointsF"] or 1))))
    reag = {}
    for r in rows("SpellReagents"):
        parts = []
        for i in range(8):
            item, n = r.get("Reagent_%d" % i), r.get("ReagentCount_%d" % i)
            if item and item != "0":
                parts.append((int(item), int(n or 1)))
        if parts:
            reag[int(r["SpellID"])] = parts
    learn = att_learn()
    skill_rank = {}
    for r in rows("ItemSparse"):
        if r.get("RequiredSkillRank") not in (None, "", "0"):
            skill_rank[int(r["ID"])] = int(r["RequiredSkillRank"])
    recipes, recipe_items = {}, set()
    for r in rows("SkillLineAbility"):
        sp, line = int(r["Spell"]), int(r["SkillLine"])
        if line not in PROFESSIONS or sp not in makes:
            continue
        item, qty = makes[sp]
        lo, hi = int(r["TrivialSkillLineRankLow"] or 0), int(r["TrivialSkillLineRankHigh"] or 0)
        how = learn.get(sp)
        at = int(r["MinSkillLineRank"] or 1)
        if how and how[0] == "item" and how[1]:
            # the recipe item says the skill it needs (ItemSparse RequiredSkillRank); the ability row says 1
            at = max(at, skill_rank.get(how[1], 0))
        recipes[sp] = (PROFESSIONS[line], at, lo, hi, item, qty, reag.get(sp, []), how)
        if how and how[0] == "item" and how[1]:
            recipe_items.add(how[1])

    def spots(key):
        return fdb.place(d, key) if d else None

    items_out = []
    for rid in sorted(recipe_items):
        info = fdb.item(d, rid) if d else None
        srcs = []
        for nid in ((d["vend"].get(str(rid)) or []) if d else [])[:KEEP]:
            n, at = fdb.npc(d, nid), spots("c%d" % nid)
            if n and at:
                srcs.append('{"vendor",%d,%.4f,%.4f,%s,%s}' % (at[0], at[1], at[2], lua_str(n[0]),
                            lua_str(fdb.faction(d, nid)) if fdb.faction(d, nid) else "nil"))
        drops = sorted((d["drop"].get(str(rid)) or []) if d else [], key=lambda x: -(x[1] or 0))
        for nid, chance in drops[:KEEP]:
            n, at = fdb.npc(d, nid), spots("c%d" % nid)
            if n and at:
                srcs.append('{"drop",%d,%.4f,%.4f,%s,nil,%d}' % (at[0], at[1], at[2], lua_str(n[0]), chance or 0))
        for qid in ((d["rew"].get(str(rid)) or []) if d else [])[:1]:
            q = d["quest"].get(str(qid))
            if q:
                srcs.append('{"quest",0,0,0,%s,nil,0,%d}' % (lua_str(q[0]), qid))
        items_out.append("[%d]={%s,{%s}}," % (rid, lua_str(info[0] if info else "?"), ",".join(srcs)))

    os.makedirs(OUT, exist_ok=True)
    src = "WoW Forever client %s (wago.tools) + AllTheThings (MIT) + %s" % (BUILD, fdb.version(d) if d else "no ForeverDB")
    with open(os.path.join(OUT, "Outrider_Data_Crafting.toc"), "w", encoding="utf-8", newline="\n") as f:
        f.write("## Interface: 16001\n## Title: Outrider Data: crafting\n")
        f.write("## Notes: What each recipe makes, skill colours, reagents and where to learn it.\n")
        f.write("## LoadOnDemand: 1\n## X-Source: %s\n\nData.lua\n" % src)
    with open(os.path.join(OUT, "Data.lua"), "w", encoding="utf-8", newline="\n") as f:
        f.write("-- GENERATED by tools/import_crafting.py. Sources: WoW Forever client tables (Blizzard Entertainment game data,\n")
        f.write("-- build %s, exported by wago.tools), AllTheThings Forever profession lists (MIT, Copyright (c) 2026\n" % BUILD)
        f.write("-- AllTheThings WoW Addon), ForeverDB (GPLv3) for recipe item sources. verified = false.\n")
        f.write("-- recipes[spellID] = { profession, learnAt, yellowAt, greyAt, itemID, count, {reagentID, count, ...}, how, recipeItemID, itemName }\n")
        f.write("--   how: \"trainer\", \"item\" (recipe item), \"quest\" or nil (unknown)\n")
        f.write("-- recipeItems[itemID] = { name, { {kind, mapID, x, y, who, faction, chancePer10000, questID}, ... } }\n")
        f.write("Outrider_DataCrafting = { source = %s,\nrecipes = {\n" % lua_str(src))
        for sp in sorted(recipes):
            prof, lv, lo, hi, item, qty, rg, how = recipes[sp]
            info = fdb.item(d, item) if d else None
            f.write("[%d]={%s,%d,%d,%d,%d,%d,{%s},%s,%s,%s},\n" % (sp, lua_str(prof), lv, lo, hi, item, qty,
                    ",".join("%d,%d" % x for x in rg), lua_str(how[0]) if how else "nil",
                    str(how[1]) if how and how[0] == "item" and how[1] else "nil",
                    lua_str(info[0]) if info and info[0] else "nil"))
        f.write("},\nrecipeItems = {\n")
        f.write("\n".join(items_out))
        f.write("\n} }\n")
    learned = {}
    for v in recipes.values():
        k = v[7][0] if v[7] else "unknown"
        learned[k] = learned.get(k, 0) + 1
    print("recipes %d (%s), recipe items with sources %d, Data.lua %d KB" % (
        len(recipes), ", ".join("%s %d" % kv for kv in sorted(learned.items())), len(items_out),
        os.path.getsize(os.path.join(OUT, "Data.lua")) // 1024))


if __name__ == "__main__":
    main()
